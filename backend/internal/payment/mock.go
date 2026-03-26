package payment

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"
)

// MockGateway simulates a mobile money aggregator for local development
type MockGateway struct{}

func NewMockGateway() *MockGateway {
	return &MockGateway{}
}

func (g *MockGateway) InitiateDeposit(ctx context.Context, req DepositRequest) (*GatewayResponse, error) {
	log.WithFields(log.Fields{
		"transaction_id": req.TransactionID,
		"phone":          req.PhoneNumber,
		"amount":         req.Amount,
		"reference":      req.Reference,
	}).Info("[MOCK] Initiating mobile money deposit")

	// Simulate processing delay
	time.Sleep(100 * time.Millisecond)

	return &GatewayResponse{
		GatewayRef: fmt.Sprintf("MOCK-DEP-%s", uuid.New().String()[:8]),
		Status:     "pending",
		Message:    "Mock deposit initiated - will auto-complete",
	}, nil
}

func (g *MockGateway) InitiateWithdrawal(ctx context.Context, req WithdrawalRequest) (*GatewayResponse, error) {
	log.WithFields(log.Fields{
		"transaction_id": req.TransactionID,
		"phone":          req.PhoneNumber,
		"amount":         req.Amount,
		"reference":      req.Reference,
	}).Info("[MOCK] Initiating mobile money withdrawal")

	time.Sleep(100 * time.Millisecond)

	return &GatewayResponse{
		GatewayRef: fmt.Sprintf("MOCK-WDR-%s", uuid.New().String()[:8]),
		Status:     "pending",
		Message:    "Mock withdrawal initiated - will auto-complete",
	}, nil
}

func (g *MockGateway) HandleWebhook(ctx context.Context, payload []byte) (*WebhookEvent, error) {
	var event WebhookEvent
	if err := json.Unmarshal(payload, &event); err != nil {
		return nil, fmt.Errorf("failed to parse webhook payload: %w", err)
	}

	log.WithFields(log.Fields{
		"transaction_id": event.TransactionID,
		"status":         event.Status,
		"gateway_ref":    event.GatewayRef,
	}).Info("[MOCK] Received webhook callback")

	return &event, nil
}
