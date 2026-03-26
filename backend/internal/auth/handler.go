package auth

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/pkg/config"
	"github.com/savingplus/backend/pkg/crypto"
	"github.com/savingplus/backend/pkg/logger"
)

type Handler struct {
	db         *sql.DB
	jwt        *JWTService
	otpService *OTPService
	cfg        *config.Config
}

func NewHandler(db *sql.DB, jwtSvc *JWTService, otpSvc *OTPService, cfg *config.Config) *Handler {
	return &Handler{db: db, jwt: jwtSvc, otpService: otpSvc, cfg: cfg}
}

type RegisterRequest struct {
	Phone    string `json:"phone" binding:"required,min=10,max=15"`
	FullName string `json:"full_name" binding:"required,min=2,max=255"`
	Password string `json:"password" binding:"required,min=8,max=128"`
	PIN      string `json:"pin" binding:"required,len=4"`
}

type LoginRequest struct {
	Phone    string `json:"phone" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type VerifyOTPRequest struct {
	Phone string `json:"phone" binding:"required"`
	Code  string `json:"code" binding:"required,len=6"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

func (h *Handler) Register(c *gin.Context) {
	log := logger.Ctx(c)

	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	log = log.WithField("phone", req.Phone)

	var exists bool
	if err := h.db.QueryRowContext(c, "SELECT EXISTS(SELECT 1 FROM users WHERE phone = $1)", req.Phone).Scan(&exists); err != nil {
		log.WithError(err).Error("Failed to check user existence")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	if exists {
		log.Warn("Registration attempt with existing phone")
		c.JSON(http.StatusConflict, gin.H{"error": apperr.ErrConflict.Message, "detail": "Phone number already registered"})
		return
	}

	passwordHash, err := crypto.HashPassword(req.Password)
	if err != nil {
		log.WithError(err).Error("Failed to hash password")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	pinHash, err := crypto.HashPassword(req.PIN)
	if err != nil {
		log.WithError(err).Error("Failed to hash PIN")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin registration transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	userID := uuid.New()
	if _, err = tx.ExecContext(c,
		`INSERT INTO users (id, phone, full_name, password_hash, pin_hash) VALUES ($1, $2, $3, $4, $5)`,
		userID, req.Phone, req.FullName, passwordHash, pinHash,
	); err != nil {
		log.WithError(err).Error("Failed to insert user")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	walletID := uuid.New()
	if _, err = tx.ExecContext(c,
		`INSERT INTO wallets (id, user_id) VALUES ($1, $2)`,
		walletID, userID,
	); err != nil {
		log.WithError(err).Error("Failed to create wallet")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit registration transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := h.otpService.SendOTP(c, req.Phone); err != nil {
		log.WithError(err).Warn("Failed to send OTP after registration")
	}

	log.WithField("user_id", userID.String()).Info("User registered successfully")

	c.JSON(http.StatusCreated, gin.H{
		"message": "Registration successful. Please verify your phone with the OTP sent.",
		"user_id": userID.String(),
	})
}

func (h *Handler) Login(c *gin.Context) {
	log := logger.Ctx(c)

	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	log = log.WithField("phone", req.Phone)

	var userID, passwordHash, status string
	var failedAttempts int
	var lockedUntil sql.NullTime
	err := h.db.QueryRowContext(c,
		`SELECT id, password_hash, status, failed_login_attempts, locked_until FROM users WHERE phone = $1`,
		req.Phone,
	).Scan(&userID, &passwordHash, &status, &failedAttempts, &lockedUntil)
	if err == sql.ErrNoRows {
		log.Debug("Login attempt for non-existent phone")
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message, "detail": "Invalid credentials"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to query user for login")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	log = log.WithField("user_id", userID)

	if status == "locked" {
		if lockedUntil.Valid && lockedUntil.Time.After(time.Now()) {
			log.Warn("Login attempt on locked account")
			c.JSON(http.StatusForbidden, gin.H{"error": apperr.ErrAccountLocked.Message, "detail": "Account is temporarily locked"})
			return
		}
		if _, err := h.db.ExecContext(c, `UPDATE users SET status = 'active', failed_login_attempts = 0 WHERE id = $1`, userID); err != nil {
			log.WithError(err).Error("Failed to auto-unlock expired lock")
		}
	}

	if status == "suspended" || status == "closed" {
		log.WithField("status", status).Warn("Login attempt on inactive account")
		c.JSON(http.StatusForbidden, gin.H{"error": apperr.ErrAccountLocked.Message, "detail": "Account is " + status})
		return
	}

	if !crypto.VerifyPassword(req.Password, passwordHash) {
		newAttempts := failedAttempts + 1
		if newAttempts >= 5 {
			lockUntil := time.Now().Add(30 * time.Minute)
			if _, err := h.db.ExecContext(c,
				`UPDATE users SET failed_login_attempts = $1, status = 'locked', locked_until = $2 WHERE id = $3`,
				newAttempts, lockUntil, userID,
			); err != nil {
				log.WithError(err).Error("Failed to lock account after max attempts")
			}
			log.WithField("attempts", newAttempts).Warn("Account locked after failed login attempts")
		} else {
			if _, err := h.db.ExecContext(c,
				`UPDATE users SET failed_login_attempts = $1 WHERE id = $2`,
				newAttempts, userID,
			); err != nil {
				log.WithError(err).Error("Failed to increment failed login attempts")
			}
		}
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message, "detail": "Invalid credentials"})
		return
	}

	if _, err := h.db.ExecContext(c,
		`UPDATE users SET failed_login_attempts = 0, last_login_at = NOW() WHERE id = $1`,
		userID,
	); err != nil {
		log.WithError(err).Error("Failed to reset login attempts")
	}

	tokenPair, refreshTokenHash, err := h.jwt.GenerateTokenPair(userID, req.Phone, "user")
	if err != nil {
		log.WithError(err).Error("Failed to generate token pair")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if _, err = h.db.ExecContext(c,
		`INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)`,
		uuid.New(), userID, refreshTokenHash, time.Now().Add(h.jwt.RefreshTokenTTL()),
	); err != nil {
		log.WithError(err).Error("Failed to store refresh token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	log.Info("User logged in successfully")
	c.JSON(http.StatusOK, tokenPair)
}

func (h *Handler) RefreshToken(c *gin.Context) {
	log := logger.Ctx(c)

	var req RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	tokenHash := HashRefreshToken(req.RefreshToken)

	var tokenID, userID, phone string
	var expiresAt time.Time
	var revoked bool
	err := h.db.QueryRowContext(c,
		`SELECT rt.id, rt.user_id, u.phone, rt.expires_at, rt.revoked
		 FROM refresh_tokens rt JOIN users u ON rt.user_id = u.id
		 WHERE rt.token_hash = $1`,
		tokenHash,
	).Scan(&tokenID, &userID, &phone, &expiresAt, &revoked)
	if err == sql.ErrNoRows {
		log.Debug("Refresh attempt with invalid token")
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message, "detail": "Invalid refresh token"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to query refresh token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	log = log.WithField("user_id", userID)

	if revoked || time.Now().After(expiresAt) {
		log.Warn("Refresh attempt with expired/revoked token")
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message, "detail": "Refresh token expired or revoked"})
		return
	}

	if _, err := h.db.ExecContext(c, `UPDATE refresh_tokens SET revoked = TRUE WHERE id = $1`, tokenID); err != nil {
		log.WithError(err).Error("Failed to revoke old refresh token")
	}

	tokenPair, newRefreshHash, err := h.jwt.GenerateTokenPair(userID, phone, "user")
	if err != nil {
		log.WithError(err).Error("Failed to generate new token pair")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if _, err = h.db.ExecContext(c,
		`INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)`,
		uuid.New(), userID, newRefreshHash, time.Now().Add(h.jwt.RefreshTokenTTL()),
	); err != nil {
		log.WithError(err).Error("Failed to store new refresh token")
	}

	log.Info("Token refreshed successfully")
	c.JSON(http.StatusOK, tokenPair)
}

func (h *Handler) VerifyOTP(c *gin.Context) {
	log := logger.Ctx(c)

	var req VerifyOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	log = log.WithField("phone", req.Phone)

	valid, err := h.otpService.VerifyOTP(c, req.Phone, req.Code)
	if err != nil {
		log.WithError(err).Error("Failed to verify OTP")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if !valid {
		log.Warn("Invalid OTP attempt")
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrOTPInvalid.Message})
		return
	}

	log.Info("OTP verified successfully")
	c.JSON(http.StatusOK, gin.H{"message": "OTP verified successfully", "verified": true})
}

func (h *Handler) SendOTP(c *gin.Context) {
	log := logger.Ctx(c)

	var req struct {
		Phone string `json:"phone" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	if err := h.otpService.SendOTP(c, req.Phone); err != nil {
		log.WithError(err).WithField("phone", req.Phone).Error("Failed to send OTP")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	log.WithField("phone", req.Phone).Info("OTP sent")
	c.JSON(http.StatusOK, gin.H{"message": "OTP sent successfully"})
}

// ChangePassword allows authenticated users to change their password
func (h *Handler) ChangePassword(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	var req struct {
		CurrentPassword string `json:"current_password" binding:"required"`
		NewPassword     string `json:"new_password" binding:"required,min=8,max=128"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	log = log.WithField("user_id", userID)

	var currentHash string
	err := h.db.QueryRowContext(c, `SELECT password_hash FROM users WHERE id = $1`, userID).Scan(&currentHash)
	if err != nil {
		log.WithError(err).Error("Failed to get current password hash")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if !crypto.VerifyPassword(req.CurrentPassword, currentHash) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Current password is incorrect"})
		return
	}

	newHash, err := crypto.HashPassword(req.NewPassword)
	if err != nil {
		log.WithError(err).Error("Failed to hash new password")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if _, err = h.db.ExecContext(c, `UPDATE users SET password_hash = $1 WHERE id = $2`, newHash, userID); err != nil {
		log.WithError(err).Error("Failed to update password")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Revoke all refresh tokens to force re-login on other devices
	if _, err = h.db.ExecContext(c, `UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = $1`, userID); err != nil {
		log.WithError(err).Warn("Failed to revoke refresh tokens after password change")
	}

	log.Info("Password changed successfully")
	c.JSON(http.StatusOK, gin.H{"message": "Password changed successfully. Please log in again on other devices."})
}

// ChangePIN allows authenticated users to change their transaction PIN
func (h *Handler) ChangePIN(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	var req struct {
		CurrentPIN string `json:"current_pin" binding:"required,len=4"`
		NewPIN     string `json:"new_pin" binding:"required,len=4"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	log = log.WithField("user_id", userID)

	var currentHash string
	err := h.db.QueryRowContext(c, `SELECT pin_hash FROM users WHERE id = $1`, userID).Scan(&currentHash)
	if err != nil {
		log.WithError(err).Error("Failed to get current PIN hash")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if !crypto.VerifyPassword(req.CurrentPIN, currentHash) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Current PIN is incorrect"})
		return
	}

	newHash, err := crypto.HashPassword(req.NewPIN)
	if err != nil {
		log.WithError(err).Error("Failed to hash new PIN")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if _, err = h.db.ExecContext(c, `UPDATE users SET pin_hash = $1 WHERE id = $2`, newHash, userID); err != nil {
		log.WithError(err).Error("Failed to update PIN")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	log.Info("PIN changed successfully")
	c.JSON(http.StatusOK, gin.H{"message": "Transaction PIN changed successfully"})
}

// Logout revokes the user's refresh token
func (h *Handler) Logout(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	tokenHash := HashRefreshToken(req.RefreshToken)
	if _, err := h.db.ExecContext(c,
		`UPDATE refresh_tokens SET revoked = TRUE WHERE token_hash = $1 AND user_id = $2`,
		tokenHash, userID,
	); err != nil {
		log.WithError(err).Error("Failed to revoke refresh token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
}
