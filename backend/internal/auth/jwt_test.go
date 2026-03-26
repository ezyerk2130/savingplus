package auth

import (
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const testSecret = "test-jwt-secret-key-for-unit-tests"

func newTestJWTService() *JWTService {
	return NewJWTService(testSecret, 15*time.Minute, 7*24*time.Hour)
}

// ---------------------------------------------------------------------------
// GenerateTokenPair
// ---------------------------------------------------------------------------

func TestGenerateTokenPair_Success(t *testing.T) {
	svc := newTestJWTService()
	pair, refreshHash, err := svc.GenerateTokenPair("user-123", "+255700000000", "customer")
	if err != nil {
		t.Fatalf("GenerateTokenPair error: %v", err)
	}

	if pair.AccessToken == "" {
		t.Error("AccessToken is empty")
	}
	if pair.RefreshToken == "" {
		t.Error("RefreshToken is empty")
	}
	if refreshHash == "" {
		t.Error("refresh token hash is empty")
	}
	if pair.TokenType != "Bearer" {
		t.Errorf("TokenType = %q, want 'Bearer'", pair.TokenType)
	}
	if pair.ExpiresIn != int64((15 * time.Minute).Seconds()) {
		t.Errorf("ExpiresIn = %d, want %d", pair.ExpiresIn, int64((15*time.Minute).Seconds()))
	}
}

func TestGenerateTokenPair_ClaimsCorrect(t *testing.T) {
	svc := newTestJWTService()
	pair, _, err := svc.GenerateTokenPair("user-456", "+255711111111", "admin")
	if err != nil {
		t.Fatalf("error: %v", err)
	}

	claims, err := svc.ValidateAccessToken(pair.AccessToken)
	if err != nil {
		t.Fatalf("ValidateAccessToken error: %v", err)
	}

	if claims.UserID != "user-456" {
		t.Errorf("UserID = %q, want 'user-456'", claims.UserID)
	}
	if claims.Phone != "+255711111111" {
		t.Errorf("Phone = %q, want '+255711111111'", claims.Phone)
	}
	if claims.Role != "admin" {
		t.Errorf("Role = %q, want 'admin'", claims.Role)
	}
	if claims.Issuer != "savingplus" {
		t.Errorf("Issuer = %q, want 'savingplus'", claims.Issuer)
	}
	if claims.Subject != "user-456" {
		t.Errorf("Subject = %q, want 'user-456'", claims.Subject)
	}
	if claims.ID == "" {
		t.Error("JWT ID (jti) is empty")
	}
}

func TestGenerateTokenPair_UniqueTokens(t *testing.T) {
	svc := newTestJWTService()
	p1, h1, _ := svc.GenerateTokenPair("user-1", "+255700000001", "")
	p2, h2, _ := svc.GenerateTokenPair("user-1", "+255700000001", "")

	if p1.AccessToken == p2.AccessToken {
		t.Error("two calls should produce different access tokens")
	}
	if p1.RefreshToken == p2.RefreshToken {
		t.Error("two calls should produce different refresh tokens")
	}
	if h1 == h2 {
		t.Error("two calls should produce different refresh token hashes")
	}
}

func TestGenerateTokenPair_RefreshHashMatchesToken(t *testing.T) {
	svc := newTestJWTService()
	pair, hash, _ := svc.GenerateTokenPair("user-1", "+255700000001", "")
	computed := HashRefreshToken(pair.RefreshToken)
	if hash != computed {
		t.Errorf("returned hash does not match HashRefreshToken of the raw refresh token")
	}
}

// ---------------------------------------------------------------------------
// ValidateAccessToken
// ---------------------------------------------------------------------------

func TestValidateAccessToken_Valid(t *testing.T) {
	svc := newTestJWTService()
	pair, _, _ := svc.GenerateTokenPair("user-1", "+255700000001", "customer")

	claims, err := svc.ValidateAccessToken(pair.AccessToken)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if claims.UserID != "user-1" {
		t.Errorf("UserID = %q, want 'user-1'", claims.UserID)
	}
}

func TestValidateAccessToken_Expired(t *testing.T) {
	// Create a service with 0 TTL (tokens expire immediately)
	svc := NewJWTService(testSecret, -1*time.Second, 7*24*time.Hour)
	pair, _, _ := svc.GenerateTokenPair("user-1", "+255700000001", "")

	_, err := svc.ValidateAccessToken(pair.AccessToken)
	if err == nil {
		t.Error("expected error for expired token")
	}
}

func TestValidateAccessToken_WrongSecret(t *testing.T) {
	svc1 := NewJWTService("secret-one", 15*time.Minute, 7*24*time.Hour)
	svc2 := NewJWTService("secret-two", 15*time.Minute, 7*24*time.Hour)

	pair, _, _ := svc1.GenerateTokenPair("user-1", "+255700000001", "")
	_, err := svc2.ValidateAccessToken(pair.AccessToken)
	if err == nil {
		t.Error("expected error when validating with wrong secret")
	}
}

func TestValidateAccessToken_MalformedToken(t *testing.T) {
	svc := newTestJWTService()

	tests := []struct {
		name  string
		token string
	}{
		{"empty", ""},
		{"random string", "not.a.jwt"},
		{"partial jwt", "eyJhbGciOiJIUzI1NiJ9."},
		{"tampered payload", func() string {
			pair, _, _ := svc.GenerateTokenPair("user-1", "+255700000001", "")
			parts := strings.SplitN(pair.AccessToken, ".", 3)
			// Tamper with the payload
			parts[1] = "dGFtcGVyZWQ" // base64("tampered")
			return strings.Join(parts, ".")
		}()},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := svc.ValidateAccessToken(tc.token)
			if err == nil {
				t.Error("expected error for malformed token")
			}
		})
	}
}

func TestValidateAccessToken_WrongSigningMethod(t *testing.T) {
	// Create a token with "none" signing method
	claims := &Claims{
		UserID: "user-1",
		Phone:  "+255700000001",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodNone, claims)
	tokenStr, _ := token.SignedString(jwt.UnsafeAllowNoneSignatureType)

	svc := newTestJWTService()
	_, err := svc.ValidateAccessToken(tokenStr)
	if err == nil {
		t.Error("expected error for 'none' signing method")
	}
}

// ---------------------------------------------------------------------------
// HashRefreshToken
// ---------------------------------------------------------------------------

func TestHashRefreshToken_Deterministic(t *testing.T) {
	h1 := HashRefreshToken("some-token-value")
	h2 := HashRefreshToken("some-token-value")
	if h1 != h2 {
		t.Error("same input should produce same hash")
	}
}

func TestHashRefreshToken_DifferentInputs(t *testing.T) {
	h1 := HashRefreshToken("token-a")
	h2 := HashRefreshToken("token-b")
	if h1 == h2 {
		t.Error("different inputs should produce different hashes")
	}
}

func TestHashRefreshToken_Length(t *testing.T) {
	h := HashRefreshToken("any-token")
	// SHA-256 produces 32 bytes = 64 hex characters
	if len(h) != 64 {
		t.Errorf("hash length = %d, want 64", len(h))
	}
}

// ---------------------------------------------------------------------------
// RefreshTokenTTL
// ---------------------------------------------------------------------------

func TestRefreshTokenTTL(t *testing.T) {
	ttl := 7 * 24 * time.Hour
	svc := NewJWTService("secret", 15*time.Minute, ttl)
	if svc.RefreshTokenTTL() != ttl {
		t.Errorf("RefreshTokenTTL = %v, want %v", svc.RefreshTokenTTL(), ttl)
	}
}
