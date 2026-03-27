package admin

import (
	"database/sql"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/pquerna/otp/totp"

	"github.com/savingplus/backend/internal/auth"
	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/pkg/config"
	"github.com/savingplus/backend/pkg/crypto"
	"github.com/savingplus/backend/pkg/logger"
	"github.com/savingplus/backend/pkg/response"
)

type Handler struct {
	db  *sql.DB
	jwt *auth.JWTService
	cfg *config.Config
}

func NewHandler(db *sql.DB, jwtSvc *auth.JWTService, cfg *config.Config) *Handler {
	return &Handler{db: db, jwt: jwtSvc, cfg: cfg}
}

type AdminLoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
	MFACode  string `json:"mfa_code" binding:"required,len=6"`
}

type AdminCreateRequest struct {
	Email    string `json:"email" binding:"required,email"`
	FullName string `json:"full_name" binding:"required"`
	Password string `json:"password" binding:"required,min=12"`
	Role     string `json:"role" binding:"required,oneof=support finance super_admin"`
}

// Login handles admin authentication with MFA
func (h *Handler) Login(c *gin.Context) {
	log := logger.Ctx(c)

	var req AdminLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	var adminID, passwordHash, role, status string
	var mfaSecret sql.NullString
	var mfaEnabled bool
	err := h.db.QueryRowContext(c,
		`SELECT id, password_hash, role, status, mfa_secret, mfa_enabled FROM admin_users WHERE email = $1`,
		req.Email,
	).Scan(&adminID, &passwordHash, &role, &status, &mfaSecret, &mfaEnabled)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to query admin user")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if status != "active" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Account is " + status})
		return
	}

	if !crypto.VerifyPassword(req.Password, passwordHash) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Verify MFA
	if mfaEnabled && mfaSecret.Valid {
		valid := totp.Validate(req.MFACode, mfaSecret.String)
		if !valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid MFA code"})
			return
		}
	}

	// Update last login (non-critical)
	if _, err := h.db.ExecContext(c, `UPDATE admin_users SET last_login_at = NOW() WHERE id = $1`, adminID); err != nil {
		log.WithError(err).Warn("Failed to update admin last_login_at")
	}

	tokenPair, _, err := h.jwt.GenerateTokenPair(adminID, req.Email, role)
	if err != nil {
		log.WithError(err).Error("Failed to generate admin tokens")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token": tokenPair.AccessToken,
		"expires_in":   tokenPair.ExpiresIn,
		"role":         role,
	})
}

// CreateAdmin creates a new admin user (super_admin only)
func (h *Handler) CreateAdmin(c *gin.Context) {
	log := logger.Ctx(c)

	var req AdminCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	passwordHash, err := crypto.HashPassword(req.Password)
	if err != nil {
		log.WithError(err).Error("Failed to hash admin password")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Generate TOTP secret
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      h.cfg.Security.TOTPIssuer,
		AccountName: req.Email,
	})
	if err != nil {
		log.WithError(err).Error("Failed to generate TOTP secret")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	adminID := uuid.New()
	_, err = h.db.ExecContext(c,
		`INSERT INTO admin_users (id, email, full_name, password_hash, role, mfa_secret, mfa_enabled)
		 VALUES ($1, $2, $3, $4, $5, $6, TRUE)`,
		adminID, req.Email, req.FullName, passwordHash, req.Role, key.Secret(),
	)
	if err != nil {
		log.WithError(err).Error("Failed to create admin user")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"admin_id":   adminID.String(),
		"mfa_secret": key.Secret(),
		"mfa_url":    key.URL(),
		"message":    "Admin user created. Please set up Google Authenticator with the provided secret.",
	})
}

