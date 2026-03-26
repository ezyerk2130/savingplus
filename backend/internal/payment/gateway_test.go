package payment_test

import (
	"strings"
	"testing"

	"github.com/savingplus/backend/internal/payment"
)

func TestNewGateway_Mock(t *testing.T) {
	gw, err := payment.NewGateway("mock")
	if err != nil {
		t.Fatalf("expected no error for mock gateway, got %v", err)
	}
	if gw == nil {
		t.Fatal("expected non-nil gateway")
	}

	// Verify the concrete type is MockGateway
	_, ok := gw.(*payment.MockGateway)
	if !ok {
		t.Errorf("expected *MockGateway, got %T", gw)
	}
}

func TestNewGateway_Cellulant(t *testing.T) {
	gw, err := payment.NewGateway("cellulant")
	if err == nil {
		t.Fatal("expected error for cellulant gateway (not implemented)")
	}
	if gw != nil {
		t.Error("expected nil gateway for cellulant")
	}
	if !strings.Contains(err.Error(), "not yet implemented") {
		t.Errorf("expected error message to mention 'not yet implemented', got: %s", err.Error())
	}
}

func TestNewGateway_Unknown(t *testing.T) {
	gw, err := payment.NewGateway("unknown")
	if err == nil {
		t.Fatal("expected error for unknown gateway")
	}
	if gw != nil {
		t.Error("expected nil gateway for unknown provider")
	}
	if !strings.Contains(err.Error(), "unknown payment gateway") {
		t.Errorf("expected error message to mention 'unknown payment gateway', got: %s", err.Error())
	}
}

func TestNewGateway_EmptyProvider(t *testing.T) {
	gw, err := payment.NewGateway("")
	if err == nil {
		t.Fatal("expected error for empty provider")
	}
	if gw != nil {
		t.Error("expected nil gateway for empty provider")
	}
}
