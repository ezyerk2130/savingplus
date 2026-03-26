package queue

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/hibiken/asynq"
	log "github.com/sirupsen/logrus"

	"github.com/savingplus/backend/internal/payment"
)

const (
	TypeProcessDeposit    = "payment:deposit"
	TypeProcessWithdrawal = "payment:withdrawal"
	TypeReconcilePending  = "payment:reconcile"
)

type PaymentPayload struct {
	TransactionID string  `json:"transaction_id"`
	PhoneNumber   string  `json:"phone_number"`
	Amount        float64 `json:"amount"`
	Currency      string  `json:"currency"`
	Reference     string  `json:"reference"`
	PaymentMethod string  `json:"payment_method"`
}

type Client struct {
	client *asynq.Client
}

func NewClient(redisAddr string) *Client {
	return &Client{
		client: asynq.NewClient(asynq.RedisClientOpt{Addr: redisAddr}),
	}
}

func (c *Client) Close() {
	c.client.Close()
}

func (c *Client) EnqueueDeposit(payload PaymentPayload) error {
	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal deposit payload: %w", err)
	}
	task := asynq.NewTask(TypeProcessDeposit, data)
	_, err = c.client.Enqueue(task, asynq.MaxRetry(3), asynq.Timeout(30*time.Second))
	return err
}

func (c *Client) EnqueueWithdrawal(payload PaymentPayload) error {
	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal withdrawal payload: %w", err)
	}
	task := asynq.NewTask(TypeProcessWithdrawal, data)
	_, err = c.client.Enqueue(task, asynq.MaxRetry(3), asynq.Timeout(30*time.Second))
	return err
}

type Worker struct {
	db      *sql.DB
	gateway payment.PaymentGateway
}

func NewWorker(db *sql.DB, gw payment.PaymentGateway) *Worker {
	return &Worker{db: db, gateway: gw}
}

func txnLog(p PaymentPayload) *log.Entry {
	return log.WithFields(log.Fields{
		"transaction_id": p.TransactionID,
		"amount":         p.Amount,
		"phone":          p.PhoneNumber,
		"reference":      p.Reference,
		"payment_method": p.PaymentMethod,
	})
}

func (w *Worker) HandleDepositTask(ctx context.Context, t *asynq.Task) error {
	var p PaymentPayload
	if err := json.Unmarshal(t.Payload(), &p); err != nil {
		return fmt.Errorf("failed to unmarshal deposit payload: %w", err)
	}

	l := txnLog(p)
	l.Info("Processing deposit payment")

	if _, err := w.db.ExecContext(ctx, `UPDATE transactions SET status = 'processing' WHERE id = $1`, p.TransactionID); err != nil {
		l.WithError(err).Warn("Failed to update transaction to processing, continuing with gateway call")
	}

	resp, err := w.gateway.InitiateDeposit(ctx, payment.DepositRequest{
		TransactionID: p.TransactionID,
		PhoneNumber:   p.PhoneNumber,
		Amount:        p.Amount,
		Currency:      p.Currency,
		Reference:     p.Reference,
	})
	if err != nil {
		l.WithError(err).Error("Gateway deposit initiation failed")
		if _, dbErr := w.db.ExecContext(ctx, `UPDATE transactions SET status = 'failed' WHERE id = $1`, p.TransactionID); dbErr != nil {
			l.WithError(dbErr).Error("Failed to mark transaction as failed after gateway error")
		}
		return err
	}

	if _, err := w.db.ExecContext(ctx, `UPDATE transactions SET gateway_ref = $1 WHERE id = $2`, resp.GatewayRef, p.TransactionID); err != nil {
		l.WithError(err).Warn("Failed to store gateway reference, transaction will continue without it")
	}

	l.WithField("gateway_ref", resp.GatewayRef).Info("Deposit initiated with gateway")
	return nil
}

func (w *Worker) HandleWithdrawalTask(ctx context.Context, t *asynq.Task) error {
	var p PaymentPayload
	if err := json.Unmarshal(t.Payload(), &p); err != nil {
		return fmt.Errorf("failed to unmarshal withdrawal payload: %w", err)
	}

	l := txnLog(p)
	l.Info("Processing withdrawal payment")

	if _, err := w.db.ExecContext(ctx, `UPDATE transactions SET status = 'processing' WHERE id = $1`, p.TransactionID); err != nil {
		l.WithError(err).Warn("Failed to update transaction to processing, continuing with gateway call")
	}

	resp, err := w.gateway.InitiateWithdrawal(ctx, payment.WithdrawalRequest{
		TransactionID: p.TransactionID,
		PhoneNumber:   p.PhoneNumber,
		Amount:        p.Amount,
		Currency:      p.Currency,
		Reference:     p.Reference,
	})
	if err != nil {
		l.WithError(err).Error("Gateway withdrawal initiation failed")
		if _, dbErr := w.db.ExecContext(ctx, `UPDATE transactions SET status = 'failed' WHERE id = $1`, p.TransactionID); dbErr != nil {
			l.WithError(dbErr).Error("Failed to mark transaction as failed after gateway error")
		}
		return err
	}

	if _, err := w.db.ExecContext(ctx, `UPDATE transactions SET gateway_ref = $1 WHERE id = $2`, resp.GatewayRef, p.TransactionID); err != nil {
		l.WithError(err).Warn("Failed to store gateway reference, transaction will continue without it")
	}

	l.WithField("gateway_ref", resp.GatewayRef).Info("Withdrawal initiated with gateway")
	return nil
}

func (w *Worker) ReconcilePendingTransactions(ctx context.Context, t *asynq.Task) error {
	log.Info("Running transaction reconciliation")

	result, err := w.db.ExecContext(ctx,
		`UPDATE transactions SET status = 'failed', updated_at = NOW()
		 WHERE status IN ('pending', 'processing') AND created_at < NOW() - INTERVAL '30 minutes'`,
	)
	if err != nil {
		log.WithError(err).Error("Reconciliation query failed")
		return fmt.Errorf("reconciliation failed: %w", err)
	}

	affected, err := result.RowsAffected()
	if err != nil {
		log.WithError(err).Warn("Failed to get reconciliation rows affected")
	}
	log.WithField("affected", affected).Info("Reconciliation complete")
	return nil
}

func StartWorkerServer(redisAddr string, worker *Worker) *asynq.Server {
	srv := asynq.NewServer(
		asynq.RedisClientOpt{Addr: redisAddr},
		asynq.Config{
			Concurrency: 10,
			Queues: map[string]int{
				"critical": 6,
				"default":  3,
				"low":      1,
			},
		},
	)

	mux := asynq.NewServeMux()
	mux.HandleFunc(TypeProcessDeposit, worker.HandleDepositTask)
	mux.HandleFunc(TypeProcessWithdrawal, worker.HandleWithdrawalTask)
	mux.HandleFunc(TypeReconcilePending, worker.ReconcilePendingTransactions)

	go func() {
		if err := srv.Run(mux); err != nil {
			log.WithError(err).Fatal("Asynq worker server failed")
		}
	}()

	return srv
}

func StartScheduler(redisAddr string) *asynq.Scheduler {
	scheduler := asynq.NewScheduler(
		asynq.RedisClientOpt{Addr: redisAddr},
		nil,
	)

	task := asynq.NewTask(TypeReconcilePending, nil)
	if _, err := scheduler.Register("*/15 * * * *", task); err != nil {
		log.WithError(err).Error("Failed to register reconciliation scheduler")
	}

	go func() {
		if err := scheduler.Run(); err != nil {
			log.WithError(err).Fatal("Asynq scheduler failed")
		}
	}()

	return scheduler
}