// SearchUsers allows support to search users
func (h *Handler) SearchUsers(c *gin.Context) {
	log := logger.Ctx(c)

	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Search query required"})
		return
	}

	p := response.GetPagination(c, 20)

	rows, err := h.db.QueryContext(c,
		`SELECT id, phone, email, full_name, kyc_status, kyc_tier, status, created_at
		 FROM users WHERE phone ILIKE $1 OR full_name ILIKE $1 OR email ILIKE $1
		 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
		"%"+query+"%", p.PageSize, p.Offset,
	)
	if err != nil {
		log.WithError(err).Error("Failed to search users")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type UserResult struct {
		ID        string  `json:"id"`
		Phone     string  `json:"phone"`
		Email     *string `json:"email"`
		FullName  string  `json:"full_name"`
		KYCStatus string  `json:"kyc_status"`
		KYCTier   int     `json:"kyc_tier"`
		Status    string  `json:"status"`
		CreatedAt string  `json:"created_at"`
	}

	var users []UserResult
	for rows.Next() {
		var u UserResult
		var email sql.NullString
		if err := rows.Scan(&u.ID, &u.Phone, &email, &u.FullName, &u.KYCStatus, &u.KYCTier, &u.Status, &u.CreatedAt); err != nil {
			log.WithError(err).Warn("Failed to scan user row")
			continue
		}
		u.Email = response.NullStr(email)
		users = append(users, u)
	}

	users = response.EmptySlice(users)
	c.JSON(http.StatusOK, gin.H{"users": users, "page": p.Page})
}

// GetUserDetail shows full user info for support
func (h *Handler) GetUserDetail(c *gin.Context) {
	log := logger.Ctx(c)
	uid := c.Param("id")

	var user struct {
		ID        string  `json:"id"`
		Phone     string  `json:"phone"`
		Email     *string `json:"email"`
		FullName  string  `json:"full_name"`
		KYCStatus string  `json:"kyc_status"`
		KYCTier   int     `json:"kyc_tier"`
		Status    string  `json:"status"`
		CreatedAt string  `json:"created_at"`
	}
	var email sql.NullString

	err := h.db.QueryRowContext(c,
		`SELECT id, phone, email, full_name, kyc_status, kyc_tier, status, created_at FROM users WHERE id = $1`,
		uid,
	).Scan(&user.ID, &user.Phone, &email, &user.FullName, &user.KYCStatus, &user.KYCTier, &user.Status, &user.CreatedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get user")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	user.Email = response.NullStr(email)

	// Get wallet balance
	var balance, locked float64
	if err := h.db.QueryRowContext(c, `SELECT available_balance, locked_balance FROM wallets WHERE user_id = $1 AND currency = 'TZS'`, uid).Scan(&balance, &locked); err != nil {
		log.WithError(err).Warn("Failed to get wallet balance for user")
	}

	c.JSON(http.StatusOK, gin.H{
		"user":              user,
		"available_balance": balance,
		"locked_balance":    locked,
	})
}

// ApproveKYC approves a user's KYC
func (h *Handler) ApproveKYC(c *gin.Context) {
	log := logger.Ctx(c)
	uid := c.Param("id")
	adminID := c.GetString("admin_id")

	var req struct {
		DocumentID string `json:"document_id" binding:"required"`
		NewTier    int    `json:"new_tier" binding:"required,min=1,max=3"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin KYC approval transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	_, err = tx.ExecContext(c,
		`UPDATE kyc_documents SET status = 'approved', reviewed_by = $1, reviewed_at = NOW() WHERE id = $2 AND user_id = $3`,
		adminID, req.DocumentID, uid,
	)
	if err != nil {
		log.WithError(err).Error("Failed to approve KYC document")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	_, err = tx.ExecContext(c,
		`UPDATE users SET kyc_status = 'approved', kyc_tier = $1 WHERE id = $2`,
		req.NewTier, uid,
	)
	if err != nil {
		log.WithError(err).Error("Failed to update user KYC tier")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit KYC approval")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "KYC approved", "new_tier": req.NewTier})
}

// RejectKYC rejects a user's KYC document
func (h *Handler) RejectKYC(c *gin.Context) {
	log := logger.Ctx(c)
	uid := c.Param("id")
	adminID := c.GetString("admin_id")

	var req struct {
		DocumentID string `json:"document_id" binding:"required"`
		Reason     string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	if _, err := h.db.ExecContext(c,
		`UPDATE kyc_documents SET status = 'rejected', rejection_reason = $1, reviewed_by = $2, reviewed_at = NOW()
		 WHERE id = $3 AND user_id = $4`,
		req.Reason, adminID, req.DocumentID, uid,
	); err != nil {
		log.WithError(err).Error("Failed to reject KYC document")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Non-critical: update user status
	if _, err := h.db.ExecContext(c, `UPDATE users SET kyc_status = 'rejected' WHERE id = $1`, uid); err != nil {
		log.WithError(err).Warn("Failed to update user KYC status to rejected")
	}

	c.JSON(http.StatusOK, gin.H{"message": "KYC document rejected"})
}

// ListTransactions for finance panel
func (h *Handler) ListTransactions(c *gin.Context) {
	log := logger.Ctx(c)

	p := response.GetPagination(c, 50)
	status := c.Query("status")
	txnType := c.Query("type")

	query := `SELECT t.id, t.user_id, u.phone, t.type, t.status, t.amount, t.fee, t.reference, t.created_at
			  FROM transactions t JOIN users u ON t.user_id = u.id WHERE 1=1`
	countQuery := `SELECT COUNT(*) FROM transactions t WHERE 1=1`
	args := []interface{}{}
	countArgs := []interface{}{}
	idx := 1

	if status != "" {
		query += ` AND t.status = $` + strconv.Itoa(idx)
		countQuery += ` AND t.status = $` + strconv.Itoa(idx)
		args = append(args, status)
		countArgs = append(countArgs, status)
		idx++
	}
	if txnType != "" {
		query += ` AND t.type = $` + strconv.Itoa(idx)
		countQuery += ` AND t.type = $` + strconv.Itoa(idx)
		args = append(args, txnType)
		countArgs = append(countArgs, txnType)
		idx++
	}

	var total int
	if err := h.db.QueryRowContext(c, countQuery, countArgs...).Scan(&total); err != nil {
		log.WithError(err).Warn("Failed to count transactions")
	}

	query += ` ORDER BY t.created_at DESC LIMIT $` + strconv.Itoa(idx) + ` OFFSET $` + strconv.Itoa(idx+1)
	args = append(args, p.PageSize, p.Offset)

	rows, err := h.db.QueryContext(c, query, args...)
	if err != nil {
		log.WithError(err).Error("Admin: failed to list transactions")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type TxnRow struct {
		ID        string  `json:"id"`
		UserID    string  `json:"user_id"`
		Phone     string  `json:"phone"`
		Type      string  `json:"type"`
		Status    string  `json:"status"`
		Amount    float64 `json:"amount"`
		Fee       float64 `json:"fee"`
		Reference string  `json:"reference"`
		CreatedAt string  `json:"created_at"`
	}

	var txns []TxnRow
	for rows.Next() {
		var t TxnRow
		if err := rows.Scan(&t.ID, &t.UserID, &t.Phone, &t.Type, &t.Status, &t.Amount, &t.Fee, &t.Reference, &t.CreatedAt); err != nil {
			log.WithError(err).Warn("Failed to scan transaction row")
			continue
		}
		txns = append(txns, t)
	}
	txns = response.EmptySlice(txns)

	response.PagedList(c, "transactions", txns, p, total)
}

// GetAuditLogs for super admin
func (h *Handler) GetAuditLogs(c *gin.Context) {
	log := logger.Ctx(c)

	p := response.GetPagination(c, 50)

	var total int
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM audit_logs`).Scan(&total); err != nil {
		log.WithError(err).Warn("Failed to count audit logs")
	}

	rows, err := h.db.QueryContext(c,
		`SELECT id, actor_type, actor_id, action, ip_address, response_status, created_at
		 FROM audit_logs ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
		p.PageSize, p.Offset,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query audit logs")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type AuditEntry struct {
		ID             string  `json:"id"`
		ActorType      string  `json:"actor_type"`
		ActorID        *string `json:"actor_id"`
		Action         string  `json:"action"`
		IPAddress      *string `json:"ip_address"`
		ResponseStatus *int    `json:"response_status"`
		CreatedAt      string  `json:"created_at"`
	}

	var entries []AuditEntry
	for rows.Next() {
		var e AuditEntry
		var actorID, ip sql.NullString
		var respStatus sql.NullInt32
		if err := rows.Scan(&e.ID, &e.ActorType, &actorID, &e.Action, &ip, &respStatus, &e.CreatedAt); err != nil {
			log.WithError(err).Warn("Failed to scan audit log row")
			continue
		}
		e.ActorID = response.NullStr(actorID)
		e.IPAddress = response.NullStr(ip)
		e.ResponseStatus = response.NullInt(respStatus)
		entries = append(entries, e)
	}
	entries = response.EmptySlice(entries)

	response.PagedList(c, "audit_logs", entries, p, total)
}

// GetFeatureFlags lists all feature flags
func (h *Handler) GetFeatureFlags(c *gin.Context) {
	log := logger.Ctx(c)

	rows, err := h.db.QueryContext(c,
		`SELECT id, name, description, enabled, created_at, updated_at FROM feature_flags ORDER BY name`,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query feature flags")
		response.InternalError(c)
		return
	}
	defer rows.Close()

	type Flag struct {
		ID          string  `json:"id"`
		Name        string  `json:"name"`
		Description *string `json:"description"`
		Enabled     bool    `json:"enabled"`
		CreatedAt   string  `json:"created_at"`
		UpdatedAt   string  `json:"updated_at"`
	}

	var flags []Flag
	for rows.Next() {
		var f Flag
		var desc sql.NullString
		if err := rows.Scan(&f.ID, &f.Name, &desc, &f.Enabled, &f.CreatedAt, &f.UpdatedAt); err != nil {
			log.WithError(err).Warn("Failed to scan feature flag row")
			continue
		}
		f.Description = response.NullStr(desc)
		flags = append(flags, f)
	}
	flags = response.EmptySlice(flags)

	c.JSON(http.StatusOK, gin.H{"feature_flags": flags})
}

// ToggleFeatureFlag enables/disables a feature flag
func (h *Handler) ToggleFeatureFlag(c *gin.Context) {
	log := logger.Ctx(c)
	flagID := c.Param("id")

	var req struct {
		Enabled bool `json:"enabled"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message})
		return
	}

	result, err := h.db.ExecContext(c,
		`UPDATE feature_flags SET enabled = $1 WHERE id = $2`,
		req.Enabled, flagID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to toggle feature flag")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	affected, err := result.RowsAffected()
	if err != nil {
		log.WithError(err).Error("Failed to get rows affected for feature flag toggle")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	if affected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Feature flag not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Feature flag updated", "enabled": req.Enabled})
}

// SystemHealth returns basic system health info
func (h *Handler) SystemHealth(c *gin.Context) {
	log := logger.Ctx(c)

	var userCount, txnCount int
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM users`).Scan(&userCount); err != nil {
		log.WithError(err).Warn("Failed to count users")
	}
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM transactions`).Scan(&txnCount); err != nil {
		log.WithError(err).Warn("Failed to count transactions")
	}

	var pendingTxns int
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM transactions WHERE status = 'pending'`).Scan(&pendingTxns); err != nil {
		log.WithError(err).Warn("Failed to count pending transactions")
	}

	var pendingKYC int
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM kyc_documents WHERE status = 'pending'`).Scan(&pendingKYC); err != nil {
		log.WithError(err).Warn("Failed to count pending KYC")
	}

	var failedTxns24h int
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM transactions WHERE status = 'failed' AND created_at > NOW() - INTERVAL '24 hours'`).Scan(&failedTxns24h); err != nil {
		log.WithError(err).Warn("Failed to count failed transactions")
	}

	var lockedAccounts int
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM users WHERE status = 'locked'`).Scan(&lockedAccounts); err != nil {
		log.WithError(err).Warn("Failed to count locked accounts")
	}

	var totalDeposits, totalWithdrawals float64
	if err := h.db.QueryRowContext(c, `SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type = 'deposit' AND status = 'completed'`).Scan(&totalDeposits); err != nil {
		log.WithError(err).Warn("Failed to sum deposits")
	}
	if err := h.db.QueryRowContext(c, `SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type = 'withdrawal' AND status = 'completed'`).Scan(&totalWithdrawals); err != nil {
		log.WithError(err).Warn("Failed to sum withdrawals")
	}

	c.JSON(http.StatusOK, gin.H{
		"status":               "healthy",
		"timestamp":            time.Now().UTC(),
		"total_users":          userCount,
		"total_transactions":   txnCount,
		"pending_transactions": pendingTxns,
		"pending_kyc":          pendingKYC,
		"failed_txns_24h":      failedTxns24h,
		"locked_accounts":      lockedAccounts,
		"total_deposits":       totalDeposits,
		"total_withdrawals":    totalWithdrawals,
	})
}

// ============================================================
// SUPPORT PANEL - Unlock Account, Reset PIN, User Transactions, KYC Queue
// ============================================================

// UnlockAccount unlocks a locked user account
func (h *Handler) UnlockAccount(c *gin.Context) {
	log := logger.Ctx(c)
	uid := c.Param("id")

	var currentStatus string
	err := h.db.QueryRowContext(c, `SELECT status FROM users WHERE id = $1`, uid).Scan(&currentStatus)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to query user status for unlock")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if currentStatus != "locked" && currentStatus != "suspended" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Account is not locked or suspended", "current_status": currentStatus})
		return
	}

	_, err = h.db.ExecContext(c,
		`UPDATE users SET status = 'active', failed_login_attempts = 0, locked_until = NULL WHERE id = $1`,
		uid,
	)
	if err != nil {
		log.WithError(err).Error("Failed to unlock account")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Account unlocked successfully", "previous_status": currentStatus})
}

// SuspendAccount suspends a user account
func (h *Handler) SuspendAccount(c *gin.Context) {
	log := logger.Ctx(c)
	uid := c.Param("id")

	var req struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	result, err := h.db.ExecContext(c, `UPDATE users SET status = 'suspended' WHERE id = $1 AND status = 'active'`, uid)
	if err != nil {
		log.WithError(err).Error("Failed to suspend account")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	affected, err := result.RowsAffected()
	if err != nil {
		log.WithError(err).Error("Failed to get rows affected for suspend")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	if affected == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User not found or not active"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Account suspended", "reason": req.Reason})
}

// ResetUserPIN resets a user's transaction PIN (support sends OTP, user verifies)
func (h *Handler) ResetUserPIN(c *gin.Context) {
	log := logger.Ctx(c)
	uid := c.Param("id")

	var req struct {
		NewPIN string `json:"new_pin" binding:"required,len=4"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	// Verify user exists
	var phone string
	err := h.db.QueryRowContext(c, `SELECT phone FROM users WHERE id = $1`, uid).Scan(&phone)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to query user for PIN reset")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Hash the new PIN
	pinHash, err := crypto.HashPassword(req.NewPIN)
	if err != nil {
		log.WithError(err).Error("Failed to hash new PIN")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	_, err = h.db.ExecContext(c, `UPDATE users SET pin_hash = $1 WHERE id = $2`, pinHash, uid)
	if err != nil {
		log.WithError(err).Error("Failed to reset PIN")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "PIN reset successfully for user " + phone})
}

// GetUserTransactions lists transactions for a specific user (support view)
func (h *Handler) GetUserTransactions(c *gin.Context) {
	log := logger.Ctx(c)
	uid := c.Param("id")

	p := response.GetPagination(c, 20)

	var total int
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM transactions WHERE user_id = $1`, uid).Scan(&total); err != nil {
		log.WithError(err).Warn("Failed to count user transactions")
	}

	rows, err := h.db.QueryContext(c,
		`SELECT id, type, status, amount, fee, currency, reference, created_at, completed_at
		 FROM transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
		uid, p.PageSize, p.Offset,
	)
	if err != nil {
		log.WithError(err).Error("Failed to get user transactions")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type TxnRow struct {
		ID          string  `json:"id"`
		Type        string  `json:"type"`
		Status      string  `json:"status"`
		Amount      float64 `json:"amount"`
		Fee         float64 `json:"fee"`
		Currency    string  `json:"currency"`
		Reference   string  `json:"reference"`
		CreatedAt   string  `json:"created_at"`
		CompletedAt *string `json:"completed_at"`
	}

	var txns []TxnRow
	for rows.Next() {
		var t TxnRow
		var completedAt sql.NullString
		if err := rows.Scan(&t.ID, &t.Type, &t.Status, &t.Amount, &t.Fee, &t.Currency, &t.Reference, &t.CreatedAt, &completedAt); err != nil {
			log.WithError(err).Warn("Failed to scan user transaction row")
			continue
		}
		t.CompletedAt = response.NullStr(completedAt)
		txns = append(txns, t)
	}
	txns = response.EmptySlice(txns)

	response.PagedList(c, "transactions", txns, p, total)
}

// GetPendingKYC returns all KYC documents awaiting review
func (h *Handler) GetPendingKYC(c *gin.Context) {
	log := logger.Ctx(c)

	p := response.GetPagination(c, 20)

	var total int
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM kyc_documents WHERE status = 'pending'`).Scan(&total); err != nil {
		log.WithError(err).Warn("Failed to count pending KYC documents")
	}

	rows, err := h.db.QueryContext(c,
		`SELECT kd.id, kd.user_id, u.phone, u.full_name, kd.document_type, kd.status, kd.created_at
		 FROM kyc_documents kd JOIN users u ON kd.user_id = u.id
		 WHERE kd.status = 'pending' ORDER BY kd.created_at ASC LIMIT $1 OFFSET $2`,
		p.PageSize, p.Offset,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query pending KYC")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type KYCRow struct {
		ID           string `json:"id"`
		UserID       string `json:"user_id"`
		Phone        string `json:"phone"`
		FullName     string `json:"full_name"`
		DocumentType string `json:"document_type"`
		Status       string `json:"status"`
		CreatedAt    string `json:"created_at"`
	}

	var docs []KYCRow
	for rows.Next() {
		var d KYCRow
		if err := rows.Scan(&d.ID, &d.UserID, &d.Phone, &d.FullName, &d.DocumentType, &d.Status, &d.CreatedAt); err != nil {
			log.WithError(err).Warn("Failed to scan pending KYC row")
			continue
		}
		docs = append(docs, d)
	}
	docs = response.EmptySlice(docs)

	response.PagedList(c, "documents", docs, p, total)
}

// GetUserKYCDocuments returns KYC documents for a specific user
func (h *Handler) GetUserKYCDocuments(c *gin.Context) {
	log := logger.Ctx(c)
	uid := c.Param("id")

	rows, err := h.db.QueryContext(c,
		`SELECT kd.id, kd.user_id, u.phone, u.full_name, kd.document_type, kd.status, kd.created_at
		 FROM kyc_documents kd JOIN users u ON kd.user_id = u.id
		 WHERE kd.user_id = $1 ORDER BY kd.created_at DESC`,
		uid,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query user KYC documents")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type KYCRow struct {
		ID           string `json:"id"`
		UserID       string `json:"user_id"`
		Phone        string `json:"phone"`
		FullName     string `json:"full_name"`
		DocumentType string `json:"document_type"`
		Status       string `json:"status"`
		CreatedAt    string `json:"created_at"`
	}

	var docs []KYCRow
	for rows.Next() {
		var d KYCRow
		if err := rows.Scan(&d.ID, &d.UserID, &d.Phone, &d.FullName, &d.DocumentType, &d.Status, &d.CreatedAt); err != nil {
			log.WithError(err).Warn("Failed to scan user KYC document row")
			continue
		}
		docs = append(docs, d)
	}
	docs = response.EmptySlice(docs)

	c.JSON(http.StatusOK, gin.H{"documents": docs})
}

// ============================================================
// FINANCE PANEL - Settlement, Reconciliation
// ============================================================

// MarkTransactionReconciled marks a transaction as reconciled
func (h *Handler) MarkTransactionReconciled(c *gin.Context) {
	log := logger.Ctx(c)
	txnID := c.Param("id")

	var req struct {
		SettlementRef string `json:"settlement_ref" binding:"required"`
		Notes         string `json:"notes"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	result, err := h.db.ExecContext(c,
		`UPDATE transactions SET metadata = metadata || jsonb_build_object('reconciled', true, 'settlement_ref', $1, 'reconciled_at', NOW()::text, 'reconciled_by', $2, 'notes', $3)
		 WHERE id = $4 AND status = 'completed'`,
		req.SettlementRef, c.GetString("admin_id"), req.Notes, txnID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to mark reconciled")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	affected, err := result.RowsAffected()
	if err != nil {
		log.WithError(err).Error("Failed to get rows affected for reconciliation")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	if affected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Transaction not found or not completed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Transaction marked as reconciled"})
}

// GetUnreconciledTransactions returns completed transactions not yet reconciled
func (h *Handler) GetUnreconciledTransactions(c *gin.Context) {
	log := logger.Ctx(c)

	p := response.GetPagination(c, 50)

	var total int
	if err := h.db.QueryRowContext(c,
		`SELECT COUNT(*) FROM transactions WHERE status = 'completed' AND (metadata->>'reconciled' IS NULL OR metadata->>'reconciled' = 'false')`,
	).Scan(&total); err != nil {
		log.WithError(err).Warn("Failed to count unreconciled transactions")
	}

	rows, err := h.db.QueryContext(c,
		`SELECT t.id, t.user_id, u.phone, t.type, t.amount, t.fee, t.reference, t.gateway_ref, t.created_at, t.completed_at
		 FROM transactions t JOIN users u ON t.user_id = u.id
		 WHERE t.status = 'completed' AND (t.metadata->>'reconciled' IS NULL OR t.metadata->>'reconciled' = 'false')
		 ORDER BY t.completed_at DESC LIMIT $1 OFFSET $2`,
		p.PageSize, p.Offset,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query unreconciled")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type Row struct {
		ID          string  `json:"id"`
		UserID      string  `json:"user_id"`
		Phone       string  `json:"phone"`
		Type        string  `json:"type"`
		Amount      float64 `json:"amount"`
		Fee         float64 `json:"fee"`
		Reference   string  `json:"reference"`
		GatewayRef  *string `json:"gateway_ref"`
		CreatedAt   string  `json:"created_at"`
		CompletedAt *string `json:"completed_at"`
	}

	var txns []Row
	for rows.Next() {
		var t Row
		var gwRef, compAt sql.NullString
		if err := rows.Scan(&t.ID, &t.UserID, &t.Phone, &t.Type, &t.Amount, &t.Fee, &t.Reference, &gwRef, &t.CreatedAt, &compAt); err != nil {
			log.WithError(err).Warn("Failed to scan unreconciled transaction row")
			continue
		}
		t.GatewayRef = response.NullStr(gwRef)
		t.CompletedAt = response.NullStr(compAt)
		txns = append(txns, t)
	}
	txns = response.EmptySlice(txns)

	response.PagedList(c, "transactions", txns, p, total)
}

// GetReconciliationSummary returns summary of reconciliation status
func (h *Handler) GetReconciliationSummary(c *gin.Context) {
	log := logger.Ctx(c)

	var totalCompleted, totalReconciled int
	var sumCompleted, sumReconciled float64

	if err := h.db.QueryRowContext(c, `SELECT COUNT(*), COALESCE(SUM(amount), 0) FROM transactions WHERE status = 'completed'`).Scan(&totalCompleted, &sumCompleted); err != nil {
		log.WithError(err).Warn("Failed to query completed transaction summary")
	}
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*), COALESCE(SUM(amount), 0) FROM transactions WHERE status = 'completed' AND metadata->>'reconciled' = 'true'`).Scan(&totalReconciled, &sumReconciled); err != nil {
		log.WithError(err).Warn("Failed to query reconciled transaction summary")
	}

	c.JSON(http.StatusOK, gin.H{
		"total_completed":     totalCompleted,
		"total_reconciled":    totalReconciled,
		"total_unreconciled":  totalCompleted - totalReconciled,
		"amount_completed":    sumCompleted,
		"amount_reconciled":   sumReconciled,
		"amount_unreconciled": sumCompleted - sumReconciled,
	})
}

// ============================================================
// SUPER ADMIN - Admin User Management, Limits, Security Alerts
// ============================================================

// ListAdmins lists all admin users
func (h *Handler) ListAdmins(c *gin.Context) {
	log := logger.Ctx(c)

	rows, err := h.db.QueryContext(c,
		`SELECT id, email, full_name, role, status, mfa_enabled, last_login_at, created_at
		 FROM admin_users ORDER BY created_at DESC`,
	)
	if err != nil {
		log.WithError(err).Error("Failed to list admins")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type AdminRow struct {
		ID          string  `json:"id"`
		Email       string  `json:"email"`
		FullName    string  `json:"full_name"`
		Role        string  `json:"role"`
		Status      string  `json:"status"`
		MFAEnabled  bool    `json:"mfa_enabled"`
		LastLoginAt *string `json:"last_login_at"`
		CreatedAt   string  `json:"created_at"`
	}

	var admins []AdminRow
	for rows.Next() {
		var a AdminRow
		var lastLogin sql.NullString
		if err := rows.Scan(&a.ID, &a.Email, &a.FullName, &a.Role, &a.Status, &a.MFAEnabled, &lastLogin, &a.CreatedAt); err != nil {
			log.WithError(err).Warn("Failed to scan admin row")
			continue
		}
		a.LastLoginAt = response.NullStr(lastLogin)
		admins = append(admins, a)
	}
	admins = response.EmptySlice(admins)

	c.JSON(http.StatusOK, gin.H{"admins": admins, "total": len(admins)})
}

// DeactivateAdmin deactivates an admin user
func (h *Handler) DeactivateAdmin(c *gin.Context) {
	log := logger.Ctx(c)
	adminID := c.Param("id")
	currentAdminID := c.GetString("admin_id")

	if adminID == currentAdminID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot deactivate your own account"})
		return
	}

	result, err := h.db.ExecContext(c,
		`UPDATE admin_users SET status = 'deactivated' WHERE id = $1 AND status = 'active'`,
		adminID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to deactivate admin")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	affected, err := result.RowsAffected()
	if err != nil {
		log.WithError(err).Error("Failed to get rows affected for admin deactivation")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	if affected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Admin not found or already deactivated"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Admin user deactivated"})
}

// ReactivateAdmin reactivates a deactivated admin
func (h *Handler) ReactivateAdmin(c *gin.Context) {
	log := logger.Ctx(c)
	adminID := c.Param("id")

	result, err := h.db.ExecContext(c,
		`UPDATE admin_users SET status = 'active' WHERE id = $1 AND status = 'deactivated'`,
		adminID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to reactivate admin")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	affected, err := result.RowsAffected()
	if err != nil {
		log.WithError(err).Error("Failed to get rows affected for admin reactivation")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	if affected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Admin not found or not deactivated"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Admin user reactivated"})
}

// GetTierLimits returns all tier limits
func (h *Handler) GetTierLimits(c *gin.Context) {
	log := logger.Ctx(c)

	rows, err := h.db.QueryContext(c,
		`SELECT kyc_tier, daily_deposit_limit, daily_withdrawal_limit, max_balance, COALESCE(description, '')
		 FROM tier_limits ORDER BY kyc_tier`,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query tier limits")
		response.InternalError(c)
		return
	}
	defer rows.Close()

	type Limit struct {
		Tier            int     `json:"kyc_tier"`
		DailyDeposit    float64 `json:"daily_deposit_limit"`
		DailyWithdrawal float64 `json:"daily_withdrawal_limit"`
		MaxBalance      float64 `json:"max_balance"`
		Description     string  `json:"description"`
	}

	var limits []Limit
	for rows.Next() {
		var l Limit
		if err := rows.Scan(&l.Tier, &l.DailyDeposit, &l.DailyWithdrawal, &l.MaxBalance, &l.Description); err != nil {
			log.WithError(err).Warn("Failed to scan tier limit row")
			continue
		}
		limits = append(limits, l)
	}

	c.JSON(http.StatusOK, gin.H{"tier_limits": limits})
}

// UpdateTierLimits updates limits for a specific tier
func (h *Handler) UpdateTierLimits(c *gin.Context) {
	log := logger.Ctx(c)

	tier, err := strconv.Atoi(c.Param("tier"))
	if err != nil || tier < 0 || tier > 3 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid tier (0-3)"})
		return
	}

	var req struct {
		DailyDeposit    *float64 `json:"daily_deposit_limit"`
		DailyWithdrawal *float64 `json:"daily_withdrawal_limit"`
		MaxBalance      *float64 `json:"max_balance"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	if req.DailyDeposit != nil {
		if _, err := h.db.ExecContext(c, `UPDATE tier_limits SET daily_deposit_limit = $1 WHERE kyc_tier = $2`, *req.DailyDeposit, tier); err != nil {
			log.WithError(err).Error("Failed to update daily deposit limit")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}
	}
	if req.DailyWithdrawal != nil {
		if _, err := h.db.ExecContext(c, `UPDATE tier_limits SET daily_withdrawal_limit = $1 WHERE kyc_tier = $2`, *req.DailyWithdrawal, tier); err != nil {
			log.WithError(err).Error("Failed to update daily withdrawal limit")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}
	}
	if req.MaxBalance != nil {
		if _, err := h.db.ExecContext(c, `UPDATE tier_limits SET max_balance = $1 WHERE kyc_tier = $2`, *req.MaxBalance, tier); err != nil {
			log.WithError(err).Error("Failed to update max balance")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Tier limits updated", "tier": tier})
}

// GetSecurityAlerts returns recent security-relevant events
func (h *Handler) GetSecurityAlerts(c *gin.Context) {
	log := logger.Ctx(c)

	p := response.GetPagination(c, 50)

	// Security alerts: failed logins, locked accounts, high-value txns, suspicious activity
	alertsQuery := `(
			SELECT 'locked_account' AS alert_type, u.id AS entity_id, u.phone AS description,
				   'User account locked after failed attempts' AS detail, u.created_at AS created_at
			FROM users u WHERE u.status = 'locked'
		)
		UNION ALL
		(
			SELECT 'high_value_txn' AS alert_type, t.id AS entity_id, t.reference AS description,
				   'Transaction over TZS 1,000,000: ' || t.amount::text AS detail, t.created_at
			FROM transactions t WHERE t.amount > 1000000 AND t.created_at > NOW() - INTERVAL '24 hours'
		)
		UNION ALL
		(
			SELECT 'failed_transaction' AS alert_type, t.id AS entity_id, t.reference AS description,
				   'Failed transaction: ' || t.type AS detail, t.created_at AS created_at
			FROM transactions t WHERE t.status = 'failed' AND t.created_at > NOW() - INTERVAL '24 hours'
		)`

	var total int
	if err := h.db.QueryRowContext(c, fmt.Sprintf(`SELECT COUNT(*) FROM (%s) AS alerts`, alertsQuery)).Scan(&total); err != nil {
		log.WithError(err).Warn("Failed to count security alerts")
	}

	rows, err := h.db.QueryContext(c,
		alertsQuery+` ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
		p.PageSize, p.Offset,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query security alerts")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type Alert struct {
		AlertType   string `json:"alert_type"`
		EntityID    string `json:"entity_id"`
		Description string `json:"description"`
		Detail      string `json:"detail"`
		CreatedAt   string `json:"created_at"`
	}

	var alerts []Alert
	for rows.Next() {
		var a Alert
		if err := rows.Scan(&a.AlertType, &a.EntityID, &a.Description, &a.Detail, &a.CreatedAt); err != nil {
			log.WithError(err).Warn("Failed to scan security alert row")
			continue
		}
		alerts = append(alerts, a)
	}
	alerts = response.EmptySlice(alerts)

	response.PagedList(c, "alerts", alerts, p, total)
}
