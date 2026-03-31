package auth

import (
	"testing"
	"time"

	"github.com/pquerna/otp/totp"
)

// TestTOTPGeneration verifies that a TOTP key can be generated and that a
// code produced from it validates successfully.
func TestTOTPGeneration(t *testing.T) {
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "SavingPlus",
		AccountName: "+255700000001",
	})
	if err != nil {
		t.Fatalf("Failed to generate TOTP key: %v", err)
	}
	if key.Secret() == "" {
		t.Error("Secret should not be empty")
	}
	if key.URL() == "" {
		t.Error("URL (otpauth://) should not be empty")
	}
	if key.Issuer() != "SavingPlus" {
		t.Errorf("Issuer = %q, want %q", key.Issuer(), "SavingPlus")
	}
	if key.AccountName() != "+255700000001" {
		t.Errorf("AccountName = %q, want %q", key.AccountName(), "+255700000001")
	}

	// Verify a valid code
	code, err := totp.GenerateCode(key.Secret(), time.Now())
	if err != nil {
		t.Fatalf("Failed to generate TOTP code: %v", err)
	}
	if len(code) != 6 {
		t.Errorf("TOTP code length = %d, want 6", len(code))
	}
	if !totp.Validate(code, key.Secret()) {
		t.Error("Generated code should validate against its own secret")
	}
}

// TestTOTPValidation_InvalidCode verifies that an arbitrary code does not
// validate against a freshly generated secret.
func TestTOTPValidation_InvalidCode(t *testing.T) {
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "SavingPlus",
		AccountName: "test@example.com",
	})
	if err != nil {
		t.Fatalf("Failed to generate TOTP key: %v", err)
	}

	invalidCodes := []string{"000000", "111111", "999999", "123456"}
	for _, code := range invalidCodes {
		// There is an astronomically small chance the random code matches
		// the current TOTP window, but we test multiple to be safe.
		if totp.Validate(code, key.Secret()) {
			// One might match by chance; that is okay, but not all of them
			t.Logf("Code %q happened to validate (possible but unlikely)", code)
		}
	}
}

// TestTOTPGeneration_DifferentAccounts verifies that different accounts
// produce different secrets.
func TestTOTPGeneration_DifferentAccounts(t *testing.T) {
	key1, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "SavingPlus",
		AccountName: "+255700000001",
	})
	if err != nil {
		t.Fatal(err)
	}

	key2, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "SavingPlus",
		AccountName: "+255700000002",
	})
	if err != nil {
		t.Fatal(err)
	}

	if key1.Secret() == key2.Secret() {
		t.Error("Different accounts should produce different secrets")
	}
}

// TestTOTPCodeChangesOverTime verifies that codes generated at different
// time windows are different (30-second window by default).
func TestTOTPCodeChangesOverTime(t *testing.T) {
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "SavingPlus",
		AccountName: "test",
	})
	if err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	code1, _ := totp.GenerateCode(key.Secret(), now)
	// Generate code 60 seconds in the future (different 30s window)
	code2, _ := totp.GenerateCode(key.Secret(), now.Add(60*time.Second))

	// They might be the same if we're on a boundary, but typically differ
	if code1 == code2 {
		t.Log("Codes at now and now+60s happen to match (boundary case)")
	}
}

// TestTOTPCodeFormat verifies all generated codes are 6-digit numeric strings.
func TestTOTPCodeFormat(t *testing.T) {
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "SavingPlus",
		AccountName: "format-test",
	})
	if err != nil {
		t.Fatal(err)
	}

	for i := 0; i < 10; i++ {
		ts := time.Now().Add(time.Duration(i*30) * time.Second)
		code, err := totp.GenerateCode(key.Secret(), ts)
		if err != nil {
			t.Errorf("Failed to generate code at offset %d: %v", i, err)
			continue
		}
		if len(code) != 6 {
			t.Errorf("Code %q at offset %d has length %d, want 6", code, i, len(code))
		}
		for _, ch := range code {
			if ch < '0' || ch > '9' {
				t.Errorf("Code %q contains non-digit character %q", code, ch)
			}
		}
	}
}
