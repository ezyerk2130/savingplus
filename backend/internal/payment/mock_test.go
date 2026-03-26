package payment_test

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"github.com/savingplus/backend/internal/payment"
)

func TestMockGateway_InitiateDeposit(t *testing.T) {
	gw := payment.NewMockGateway()

	req := payment.DepositRequest{
		TransactionID: "txn-001",
		PhoneNumber:   "+255712345678",
		Amount:        50000.00,
		Currency:      "TZS",
		Reference:     "DEP-001",
		CallbackURL:   "http://localhost:8080/api/v1/webhooks/payment",
	}

	resp, err := gw.InitiateDeposit(context.Background(), req)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
	if resp.Status != "pending" {
		t.Errorf("expected status=pending, got %s", resp.Status)
	}
	if !strings.HasPrefix(resp.GatewayRef, "MOCK-DEP-") {
		t.Errorf("expected gateway ref to start with MOCK-DEP-, got %s", resp.GatewayRef)
	}
	if resp.Message == "" {
		t.Error("expected non-empty message")
	}
}

func TestMockGateway_InitiateWithdrawal(t *testing.T) {
	gw := payment.NewMockGateway()

	req := payment.WithdrawalRequest{
		TransactionID: "txn-002",
		PhoneNumber:   "+255712345678",
		Amount:        25000.00,
		Currency:      "TZS",
		Reference:     "WDR-001",
		CallbackURL:   "http://localhost:8080/api/v1/webhooks/payment",
	}

	resp, err := gw.InitiateWithdrawal(context.Background(), req)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
	if resp.Status != "pending" {
		t.Errorf("expected status=pending, got %s", resp.Status)
	}
	if !strings.HasPrefix(resp.GatewayRef, "MOCK-WDR-") {
		t.Errorf("expected gateway ref to start with MOCK-WDR-, got %s", resp.GatewayRef)
	}
	if resp.Message == "" {
		t.Error("expected non-empty message")
	}
}

func TestMockGateway_HandleWebhook_ValidPayload(t *testing.T) {
	gw := payment.NewMockGateway()

	event := payment.WebhookEvent{
		TransactionID: "txn-003",
		GatewayRef:    "MOCK-DEP-abc12345",
		Status:        "completed",
		Amount:        100000.00,
		Reference:     "DEP-003",
		Message:       "Payment successful",
	}

	payload, err := json.Marshal(event)
	if err != nil {
		t.Fatalf("failed to marshal test event: %v", err)
	}

	result, err := gw.HandleWebhook(context.Background(), payload)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result == nil {
		t.Fatal("expected non-nil event")
	}
	if result.TransactionID != "txn-003" {
		t.Errorf("expected transaction_id=txn-003, got %s", result.TransactionID)
	}
	if result.GatewayRef != "MOCK-DEP-abc12345" {
		t.Errorf("expected gateway_ref=MOCK-DEP-abc12345, got %s", result.GatewayRef)
	}
	if result.Status != "completed" {
		t.Errorf("expected status=completed, got %s", result.Status)
	}
	if result.Amount != 100000.00 {
		t.Errorf("expected amount=100000, got %f", result.Amount)
	}
	if result.Reference != "DEP-003" {
		t.Errorf("expected reference=DEP-003, got %s", result.Reference)
	}
	if result.Message != "Payment successful" {
		t.Errorf("expected message='Payment successful', got %s", result.Message)
	}
}

func TestMockGateway_HandleWebhook_InvalidJSON(t *testing.T) {
	gw := payment.NewMockGateway()

	payload := []byte("this is not valid json{{{")

	result, err := gw.HandleWebhook(context.Background(), payload)
	if err == nil {
		t.Fatal("expected error for invalid JSON")
	}
	if result != nil {
		t.Error("expected nil result for invalid JSON")
	}
	if !strings.Contains(err.Error(), "failed to parse webhook payload") {
		t.Errorf("expected error about parsing webhook payload, got: %s", err.Error())
	}
}

func TestMockGateway_HandleWebhook_EmptyPayload(t *testing.T) {
	gw := payment.NewMockGateway()

	result, err := gw.HandleWebhook(context.Background(), []byte{})
	if err == nil {
		t.Fatal("expected error for empty payload")
	}
	if result != nil {
		t.Error("expected nil result for empty payload")
	}
}

func TestMockGateway_HandleWebhook_FailedStatus(t *testing.T) {
	gw := payment.NewMockGateway()

	event := payment.WebhookEvent{
		TransactionID: "txn-004",
		GatewayRef:    "MOCK-DEP-failed1",
		Status:        "failed",
		Amount:        50000.00,
		Reference:     "DEP-004",
		Message:       "Insufficient funds on mobile money account",
	}

	payload, err := json.Marshal(event)
	if err != nil {
		t.Fatalf("failed to marshal: %v", err)
	}

	result, err := gw.HandleWebhook(context.Background(), payload)
	if err != nil {
		t.Fatalf("expected no error for valid JSON with failed status, got %v", err)
	}
	if result.Status != "failed" {
		t.Errorf("expected status=failed, got %s", result.Status)
	}
}

func TestMockGateway_HandleWebhook_PartialPayload(t *testing.T) {
	gw := payment.NewMockGateway()

	// Valid JSON but missing most fields
	payload := []byte(`{"transaction_id": "txn-005"}`)

	result, err := gw.HandleWebhook(context.Background(), payload)
	if err != nil {
		t.Fatalf("expected no error for valid JSON with partial fields, got %v", err)
	}
	if result.TransactionID != "txn-005" {
		t.Errorf("expected transaction_id=txn-005, got %s", result.TransactionID)
	}
	// Other fields should be zero values
	if result.Status != "" {
		t.Errorf("expected empty status for partial payload, got %s", result.Status)
	}
	if result.Amount != 0 {
		t.Errorf("expected amount=0 for partial payload, got %f", result.Amount)
	}
}

func TestMockGateway_ImplementsInterface(t *testing.T) {
	// Compile-time check that MockGateway implements PaymentGateway
	var _ payment.PaymentGateway = (*payment.MockGateway)(nil)
}

func TestMockGateway_DepositAndWithdrawal_UniqueRefs(t *testing.T) {
	gw := payment.NewMockGateway()

	req := payment.DepositRequest{
		TransactionID: "txn-ref-1",
		PhoneNumber:   "+255712345678",
		Amount:        10000.00,
		Currency:      "TZS",
		Reference:     "REF-1",
	}

	resp1, err1 := gw.InitiateDeposit(context.Background(), req)
	if err1 != nil {
		t.Fatalf("first deposit error: %v", err1)
	}

	req.TransactionID = "txn-ref-2"
	req.Reference = "REF-2"
	resp2, err2 := gw.InitiateDeposit(context.Background(), req)
	if err2 != nil {
		t.Fatalf("second deposit error: %v", err2)
	}

	if resp1.GatewayRef == resp2.GatewayRef {
		t.Errorf("expected unique gateway refs, both were %s", resp1.GatewayRef)
	}
}
