package payment

import (
	"context"
	"fmt"
)

// PaymentGateway defines the interface for mobile money integration
type PaymentGateway interface {
	InitiateDeposit(ctx context.Context, req DepositRequest) (*GatewayResponse, error)
	InitiateWithdrawal(ctx context.Context, req WithdrawalRequest) (*GatewayResponse, error)
	HandleWebhook(ctx context.Context, payload []byte) (*WebhookEvent, error)
}

type DepositRequest struct {
	TransactionID string  `json:"transaction_id"`
	PhoneNumber   string  `json:"phone_number"`
	Amount        float64 `json:"amount"`
	Currency      string  `json:"currency"`
	Reference     string  `json:"reference"`
	CallbackURL   string  `json:"callback_url"`
}

type WithdrawalRequest struct {
	TransactionID string  `json:"transaction_id"`
	PhoneNumber   string  `json:"phone_number"`
	Amount        float64 `json:"amount"`
	Currency      string  `json:"currency"`
	Reference     string  `json:"reference"`
	CallbackURL   string  `json:"callback_url"`
}

type GatewayResponse struct {
	GatewayRef string `json:"gateway_ref"`
	Status     string `json:"status"`
	Message    string `json:"message"`
}

type WebhookEvent struct {
	TransactionID string  `json:"transaction_id"`
	GatewayRef    string  `json:"gateway_ref"`
	Status        string  `json:"status"` // completed, failed
	Amount        float64 `json:"amount"`
	Reference     string  `json:"reference"`
	Message       string  `json:"message"`
}

// NewGateway creates a payment gateway based on the provider name
func NewGateway(provider string) (PaymentGateway, error) {
	switch provider {
	case "mock":
		return NewMockGateway(), nil
	case "cellulant":
		return nil, fmt.Errorf("cellulant gateway not yet implemented - use mock for development")
	default:
		return nil, fmt.Errorf("unknown payment gateway: %s", provider)
	}
}
