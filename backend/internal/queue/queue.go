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

// Client wraps asynq client for enqueuing tasks
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
	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TypeProcessDeposit, data)
	_, err := c.client.Enqueue(task, asynq.MaxRetry(3), asynq.Timeout(30*time.Second))
	return err
}

func (c *Client) EnqueueWithdrawal(payload PaymentPayload) error {
	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TypeProcessWithdrawal, data)
	_, err := c.client.Enqueue(task, asynq.MaxRetry(3), asynq.Timeout(30*time.Second))
	return err
}

// Worker processes async payment tasks
type Worker struct {
	db      *sql.DB
	gateway payment.PaymentGateway
}

func NewWorker(db *sql.DB, gw payment.PaymentGateway) *Worker {
	return &Worker{db: db, gateway: gw}
}

func (w *Worker) HandleDepositTask(ctx context.Context, t *asynq.Task) error {
	var p PaymentPayload
	if err := json.Unmarshal(t.Payload(), &p); err != nil {
		return fmt.Errorf("failed to unmarshal payload: %w", err)
	}

	log.WithFields(log.Fields{
		"transaction_id": p.TransactionID,
		"amount":         p.Amount,
		"phone":          p.PhoneNumber,
	}).Info("Processing deposit payment")

	// Update transaction to processing
	w.db.ExecContext(ctx, `UPDATE transactions SET status = 'processing' WHERE id = $1`, p.TransactionID)

	resp, err := w.gateway.InitiateDeposit(ctx, payment.DepositRequest{
		TransactionID: p.TransactionID,
		PhoneNumber:   p.PhoneNumber,
		Amount:        p.Amount,
		Currency:      p.Currency,
		Reference:     p.Reference,
	})
	if err != nil {
		log.WithError(err).Error("Gateway deposit failed")
		w.db.ExecContext(ctx, `UPDATE transactions SET status = 'failed' WHERE id = $1`, p.TransactionID)
		return err
	}

	// Store gateway reference
	w.db.ExecContext(ctx, `UPDATE transactions SET gateway_ref = $1 WHERE id = $2`, resp.GatewayRef, p.TransactionID)

	log.WithField("gateway_ref", resp.GatewayRef).Info("Deposit initiated with gateway")
	return nil
}

func (w *Worker) HandleWithdrawalTask(ctx context.Context, t *asynq.Task) error {
	var p PaymentPayload
	if err := json.Unmarshal(t.Payload(), &p); err != nil {
		return fmt.Errorf("failed to unmarshal payload: %w", err)
	}

	log.WithFields(log.Fields{
		"transaction_id": p.TransactionID,
		"amount":         p.Amount,
		"phone":          p.PhoneNumber,
	}).Info("Processing withdrawal payment")

	w.db.ExecContext(ctx, `UPDATE transactions SET status = 'processing' WHERE id = $1`, p.TransactionID)

	resp, err := w.gateway.InitiateWithdrawal(ctx, payment.WithdrawalRequest{
		TransactionID: p.TransactionID,
		PhoneNumber:   p.PhoneNumber,
		Amount:        p.Amount,
		Currency:      p.Currency,
		Reference:     p.Reference,
	})
	if err != nil {
		log.WithError(err).Error("Gateway withdrawal failed")
		w.db.ExecContext(ctx, `UPDATE transactions SET status = 'failed' WHERE id = $1`, p.TransactionID)
		return err
	}

	w.db.ExecContext(ctx, `UPDATE transactions SET gateway_ref = $1 WHERE id = $2`, resp.GatewayRef, p.TransactionID)

	log.WithField("gateway_ref", resp.GatewayRef).Info("Withdrawal initiated with gateway")
	return nil
}

// ReconcilePendingTransactions marks stale pending transactions as failed
func (w *Worker) ReconcilePendingTransactions(ctx context.Context, t *asynq.Task) error {
	log.Info("Running transaction reconciliation")

	result, err := w.db.ExecContext(ctx,
		`UPDATE transactions SET status = 'failed', updated_at = NOW()
		 WHERE status IN ('pending', 'processing') AND created_at < NOW() - INTERVAL '30 minutes'`,
	)
	if err != nil {
		return fmt.Errorf("reconciliation failed: %w", err)
	}

	affected, _ := result.RowsAffected()
	log.WithField("affected", affected).Info("Reconciliation complete")
	return nil
}

// StartWorkerServer starts the Asynq worker server
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

// StartScheduler starts periodic tasks (reconciliation)
func StartScheduler(redisAddr string) *asynq.Scheduler {
	scheduler := asynq.NewScheduler(
		asynq.RedisClientOpt{Addr: redisAddr},
		nil,
	)

	// Run reconciliation every 15 minutes
	task := asynq.NewTask(TypeReconcilePending, nil)
	scheduler.Register("*/15 * * * *", task)

	go func() {
		if err := scheduler.Run(); err != nil {
			log.WithError(err).Fatal("Asynq scheduler failed")
		}
	}()

	return scheduler
}
