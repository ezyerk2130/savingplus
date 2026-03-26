package payment

import (
	"database/sql"
	"encoding/json"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/internal/ledger"
	"github.com/savingplus/backend/pkg/logger"
)

type WebhookHandler struct {
	db      *sql.DB
	gateway PaymentGateway
}

func NewWebhookHandler(db *sql.DB, gw PaymentGateway) *WebhookHandler {
	return &WebhookHandler{db: db, gateway: gw}
}

func (h *WebhookHandler) HandlePaymentWebhook(c *gin.Context) {
	log := logger.Ctx(c)

	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		log.WithError(err).Error("Failed to read webhook request body")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read request body"})
		return
	}

	event, err := h.gateway.HandleWebhook(c, body)
	if err != nil {
		log.WithError(err).Error("Failed to parse webhook payload")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid webhook payload"})
		return
	}

	log = log.WithField("transaction_id", event.TransactionID).WithField("gateway_ref", event.GatewayRef)

	// Log the gateway interaction
	h.logGatewayEvent(c, event.TransactionID, "inbound", "/webhooks/payment", nil, body, 200)

	// Get transaction details
	var txnID, walletID, txnType, currentStatus string
	var amount float64
	err = h.db.QueryRowContext(c,
		`SELECT id, wallet_id, type, status, amount FROM transactions WHERE id = $1 OR reference = $2`,
		event.TransactionID, event.Reference,
	).Scan(&txnID, &walletID, &txnType, &currentStatus, &amount)
	if err != nil {
		log.WithError(err).WithField("reference", event.Reference).Error("Transaction not found for webhook")
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}

	log = log.WithField("txn_type", txnType).WithField("amount", amount)

	if currentStatus != "pending" && currentStatus != "processing" {
		log.WithField("current_status", currentStatus).Warn("Webhook received for already-settled transaction")
		c.JSON(http.StatusOK, gin.H{"message": "Already processed"})
		return
	}

	// Update transaction status
	newStatus := "completed"
	if event.Status == "failed" {
		newStatus = "failed"
	}

	if _, err = h.db.ExecContext(c,
		`UPDATE transactions SET status = $1, gateway_ref = $2, completed_at = NOW() WHERE id = $3`,
		newStatus, event.GatewayRef, txnID,
	); err != nil {
		log.WithError(err).Error("Failed to update transaction status from webhook")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Update wallet balance if successful
	if newStatus == "completed" {
		switch txnType {
		case "deposit":
			if err := ledger.CreditWallet(h.db, c, walletID, txnID, amount, "Mobile money deposit"); err != nil {
				log.WithError(err).WithField("wallet_id", walletID).Error("CRITICAL: Failed to credit wallet after successful deposit")
			}
		case "withdrawal":
			if err := ledger.DebitWallet(h.db, c, walletID, txnID, amount, "Mobile money withdrawal"); err != nil {
				log.WithError(err).WithField("wallet_id", walletID).Error("CRITICAL: Failed to debit wallet after successful withdrawal")
			}
		}
	}

	log.WithField("new_status", newStatus).Info("Webhook processed successfully")
	c.JSON(http.StatusOK, gin.H{"message": "Webhook processed successfully"})
}

func (h *WebhookHandler) logGatewayEvent(c *gin.Context, txnID, direction, endpoint string, request, response []byte, httpStatus int) {
	log := logger.Ctx(c)

	var reqJSON, respJSON json.RawMessage
	if request != nil {
		reqJSON = json.RawMessage(request)
	}
	if response != nil {
		respJSON = json.RawMessage(response)
	}

	if _, err := h.db.ExecContext(c,
		`INSERT INTO payment_gateway_logs (id, transaction_id, gateway, direction, endpoint, request_body, response_body, http_status)
		 VALUES ($1, $2, 'mock', $3, $4, $5, $6, $7)`,
		uuid.New(), txnID, direction, endpoint, reqJSON, respJSON, httpStatus,
	); err != nil {
		log.WithError(err).WithField("transaction_id", txnID).Error("Failed to log gateway event")
	}
}
