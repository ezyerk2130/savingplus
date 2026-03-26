package auth

import (
	"testing"
	"time"

	"github.com/savingplus/backend/pkg/crypto"
)

// ---------------------------------------------------------------------------
// OTP Tests
//
// The OTPService depends on a live Redis connection for SendOTP and VerifyOTP.
// Below we test the parts that can run without Redis (OTP generation format)
// and document the expected behavior of the Redis-dependent methods.
// ---------------------------------------------------------------------------

func TestNewOTPService(t *testing.T) {
	// NewOTPService should accept nil redis client for construction
	// (it will fail at runtime when methods are called, not at construction)
	svc := NewOTPService(nil, 6, 5*time.Minute)
	if svc == nil {
		t.Fatal("NewOTPService returned nil")
	}
	if svc.length != 6 {
		t.Errorf("length = %d, want 6", svc.length)
	}
	if svc.ttl != 5*time.Minute {
		t.Errorf("ttl = %v, want 5m", svc.ttl)
	}
}

func TestOTPGeneration_Format(t *testing.T) {
	// OTPService uses crypto.GenerateOTP internally. Test the generation
	// to ensure 6-digit format is always produced.
	tests := []struct {
		length int
	}{
		{4},
		{6},
		{8},
	}
	for _, tc := range tests {
		for i := 0; i < 50; i++ {
			otp, err := crypto.GenerateOTP(tc.length)
			if err != nil {
				t.Fatalf("GenerateOTP(%d) error: %v", tc.length, err)
			}
			if len(otp) != tc.length {
				t.Errorf("OTP length = %d, want %d (value: %s)", len(otp), tc.length, otp)
			}
			for _, c := range otp {
				if c < '0' || c > '9' {
					t.Errorf("OTP contains non-digit: %c (value: %s)", c, otp)
				}
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Documented expected behavior (requires Redis, not executed in unit tests)
// ---------------------------------------------------------------------------

// SendOTP expected behavior:
//
// 1. Generates a numeric OTP of the configured length using crypto.GenerateOTP.
// 2. Stores the OTP in Redis under the key "otp:<phone>" with the configured TTL.
// 3. In production, sends the OTP via SMS (Africa's Talking).
// 4. In dev mode, logs the OTP.
// 5. Returns nil on success, or an error if generation or Redis storage fails.
//
// Edge cases:
// - If Redis is unavailable, returns an error wrapping the Redis error.
// - Calling SendOTP twice for the same phone overwrites the previous OTP.
// - The OTP automatically expires after the TTL (default 5 minutes).

// VerifyOTP expected behavior:
//
// 1. Reads the stored OTP from Redis key "otp:<phone>".
// 2. If key does not exist (expired or never sent), returns (false, nil).
// 3. If key exists but code does not match, returns (false, nil).
// 4. If key exists and code matches, deletes the key and returns (true, nil).
// 5. Returns (false, error) only if Redis communication fails.
//
// Edge cases:
// - OTP is single-use: after successful verification, the key is deleted.
// - Expired OTPs return false (Redis handles TTL-based expiry).
// - Empty code never matches a real OTP (all OTPs are numeric with > 0 length).
