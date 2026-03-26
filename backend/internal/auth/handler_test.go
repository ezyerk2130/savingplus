package auth_test

import (
	"net/http"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/savingplus/backend/internal/auth"
	"github.com/savingplus/backend/internal/testutil"
	"github.com/savingplus/backend/pkg/config"
)

// newTestHandler creates an auth.Handler with nil DB and OTP service.
// This is sufficient for testing input validation since the handler returns
// a 400 error before any DB or OTP call when the request body is invalid.
func newTestHandler() *auth.Handler {
	cfg := &config.Config{}
	jwtSvc := auth.NewJWTService("test-secret-key-for-unit-tests-only", 15*time.Minute, 7*24*time.Hour)
	// DB and OTP are nil; validation errors trigger before they are used.
	return auth.NewHandler(nil, jwtSvc, nil, cfg)
}

func setupAuthRouter(h *auth.Handler) *gin.Engine {
	r := testutil.SetupRouter()
	v1 := r.Group("/api/v1/auth")
	{
		v1.POST("/register", h.Register)
		v1.POST("/login", h.Login)
		v1.POST("/refresh", h.RefreshToken)
		v1.POST("/verify-otp", h.VerifyOTP)
		v1.POST("/send-otp", h.SendOTP)
		v1.POST("/change-password", h.ChangePassword)
		v1.POST("/change-pin", h.ChangePIN)
		v1.POST("/logout", h.Logout)
	}
	return r
}

// ---------------------------------------------------------------------------
// Register
// ---------------------------------------------------------------------------

func TestRegister_MissingAllFields(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/register", map[string]string{})
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
	resp := testutil.ParseResponse(w)
	if resp["error"] == nil {
		t.Error("expected error field in response")
	}
}

func TestRegister_MissingPhone(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{
		"full_name": "John Doe",
		"password":  "securepass123",
		"pin":       "1234",
	}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/register", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestRegister_ShortPassword(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{
		"phone":     "+255712345678",
		"full_name": "John Doe",
		"password":  "short",
		"pin":       "1234",
	}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/register", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400 for short password, got %d", w.Code)
	}
	resp := testutil.ParseResponse(w)
	if resp["detail"] == nil {
		t.Error("expected detail field describing the validation error")
	}
}

func TestRegister_InvalidPINLength(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	// PIN too short
	body := map[string]string{
		"phone":     "+255712345678",
		"full_name": "John Doe",
		"password":  "securepass123",
		"pin":       "12",
	}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/register", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400 for short PIN, got %d", w.Code)
	}

	// PIN too long
	body["pin"] = "123456"
	w = testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/register", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400 for long PIN, got %d", w.Code)
	}
}

func TestRegister_MissingFullName(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{
		"phone":    "+255712345678",
		"password": "securepass123",
		"pin":      "1234",
	}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/register", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestRegister_InvalidJSON(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	// Send a string that is not valid JSON for the expected struct
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/register", "not-json")
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400 for invalid JSON, got %d", w.Code)
	}
}

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

func TestLogin_MissingAllFields(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/login", map[string]string{})
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestLogin_MissingPassword(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{"phone": "+255712345678"}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/login", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestLogin_MissingPhone(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{"password": "securepass123"}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/login", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

// ---------------------------------------------------------------------------
// RefreshToken
// ---------------------------------------------------------------------------

func TestRefreshToken_MissingToken(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/refresh", map[string]string{})
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
	resp := testutil.ParseResponse(w)
	if resp["error"] == nil {
		t.Error("expected error field in response")
	}
}

func TestRefreshToken_EmptyBody(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/refresh", nil)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

// ---------------------------------------------------------------------------
// VerifyOTP
// ---------------------------------------------------------------------------

func TestVerifyOTP_MissingAllFields(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/verify-otp", map[string]string{})
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestVerifyOTP_MissingCode(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{"phone": "+255712345678"}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/verify-otp", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestVerifyOTP_InvalidCodeLength(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{
		"phone": "+255712345678",
		"code":  "12",
	}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/verify-otp", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400 for short OTP code, got %d", w.Code)
	}
}

func TestVerifyOTP_MissingPhone(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{"code": "123456"}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/verify-otp", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

// ---------------------------------------------------------------------------
// SendOTP
// ---------------------------------------------------------------------------

func TestSendOTP_MissingPhone(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/send-otp", map[string]string{})
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
	resp := testutil.ParseResponse(w)
	if resp["error"] == nil {
		t.Error("expected error field in response")
	}
}

func TestSendOTP_EmptyBody(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/send-otp", nil)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

// ---------------------------------------------------------------------------
// ChangePassword
// ---------------------------------------------------------------------------

func TestChangePassword_MissingAllFields(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/change-password", map[string]string{})
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestChangePassword_MissingCurrentPassword(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{"new_password": "newpassword123"}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/change-password", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestChangePassword_NewPasswordTooShort(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{
		"current_password": "oldpassword123",
		"new_password":     "short",
	}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/change-password", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400 for short new password, got %d", w.Code)
	}
}

func TestChangePassword_MissingNewPassword(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{"current_password": "oldpassword123"}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/change-password", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

// ---------------------------------------------------------------------------
// ChangePIN
// ---------------------------------------------------------------------------

func TestChangePIN_MissingAllFields(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/change-pin", map[string]string{})
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestChangePIN_InvalidCurrentPINLength(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{
		"current_pin": "12",
		"new_pin":     "5678",
	}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/change-pin", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400 for invalid current PIN length, got %d", w.Code)
	}
}

func TestChangePIN_InvalidNewPINLength(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{
		"current_pin": "1234",
		"new_pin":     "56",
	}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/change-pin", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400 for invalid new PIN length, got %d", w.Code)
	}
}

func TestChangePIN_MissingNewPIN(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	body := map[string]string{"current_pin": "1234"}
	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/change-pin", body)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

// ---------------------------------------------------------------------------
// Logout
// ---------------------------------------------------------------------------

func TestLogout_MissingRefreshToken(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodPost, "/api/v1/auth/logout", map[string]string{})
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

// ---------------------------------------------------------------------------
// Wrong HTTP method
// ---------------------------------------------------------------------------

func TestRegister_WrongMethod(t *testing.T) {
	h := newTestHandler()
	r := setupAuthRouter(h)

	w := testutil.MakeRequest(r, http.MethodGet, "/api/v1/auth/register", nil)
	if w.Code != http.StatusNotFound && w.Code != http.StatusMethodNotAllowed {
		t.Errorf("expected 404 or 405 for GET on register, got %d", w.Code)
	}
}
