package auth

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/pkg/config"
	"github.com/savingplus/backend/pkg/crypto"
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
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	// Check if user exists
	var exists bool
	err := h.db.QueryRowContext(c, "SELECT EXISTS(SELECT 1 FROM users WHERE phone = $1)", req.Phone).Scan(&exists)
	if err != nil {
		log.WithError(err).Error("Failed to check user existence")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	if exists {
		c.JSON(http.StatusConflict, gin.H{"error": apperr.ErrConflict.Message, "detail": "Phone number already registered"})
		return
	}

	// Hash password and PIN
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

	// Create user and wallet in a transaction
	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	userID := uuid.New()
	_, err = tx.ExecContext(c,
		`INSERT INTO users (id, phone, full_name, password_hash, pin_hash) VALUES ($1, $2, $3, $4, $5)`,
		userID, req.Phone, req.FullName, passwordHash, pinHash,
	)
	if err != nil {
		log.WithError(err).Error("Failed to insert user")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	walletID := uuid.New()
	_, err = tx.ExecContext(c,
		`INSERT INTO wallets (id, user_id) VALUES ($1, $2)`,
		walletID, userID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to create wallet")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Send OTP for phone verification
	if err := h.otpService.SendOTP(c, req.Phone); err != nil {
		log.WithError(err).Warn("Failed to send OTP after registration")
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "Registration successful. Please verify your phone with the OTP sent.",
		"user_id": userID.String(),
	})
}

func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	var userID, passwordHash, status string
	var failedAttempts int
	var lockedUntil sql.NullTime
	err := h.db.QueryRowContext(c,
		`SELECT id, password_hash, status, failed_login_attempts, locked_until FROM users WHERE phone = $1`,
		req.Phone,
	).Scan(&userID, &passwordHash, &status, &failedAttempts, &lockedUntil)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message, "detail": "Invalid credentials"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to query user")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Check account status
	if status == "locked" {
		if lockedUntil.Valid && lockedUntil.Time.After(time.Now()) {
			c.JSON(http.StatusForbidden, gin.H{"error": apperr.ErrAccountLocked.Message, "detail": "Account is temporarily locked"})
			return
		}
		// Unlock if lock period has passed
		h.db.ExecContext(c, `UPDATE users SET status = 'active', failed_login_attempts = 0 WHERE id = $1`, userID)
	}

	if status == "suspended" || status == "closed" {
		c.JSON(http.StatusForbidden, gin.H{"error": apperr.ErrAccountLocked.Message, "detail": "Account is " + status})
		return
	}

	// Verify password
	if !crypto.VerifyPassword(req.Password, passwordHash) {
		newAttempts := failedAttempts + 1
		if newAttempts >= 5 {
			lockUntil := time.Now().Add(30 * time.Minute)
			h.db.ExecContext(c,
				`UPDATE users SET failed_login_attempts = $1, status = 'locked', locked_until = $2 WHERE id = $3`,
				newAttempts, lockUntil, userID,
			)
		} else {
			h.db.ExecContext(c,
				`UPDATE users SET failed_login_attempts = $1 WHERE id = $2`,
				newAttempts, userID,
			)
		}
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message, "detail": "Invalid credentials"})
		return
	}

	// Reset failed attempts and update last login
	h.db.ExecContext(c,
		`UPDATE users SET failed_login_attempts = 0, last_login_at = NOW() WHERE id = $1`,
		userID,
	)

	// Generate token pair
	tokenPair, refreshTokenHash, err := h.jwt.GenerateTokenPair(userID, req.Phone, "user")
	if err != nil {
		log.WithError(err).Error("Failed to generate tokens")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Store refresh token
	_, err = h.db.ExecContext(c,
		`INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)`,
		uuid.New(), userID, refreshTokenHash, time.Now().Add(h.jwt.RefreshTokenTTL()),
	)
	if err != nil {
		log.WithError(err).Error("Failed to store refresh token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, tokenPair)
}

func (h *Handler) RefreshToken(c *gin.Context) {
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
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message, "detail": "Invalid refresh token"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to query refresh token")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if revoked || time.Now().After(expiresAt) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message, "detail": "Refresh token expired or revoked"})
		return
	}

	// Revoke old token (rotation)
	h.db.ExecContext(c, `UPDATE refresh_tokens SET revoked = TRUE WHERE id = $1`, tokenID)

	// Generate new pair
	tokenPair, newRefreshHash, err := h.jwt.GenerateTokenPair(userID, phone, "user")
	if err != nil {
		log.WithError(err).Error("Failed to generate new tokens")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Store new refresh token
	_, err = h.db.ExecContext(c,
		`INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)`,
		uuid.New(), userID, newRefreshHash, time.Now().Add(h.jwt.RefreshTokenTTL()),
	)
	if err != nil {
		log.WithError(err).Error("Failed to store new refresh token")
	}

	c.JSON(http.StatusOK, tokenPair)
}

func (h *Handler) VerifyOTP(c *gin.Context) {
	var req VerifyOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	valid, err := h.otpService.VerifyOTP(c, req.Phone, req.Code)
	if err != nil {
		log.WithError(err).Error("Failed to verify OTP")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if !valid {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrOTPInvalid.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "OTP verified successfully", "verified": true})
}

func (h *Handler) SendOTP(c *gin.Context) {
	var req struct {
		Phone string `json:"phone" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	if err := h.otpService.SendOTP(c, req.Phone); err != nil {
		log.WithError(err).Error("Failed to send OTP")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "OTP sent successfully"})
}
