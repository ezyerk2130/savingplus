package user

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/pkg/config"
	"github.com/savingplus/backend/pkg/logger"
)

type Handler struct {
	db  *sql.DB
	cfg *config.Config
}

func NewHandler(db *sql.DB, cfg *config.Config) *Handler {
	return &Handler{db: db, cfg: cfg}
}

type ProfileResponse struct {
	ID        string  `json:"id"`
	Phone     string  `json:"phone"`
	Email     *string `json:"email"`
	FullName  string  `json:"full_name"`
	KYCStatus string  `json:"kyc_status"`
	KYCTier   int     `json:"kyc_tier"`
	Status    string  `json:"status"`
	CreatedAt string  `json:"created_at"`
}

type UpdateProfileRequest struct {
	FullName string `json:"full_name" binding:"omitempty,min=2,max=255"`
	Email    string `json:"email" binding:"omitempty,email"`
}

func (h *Handler) GetProfile(c *gin.Context) {
	log := logger.Ctx(c)

	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message})
		return
	}

	var p ProfileResponse
	var email sql.NullString
	err := h.db.QueryRowContext(c,
		`SELECT id, phone, email, full_name, kyc_status, kyc_tier, status, created_at
		 FROM users WHERE id = $1`,
		userID,
	).Scan(&p.ID, &p.Phone, &email, &p.FullName, &p.KYCStatus, &p.KYCTier, &p.Status, &p.CreatedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to get user profile")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if email.Valid {
		p.Email = &email.String
	}

	c.JSON(http.StatusOK, p)
}

func (h *Handler) UpdateProfile(c *gin.Context) {
	log := logger.Ctx(c)

	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message})
		return
	}

	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	if req.FullName != "" {
		_, err := h.db.ExecContext(c,
			`UPDATE users SET full_name = $1 WHERE id = $2`,
			req.FullName, userID,
		)
		if err != nil {
			log.WithError(err).WithField("user_id", userID).Error("Failed to update full name")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}
	}

	if req.Email != "" {
		_, err := h.db.ExecContext(c,
			`UPDATE users SET email = $1 WHERE id = $2`,
			req.Email, userID,
		)
		if err != nil {
			log.WithError(err).WithField("user_id", userID).Error("Failed to update email")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Profile updated successfully"})
}

func (h *Handler) GetTierLimits(c *gin.Context) {
	log := logger.Ctx(c)

	userID := c.GetString("user_id")

	var kycTier int
	err := h.db.QueryRowContext(c, `SELECT kyc_tier FROM users WHERE id = $1`, userID).Scan(&kycTier)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to get user KYC tier")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	var limits struct {
		DailyDeposit    string `json:"daily_deposit_limit"`
		DailyWithdrawal string `json:"daily_withdrawal_limit"`
		MaxBalance      string `json:"max_balance"`
		Description     string `json:"description"`
	}
	err = h.db.QueryRowContext(c,
		`SELECT daily_deposit_limit, daily_withdrawal_limit, max_balance, COALESCE(description, '')
		 FROM tier_limits WHERE kyc_tier = $1`,
		kycTier,
	).Scan(&limits.DailyDeposit, &limits.DailyWithdrawal, &limits.MaxBalance, &limits.Description)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to get tier limits")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"kyc_tier": kycTier,
		"limits":   limits,
	})
}
