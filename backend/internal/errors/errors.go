package errors

import (
	"fmt"
	"net/http"
)

type AppError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Detail  string `json:"detail,omitempty"`
}

func (e *AppError) Error() string {
	return fmt.Sprintf("[%d] %s: %s", e.Code, e.Message, e.Detail)
}

func New(code int, message, detail string) *AppError {
	return &AppError{Code: code, Message: message, Detail: detail}
}

// Common errors
var (
	ErrBadRequest          = New(http.StatusBadRequest, "bad_request", "Invalid request data")
	ErrUnauthorized        = New(http.StatusUnauthorized, "unauthorized", "Authentication required")
	ErrForbidden           = New(http.StatusForbidden, "forbidden", "Insufficient permissions")
	ErrNotFound            = New(http.StatusNotFound, "not_found", "Resource not found")
	ErrConflict            = New(http.StatusConflict, "conflict", "Resource already exists")
	ErrTooManyRequests     = New(http.StatusTooManyRequests, "rate_limited", "Too many requests")
	ErrInternal            = New(http.StatusInternalServerError, "internal_error", "An unexpected error occurred")
	ErrIdempotencyConflict = New(http.StatusConflict, "idempotency_conflict", "Request with this idempotency key already processed")
	ErrOTPExpired          = New(http.StatusBadRequest, "otp_expired", "OTP has expired or is invalid")
	ErrOTPInvalid          = New(http.StatusBadRequest, "otp_invalid", "Invalid OTP code")
	ErrKYCRequired         = New(http.StatusForbidden, "kyc_required", "KYC verification required")
	ErrInsufficientBalance = New(http.StatusBadRequest, "insufficient_balance", "Insufficient wallet balance")
	ErrStepUpRequired      = New(http.StatusForbidden, "stepup_required", "Additional verification required for this transaction")
	ErrAccountLocked       = New(http.StatusForbidden, "account_locked", "Account is locked")
)

func BadRequest(detail string) *AppError {
	return New(http.StatusBadRequest, "bad_request", detail)
}

func NotFound(detail string) *AppError {
	return New(http.StatusNotFound, "not_found", detail)
}

func Internal(detail string) *AppError {
	return New(http.StatusInternalServerError, "internal_error", detail)
}

func Forbidden(detail string) *AppError {
	return New(http.StatusForbidden, "forbidden", detail)
}
