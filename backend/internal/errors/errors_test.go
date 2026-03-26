package errors

import (
	"net/http"
	"strings"
	"testing"
)

// ---------------------------------------------------------------------------
// Error() method
// ---------------------------------------------------------------------------

func TestAppError_Error(t *testing.T) {
	err := &AppError{Code: 400, Message: "bad_request", Detail: "missing field"}
	got := err.Error()
	want := "[400] bad_request: missing field"
	if got != want {
		t.Errorf("Error() = %q, want %q", got, want)
	}
}

func TestAppError_Error_EmptyDetail(t *testing.T) {
	err := &AppError{Code: 500, Message: "internal_error", Detail: ""}
	got := err.Error()
	// Should still format correctly with empty detail
	if !strings.HasPrefix(got, "[500]") {
		t.Errorf("Error() = %q, expected to start with '[500]'", got)
	}
}

func TestAppError_ImplementsErrorInterface(t *testing.T) {
	var err error = &AppError{Code: 400, Message: "test", Detail: "detail"}
	if err.Error() == "" {
		t.Error("Error() should return non-empty string")
	}
}

// ---------------------------------------------------------------------------
// New()
// ---------------------------------------------------------------------------

func TestNew(t *testing.T) {
	err := New(422, "validation_error", "email is invalid")
	if err.Code != 422 {
		t.Errorf("Code = %d, want 422", err.Code)
	}
	if err.Message != "validation_error" {
		t.Errorf("Message = %q, want 'validation_error'", err.Message)
	}
	if err.Detail != "email is invalid" {
		t.Errorf("Detail = %q, want 'email is invalid'", err.Detail)
	}
}

// ---------------------------------------------------------------------------
// Predefined errors have correct HTTP status codes
// ---------------------------------------------------------------------------

func TestPredefinedErrors_StatusCodes(t *testing.T) {
	tests := []struct {
		name     string
		err      *AppError
		wantCode int
	}{
		{"ErrBadRequest", ErrBadRequest, http.StatusBadRequest},
		{"ErrUnauthorized", ErrUnauthorized, http.StatusUnauthorized},
		{"ErrForbidden", ErrForbidden, http.StatusForbidden},
		{"ErrNotFound", ErrNotFound, http.StatusNotFound},
		{"ErrConflict", ErrConflict, http.StatusConflict},
		{"ErrTooManyRequests", ErrTooManyRequests, http.StatusTooManyRequests},
		{"ErrInternal", ErrInternal, http.StatusInternalServerError},
		{"ErrIdempotencyConflict", ErrIdempotencyConflict, http.StatusConflict},
		{"ErrOTPExpired", ErrOTPExpired, http.StatusBadRequest},
		{"ErrOTPInvalid", ErrOTPInvalid, http.StatusBadRequest},
		{"ErrKYCRequired", ErrKYCRequired, http.StatusForbidden},
		{"ErrInsufficientBalance", ErrInsufficientBalance, http.StatusBadRequest},
		{"ErrStepUpRequired", ErrStepUpRequired, http.StatusForbidden},
		{"ErrAccountLocked", ErrAccountLocked, http.StatusForbidden},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.err.Code != tc.wantCode {
				t.Errorf("%s.Code = %d, want %d", tc.name, tc.err.Code, tc.wantCode)
			}
			if tc.err.Message == "" {
				t.Errorf("%s.Message is empty", tc.name)
			}
			if tc.err.Detail == "" {
				t.Errorf("%s.Detail is empty", tc.name)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Helper functions: BadRequest, NotFound, Internal, Forbidden
// ---------------------------------------------------------------------------

func TestBadRequest(t *testing.T) {
	err := BadRequest("invalid email")
	if err.Code != http.StatusBadRequest {
		t.Errorf("Code = %d, want %d", err.Code, http.StatusBadRequest)
	}
	if err.Message != "bad_request" {
		t.Errorf("Message = %q, want 'bad_request'", err.Message)
	}
	if err.Detail != "invalid email" {
		t.Errorf("Detail = %q, want 'invalid email'", err.Detail)
	}
}

func TestNotFound(t *testing.T) {
	err := NotFound("user not found")
	if err.Code != http.StatusNotFound {
		t.Errorf("Code = %d, want %d", err.Code, http.StatusNotFound)
	}
	if err.Message != "not_found" {
		t.Errorf("Message = %q, want 'not_found'", err.Message)
	}
	if err.Detail != "user not found" {
		t.Errorf("Detail = %q, want 'user not found'", err.Detail)
	}
}

func TestInternal(t *testing.T) {
	err := Internal("database connection failed")
	if err.Code != http.StatusInternalServerError {
		t.Errorf("Code = %d, want %d", err.Code, http.StatusInternalServerError)
	}
	if err.Message != "internal_error" {
		t.Errorf("Message = %q, want 'internal_error'", err.Message)
	}
	if err.Detail != "database connection failed" {
		t.Errorf("Detail = %q, want 'database connection failed'", err.Detail)
	}
}

func TestForbidden(t *testing.T) {
	err := Forbidden("admin only")
	if err.Code != http.StatusForbidden {
		t.Errorf("Code = %d, want %d", err.Code, http.StatusForbidden)
	}
	if err.Message != "forbidden" {
		t.Errorf("Message = %q, want 'forbidden'", err.Message)
	}
	if err.Detail != "admin only" {
		t.Errorf("Detail = %q, want 'admin only'", err.Detail)
	}
}

// ---------------------------------------------------------------------------
// Helpers produce distinct instances
// ---------------------------------------------------------------------------

func TestHelpers_ProduceDistinctInstances(t *testing.T) {
	e1 := BadRequest("error 1")
	e2 := BadRequest("error 2")
	if e1 == e2 {
		t.Error("helper functions should return new instances each time")
	}
	if e1.Detail == e2.Detail {
		t.Error("details should differ")
	}
}

func TestHelpers_NotSameAsPredefined(t *testing.T) {
	// The helpers should create new instances, not return the predefined vars
	e := BadRequest("custom detail")
	if e == ErrBadRequest {
		t.Error("BadRequest() should not return the same pointer as ErrBadRequest")
	}
}
