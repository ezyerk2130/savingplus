package payment

import (
	"database/sql"
	"encoding/json"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/internal/wallet"
)

type WebhookHandler struct {
	db      *sql.DB
	gateway PaymentGateway
}

func NewWebhookHandler(db *sql.DB, gw PaymentGateway) *WebhookHandler {
	return &WebhookHandler{db: db, gateway: gw}
}

func (h *WebhookHandler) HandlePaymentWebhook(c *gin.Context) {
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read request body"})
		return
	}

	event, err := h.gateway.HandleWebhook(c, body)
	if err != nil {
		log.WithError(err).Error("Failed to process webhook")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid webhook payload"})
		return
	}

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
		log.WithError(err).Error("Transaction not found for webhook")
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}

	if currentStatus != "pending" && currentStatus != "processing" {
		log.Warn("Webhook received for already-settled transaction")
		c.JSON(http.StatusOK, gin.H{"message": "Already processed"})
		return
	}

	// Update transaction status
	newStatus := "completed"
	if event.Status == "failed" {
		newStatus = "failed"
	}

	_, err = h.db.ExecContext(c,
		`UPDATE transactions SET status = $1, gateway_ref = $2, completed_at = NOW() WHERE id = $3`,
		newStatus, event.GatewayRef, txnID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to update transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Update wallet balance if successful
	if newStatus == "completed" {
		switch txnType {
		case "deposit":
			if err := wallet.CreditWallet(h.db, c, walletID, txnID, amount, "Mobile money deposit"); err != nil {
				log.WithError(err).Error("Failed to credit wallet")
			}
		case "withdrawal":
			if err := wallet.DebitWallet(h.db, c, walletID, txnID, amount, "Mobile money withdrawal"); err != nil {
				log.WithError(err).Error("Failed to debit wallet")
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Webhook processed successfully"})
}

func (h *WebhookHandler) logGatewayEvent(c *gin.Context, txnID, direction, endpoint string, request, response []byte, httpStatus int) {
	reqJSON, _ := json.Marshal(json.RawMessage(request))
	respJSON, _ := json.Marshal(json.RawMessage(response))

	h.db.ExecContext(c,
		`INSERT INTO payment_gateway_logs (id, transaction_id, gateway, direction, endpoint, request_body, response_body, http_status)
		 VALUES ($1, $2, 'mock', $3, $4, $5, $6, $7)`,
		uuid.New(), txnID, direction, endpoint, reqJSON, respJSON, httpStatus,
	)
}
