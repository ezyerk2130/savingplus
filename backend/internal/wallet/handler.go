package wallet

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/internal/queue"
	"github.com/savingplus/backend/pkg/config"
	"github.com/savingplus/backend/pkg/crypto"
	"github.com/savingplus/backend/pkg/logger"
	"github.com/savingplus/backend/pkg/response"
)

type Handler struct {
	db    *sql.DB
	redis *redis.Client
	queue *queue.Client
	cfg   *config.Config
}

func NewHandler(db *sql.DB, rdb *redis.Client, queueClient *queue.Client, cfg *config.Config) *Handler {
	return &Handler{db: db, redis: rdb, queue: queueClient, cfg: cfg}
}

type BalanceResponse struct {
	WalletID         string `json:"wallet_id"`
	Currency         string `json:"currency"`
	AvailableBalance string `json:"available_balance"`
	LockedBalance    string `json:"locked_balance"`
	TotalBalance     string `json:"total_balance"`
}

type DepositRequest struct {
	Amount         float64 `json:"amount" binding:"required,gt=0"`
	PaymentMethod  string  `json:"payment_method" binding:"required,oneof=mpesa tigopesa airtel halopesa"`
	PhoneNumber    string  `json:"phone_number" binding:"required"`
	IdempotencyKey string  `json:"idempotency_key" binding:"required,min=16,max=64"`
}

type WithdrawRequest struct {
	Amount         float64 `json:"amount" binding:"required,gt=0"`
	PIN            string  `json:"pin" binding:"required,len=4"`
	PaymentMethod  string  `json:"payment_method" binding:"required,oneof=mpesa tigopesa airtel halopesa"`
	PhoneNumber    string  `json:"phone_number" binding:"required"`
	IdempotencyKey string  `json:"idempotency_key" binding:"required,min=16,max=64"`
	OTPCode        string  `json:"otp_code,omitempty"`
}

