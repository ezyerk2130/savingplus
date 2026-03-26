package admin

import (
	"database/sql"
	"math"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/pquerna/otp/totp"
	log "github.com/sirupsen/logrus"

	"github.com/savingplus/backend/internal/auth"
	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/pkg/config"
	"github.com/savingplus/backend/pkg/crypto"
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

	// Update last login
	h.db.ExecContext(c, `UPDATE admin_users SET last_login_at = NOW() WHERE id = $1`, adminID)

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
		"admin_id":    adminID.String(),
		"mfa_secret":  key.Secret(),
		"mfa_url":     key.URL(),
		"message":     "Admin user created. Please set up Google Authenticator with the provided secret.",
	})
}

// SearchUsers allows support to search users
func (h *Handler) SearchUsers(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Search query required"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize := 20
	offset := (page - 1) * pageSize

	rows, err := h.db.QueryContext(c,
		`SELECT id, phone, email, full_name, kyc_status, kyc_tier, status, created_at
		 FROM users WHERE phone ILIKE $1 OR full_name ILIKE $1 OR email ILIKE $1
		 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
		"%"+query+"%", pageSize, offset,
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
			continue
		}
		if email.Valid {
			u.Email = &email.String
		}
		users = append(users, u)
	}

	if users == nil {
		users = []UserResult{}
	}

	c.JSON(http.StatusOK, gin.H{"users": users, "page": page})
}

// GetUserDetail shows full user info for support
func (h *Handler) GetUserDetail(c *gin.Context) {
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
	if email.Valid {
		user.Email = &email.String
	}

	// Get wallet balance
	var balance, locked float64
	h.db.QueryRowContext(c, `SELECT available_balance, locked_balance FROM wallets WHERE user_id = $1`, uid).Scan(&balance, &locked)

	c.JSON(http.StatusOK, gin.H{
		"user":              user,
		"available_balance": balance,
		"locked_balance":    locked,
	})
}

// ApproveKYC approves a user's KYC
func (h *Handler) ApproveKYC(c *gin.Context) {
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	_, err = tx.ExecContext(c,
		`UPDATE kyc_documents SET status = 'approved', reviewed_by = $1, reviewed_at = NOW() WHERE id = $2 AND user_id = $3`,
		adminID, req.DocumentID, uid,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	_, err = tx.ExecContext(c,
		`UPDATE users SET kyc_status = 'approved', kyc_tier = $1 WHERE id = $2`,
		req.NewTier, uid,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	tx.Commit()
	c.JSON(http.StatusOK, gin.H{"message": "KYC approved", "new_tier": req.NewTier})
}

// RejectKYC rejects a user's KYC document
func (h *Handler) RejectKYC(c *gin.Context) {
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

	h.db.ExecContext(c,
		`UPDATE kyc_documents SET status = 'rejected', rejection_reason = $1, reviewed_by = $2, reviewed_at = NOW()
		 WHERE id = $3 AND user_id = $4`,
		req.Reason, adminID, req.DocumentID, uid,
	)

	h.db.ExecContext(c, `UPDATE users SET kyc_status = 'rejected' WHERE id = $1`, uid)

	c.JSON(http.StatusOK, gin.H{"message": "KYC document rejected"})
}

// ListTransactions for finance panel
func (h *Handler) ListTransactions(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize := 50
	offset := (page - 1) * pageSize
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
	h.db.QueryRowContext(c, countQuery, countArgs...).Scan(&total)

	query += ` ORDER BY t.created_at DESC LIMIT $` + strconv.Itoa(idx) + ` OFFSET $` + strconv.Itoa(idx+1)
	args = append(args, pageSize, offset)

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
			continue
		}
		txns = append(txns, t)
	}
	if txns == nil {
		txns = []TxnRow{}
	}

	c.JSON(http.StatusOK, gin.H{
		"transactions": txns,
		"total":        total,
		"page":         page,
		"total_pages":  int(math.Ceil(float64(total) / float64(pageSize))),
	})
}

// GetAuditLogs for super admin
func (h *Handler) GetAuditLogs(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize := 50
	offset := (page - 1) * pageSize

	rows, err := h.db.QueryContext(c,
		`SELECT id, actor_type, actor_id, action, ip_address, response_status, created_at
		 FROM audit_logs ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
		pageSize, offset,
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
			continue
		}
		if actorID.Valid {
			e.ActorID = &actorID.String
		}
		if ip.Valid {
			e.IPAddress = &ip.String
		}
		if respStatus.Valid {
			v := int(respStatus.Int32)
			e.ResponseStatus = &v
		}
		entries = append(entries, e)
	}
	if entries == nil {
		entries = []AuditEntry{}
	}

	c.JSON(http.StatusOK, gin.H{"audit_logs": entries, "page": page})
}

// GetFeatureFlags lists all feature flags
func (h *Handler) GetFeatureFlags(c *gin.Context) {
	rows, err := h.db.QueryContext(c,
		`SELECT id, name, description, enabled, created_at, updated_at FROM feature_flags ORDER BY name`,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
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
			continue
		}
		if desc.Valid {
			f.Description = &desc.String
		}
		flags = append(flags, f)
	}
	if flags == nil {
		flags = []Flag{}
	}

	c.JSON(http.StatusOK, gin.H{"feature_flags": flags})
}

// ToggleFeatureFlag enables/disables a feature flag
func (h *Handler) ToggleFeatureFlag(c *gin.Context) {
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Feature flag not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Feature flag updated", "enabled": req.Enabled})
}

// SystemHealth returns basic system health info
func (h *Handler) SystemHealth(c *gin.Context) {
	var userCount, txnCount int
	h.db.QueryRowContext(c, `SELECT COUNT(*) FROM users`).Scan(&userCount)
	h.db.QueryRowContext(c, `SELECT COUNT(*) FROM transactions`).Scan(&txnCount)

	var pendingTxns int
	h.db.QueryRowContext(c, `SELECT COUNT(*) FROM transactions WHERE status = 'pending'`).Scan(&pendingTxns)

	var pendingKYC int
	h.db.QueryRowContext(c, `SELECT COUNT(*) FROM kyc_documents WHERE status = 'pending'`).Scan(&pendingKYC)

	c.JSON(http.StatusOK, gin.H{
		"status":               "healthy",
		"timestamp":            time.Now().UTC(),
		"total_users":          userCount,
		"total_transactions":   txnCount,
		"pending_transactions": pendingTxns,
		"pending_kyc":          pendingKYC,
	})
}