func (h *Handler) GetBalance(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	log = log.WithField("user_id", userID)

	var resp BalanceResponse
	var available, locked float64
	err := h.db.QueryRowContext(c,
		`SELECT id, currency, available_balance, locked_balance FROM wallets WHERE user_id = $1 AND currency = 'TZS'`,
		userID,
	).Scan(&resp.WalletID, &resp.Currency, &available, &locked)
	if err != nil {
		log.WithError(err).Error("Failed to get wallet balance")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	resp.AvailableBalance = response.FormatMoney(available)
	resp.LockedBalance = response.FormatMoney(locked)
	resp.TotalBalance = response.FormatMoney(available + locked)

	c.JSON(http.StatusOK, resp)
}

func (h *Handler) Deposit(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	log = log.WithField("user_id", userID)

	var req DepositRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	// Check idempotency
	idemKey := fmt.Sprintf("idempotency:%s", req.IdempotencyKey)
	exists, err := h.redis.Exists(c, idemKey).Result()
	if err != nil {
		log.WithError(err).Warn("Redis error during idempotency check, continuing request")
	} else if exists > 0 {
		// Return cached response
		cached, err := h.redis.Get(c, idemKey).Result()
		if err != nil {
			log.WithError(err).Warn("Redis error fetching cached idempotency response")
		} else {
			c.Data(http.StatusOK, "application/json", []byte(cached))
			return
		}
	}

	// Check tier limits
	if err := h.checkDepositLimits(c, userID, req.Amount); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get wallet
	var walletID string
	err = h.db.QueryRowContext(c, `SELECT id FROM wallets WHERE user_id = $1 AND currency = 'TZS'`, userID).Scan(&walletID)
	if err != nil {
		log.WithError(err).Error("Failed to get wallet")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create pending transaction
	txnID := uuid.New()
	ref := fmt.Sprintf("DEP-%s-%d", txnID.String()[:8], time.Now().UnixMilli())

	metadata, err := json.Marshal(map[string]string{"payment_method": req.PaymentMethod, "phone_number": req.PhoneNumber})
	if err != nil {
		log.WithError(err).Error("Failed to marshal deposit metadata")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	_, err = h.db.ExecContext(c,
		`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, reference, idempotency_key, metadata)
		 VALUES ($1, $2, $3, 'deposit', 'pending', $4, $5, $6, $7)`,
		txnID, userID, walletID, req.Amount, ref, req.IdempotencyKey, metadata,
	)
	if err != nil {
		log.WithError(err).Error("Failed to create deposit transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Enqueue async payment job
	if err := h.queue.EnqueueDeposit(queue.PaymentPayload{
		TransactionID: txnID.String(),
		PhoneNumber:   req.PhoneNumber,
		Amount:        req.Amount,
		Currency:      "TZS",
		Reference:     ref,
		PaymentMethod: req.PaymentMethod,
	}); err != nil {
		log.WithError(err).Error("Failed to enqueue deposit job")
	}

	resp := gin.H{
		"transaction_id": txnID.String(),
		"reference":      ref,
		"status":         "pending",
		"message":        "Deposit initiated. You will receive a mobile money prompt shortly.",
	}

	// Cache response for idempotency (24h)
	if err := h.redis.Set(c, idemKey, fmt.Sprintf(`{"transaction_id":"%s","reference":"%s","status":"pending"}`, txnID, ref), 24*time.Hour).Err(); err != nil {
		log.WithError(err).Warn("Redis error caching idempotency response")
	}

	c.JSON(http.StatusAccepted, resp)
}

func (h *Handler) Withdraw(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	log = log.WithField("user_id", userID)

	var req WithdrawRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	// Check idempotency
	idemKey := fmt.Sprintf("idempotency:%s", req.IdempotencyKey)
	exists, err := h.redis.Exists(c, idemKey).Result()
	if err != nil {
		log.WithError(err).Warn("Redis error during idempotency check, continuing request")
	} else if exists > 0 {
		cached, err := h.redis.Get(c, idemKey).Result()
		if err != nil {
			log.WithError(err).Warn("Redis error fetching cached idempotency response")
		} else {
			c.Data(http.StatusOK, "application/json", []byte(cached))
			return
		}
	}

	// Verify PIN
	var pinHash string
	err = h.db.QueryRowContext(c, `SELECT pin_hash FROM users WHERE id = $1`, userID).Scan(&pinHash)
	if err != nil {
		log.WithError(err).Error("Failed to get user PIN")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if !crypto.VerifyPassword(req.PIN, pinHash) {
		log.Warn("Invalid PIN for withdrawal")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid transaction PIN"})
		return
	}

	// Step-up authentication for high-value withdrawals
	if req.Amount >= h.cfg.Security.StepUpThreshold {
		if req.OTPCode == "" {
			c.JSON(http.StatusForbidden, gin.H{
				"error":   apperr.ErrStepUpRequired.Message,
				"detail":  fmt.Sprintf("Withdrawals over TZS %.0f require OTP verification", h.cfg.Security.StepUpThreshold),
				"require": "otp",
			})
			return
		}
		// OTP would be verified here via OTPService
	}

	// Check KYC status (withdrawals require at least tier 1)
	var kycTier int
	err = h.db.QueryRowContext(c, `SELECT kyc_tier FROM users WHERE id = $1`, userID).Scan(&kycTier)
	if err != nil {
		log.WithError(err).Error("Failed to get KYC tier")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	if kycTier < 1 {
		c.JSON(http.StatusForbidden, gin.H{"error": apperr.ErrKYCRequired.Message, "detail": "KYC verification required for withdrawals"})
		return
	}

	// Check balance
	var walletID string
	var available float64
	err = h.db.QueryRowContext(c,
		`SELECT id, available_balance FROM wallets WHERE user_id = $1 AND currency = 'TZS'`,
		userID,
	).Scan(&walletID, &available)
	if err != nil {
		log.WithError(err).Error("Failed to get wallet")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if available < req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrInsufficientBalance.Message})
		return
	}

	// Check withdrawal limits
	if err := h.checkWithdrawalLimits(c, userID, req.Amount); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Create pending transaction
	txnID := uuid.New()
	ref := fmt.Sprintf("WDR-%s-%d", txnID.String()[:8], time.Now().UnixMilli())

	metadata, err := json.Marshal(map[string]string{"payment_method": req.PaymentMethod, "phone_number": req.PhoneNumber})
	if err != nil {
		log.WithError(err).Error("Failed to marshal withdrawal metadata")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	_, err = h.db.ExecContext(c,
		`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, reference, idempotency_key, metadata)
		 VALUES ($1, $2, $3, 'withdrawal', 'pending', $4, $5, $6, $7)`,
		txnID, userID, walletID, req.Amount, ref, req.IdempotencyKey, metadata,
	)
	if err != nil {
		log.WithError(err).Error("Failed to create withdrawal transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Enqueue async payment job
	if err := h.queue.EnqueueWithdrawal(queue.PaymentPayload{
		TransactionID: txnID.String(),
		PhoneNumber:   req.PhoneNumber,
		Amount:        req.Amount,
		Currency:      "TZS",
		Reference:     ref,
		PaymentMethod: req.PaymentMethod,
	}); err != nil {
		log.WithError(err).Error("Failed to enqueue withdrawal job")
	}

	resp := gin.H{
		"transaction_id": txnID.String(),
		"reference":      ref,
		"status":         "pending",
		"message":        "Withdrawal initiated. You will receive the money shortly.",
	}

	if err := h.redis.Set(c, idemKey, fmt.Sprintf(`{"transaction_id":"%s","reference":"%s","status":"pending"}`, txnID, ref), 24*time.Hour).Err(); err != nil {
		log.WithError(err).Warn("Redis error caching idempotency response")
	}

	c.JSON(http.StatusAccepted, resp)
}

func (h *Handler) checkDepositLimits(c *gin.Context, userID string, amount float64) error {
	var kycTier int
	err := h.db.QueryRowContext(c, `SELECT kyc_tier FROM users WHERE id = $1`, userID).Scan(&kycTier)
	if err != nil {
		return fmt.Errorf("failed to get KYC tier: %w", err)
	}

	var dailyLimit float64
	err = h.db.QueryRowContext(c, `SELECT daily_deposit_limit FROM tier_limits WHERE kyc_tier = $1`, kycTier).Scan(&dailyLimit)
	if err != nil {
		return fmt.Errorf("failed to get deposit limit for tier %d: %w", kycTier, err)
	}

	// Get today's total deposits
	var todayTotal float64
	err = h.db.QueryRowContext(c,
		`SELECT COALESCE(SUM(amount), 0) FROM transactions
		 WHERE user_id = $1 AND type = 'deposit' AND status IN ('pending', 'completed')
		 AND created_at >= CURRENT_DATE`,
		userID,
	).Scan(&todayTotal)
	if err != nil {
		return fmt.Errorf("failed to get today's deposit total: %w", err)
	}

	if todayTotal+amount > dailyLimit {
		return fmt.Errorf("deposit would exceed daily limit of TZS %.2f (today's total: TZS %.2f)", dailyLimit, todayTotal)
	}

	return nil
}

func (h *Handler) checkWithdrawalLimits(c *gin.Context, userID string, amount float64) error {
	var kycTier int
	err := h.db.QueryRowContext(c, `SELECT kyc_tier FROM users WHERE id = $1`, userID).Scan(&kycTier)
	if err != nil {
		return fmt.Errorf("failed to get KYC tier: %w", err)
	}

	var dailyLimit float64
	err = h.db.QueryRowContext(c, `SELECT daily_withdrawal_limit FROM tier_limits WHERE kyc_tier = $1`, kycTier).Scan(&dailyLimit)
	if err != nil {
		return fmt.Errorf("failed to get withdrawal limit for tier %d: %w", kycTier, err)
	}

	var todayTotal float64
	err = h.db.QueryRowContext(c,
		`SELECT COALESCE(SUM(amount), 0) FROM transactions
		 WHERE user_id = $1 AND type = 'withdrawal' AND status IN ('pending', 'completed')
		 AND created_at >= CURRENT_DATE`,
		userID,
	).Scan(&todayTotal)
	if err != nil {
		return fmt.Errorf("failed to get today's withdrawal total: %w", err)
	}

	if todayTotal+amount > dailyLimit {
		return fmt.Errorf("withdrawal would exceed daily limit of TZS %.2f (today's total: TZS %.2f)", dailyLimit, todayTotal)
	}

	return nil
}
