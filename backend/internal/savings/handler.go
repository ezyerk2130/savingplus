package savings

import (
	"database/sql"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/pkg/logger"
	"github.com/savingplus/backend/pkg/response"
)

type Handler struct {
	db *sql.DB
}

func NewHandler(db *sql.DB) *Handler {
	return &Handler{db: db}
}

type CreatePlanRequest struct {
	Name               string   `json:"name" binding:"required,min=1,max=100"`
	Type               string   `json:"type" binding:"required,oneof=flexible locked target"`
	InitialAmount      *float64 `json:"initial_amount,omitempty"`
	TargetAmount       *float64 `json:"target_amount,omitempty"`
	LockDurationDays   *int     `json:"lock_duration_days,omitempty"`
	AutoDebit          bool     `json:"auto_debit"`
	AutoDebitAmount    *float64 `json:"auto_debit_amount,omitempty"`
	AutoDebitFrequency *string  `json:"auto_debit_frequency,omitempty"`
}

type PlanResponse struct {
	ID                 string  `json:"id"`
	Name               string  `json:"name"`
	Type               string  `json:"type"`
	Status             string  `json:"status"`
	TargetAmount       *string `json:"target_amount,omitempty"`
	CurrentAmount      string  `json:"current_amount"`
	InterestRate       string  `json:"interest_rate"`
	LockDurationDays   *int    `json:"lock_duration_days,omitempty"`
	MaturityDate       *string `json:"maturity_date,omitempty"`
	AutoDebit          bool    `json:"auto_debit"`
	AutoDebitAmount    *string `json:"auto_debit_amount,omitempty"`
	AutoDebitFrequency *string `json:"auto_debit_frequency,omitempty"`
	CreatedAt          string  `json:"created_at"`
}

func (h *Handler) CreatePlan(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	var req CreatePlanRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	// Validate based on type
	if req.Type == "target" && (req.TargetAmount == nil || *req.TargetAmount <= 0) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Target amount required for target savings plans"})
		return
	}
	if req.Type == "locked" && (req.LockDurationDays == nil || *req.LockDurationDays < 30) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Lock duration (minimum 30 days) required for locked savings plans"})
		return
	}
	if req.AutoDebit && (req.AutoDebitAmount == nil || req.AutoDebitFrequency == nil) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Auto-debit amount and frequency required when auto-debit is enabled"})
		return
	}

	// Validate initial amount for target plans
	initialAmount := 0.0
	if req.InitialAmount != nil && *req.InitialAmount > 0 {
		initialAmount = *req.InitialAmount
		// For target plans, initial amount can't exceed target
		if req.Type == "target" && req.TargetAmount != nil && initialAmount > *req.TargetAmount {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Initial amount cannot exceed target amount"})
			return
		}
	}

	// Determine interest rate based on type
	var interestRate float64
	switch req.Type {
	case "flexible":
		interestRate = 0.04 // 4% p.a.
	case "locked":
		interestRate = 0.08 // 8% p.a.
	case "target":
		interestRate = 0.06 // 6% p.a.
	}

	planID := uuid.New()
	var maturityDate *time.Time
	if req.LockDurationDays != nil {
		t := time.Now().AddDate(0, 0, *req.LockDurationDays)
		maturityDate = &t
	}

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin create plan transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	// Get wallet
	var walletID string
	var available float64
	err = tx.QueryRowContext(c, `SELECT id, available_balance FROM wallets WHERE user_id = $1 AND currency = 'TZS' FOR UPDATE`, userID).Scan(&walletID, &available)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to get wallet")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Check balance if initial deposit
	if initialAmount > 0 && available < initialAmount {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Insufficient wallet balance for initial deposit"})
		return
	}

	// Create the plan
	_, err = tx.ExecContext(c,
		`INSERT INTO savings_plans (id, user_id, wallet_id, name, type, target_amount, current_amount, interest_rate,
		 lock_duration_days, maturity_date, auto_debit, auto_debit_amount, auto_debit_frequency)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
		planID, userID, walletID, req.Name, req.Type, req.TargetAmount, initialAmount, interestRate,
		req.LockDurationDays, maturityDate, req.AutoDebit, req.AutoDebitAmount, req.AutoDebitFrequency,
	)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to create savings plan")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// If initial deposit, debit wallet and create ledger entry
	if initialAmount > 0 {
		newBalance := available - initialAmount
		if _, err = tx.ExecContext(c, `UPDATE wallets SET available_balance = $1 WHERE id = $2`, newBalance, walletID); err != nil {
			log.WithError(err).Error("Failed to debit wallet for initial savings deposit")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}

		txnID := uuid.New()
		ref := fmt.Sprintf("SAV-NEW-%s-%d", txnID.String()[:8], time.Now().UnixMilli())
		if _, err = tx.ExecContext(c,
			`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, reference, description, completed_at)
			 VALUES ($1, $2, $3, 'savings_lock', 'completed', $4, $5, $6, NOW())`,
			txnID, userID, walletID, initialAmount, ref, "Initial deposit to savings plan: "+req.Name,
		); err != nil {
			log.WithError(err).Error("Failed to create initial deposit transaction")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}

		if _, err = tx.ExecContext(c,
			`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
			 VALUES ($1, $2, $3, 'debit', $4, $5, $6)`,
			uuid.New(), txnID, walletID, initialAmount, newBalance, "Initial savings plan deposit",
		); err != nil {
			log.WithError(err).Error("Failed to create ledger entry for initial deposit")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}

		// Check if target plan is immediately met
		if req.Type == "target" && req.TargetAmount != nil && initialAmount >= *req.TargetAmount {
			if _, err = tx.ExecContext(c, `UPDATE savings_plans SET status = 'matured' WHERE id = $1`, planID); err != nil {
				log.WithError(err).Warn("Failed to mark plan as matured after initial deposit, continuing")
			}
		}
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit create plan transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	resp := gin.H{
		"plan_id":       planID.String(),
		"name":          req.Name,
		"type":          req.Type,
		"interest_rate": strconv.FormatFloat(interestRate*100, 'f', 2, 64) + "%",
		"message":       "Savings plan created successfully",
	}
	if initialAmount > 0 {
		resp["initial_deposit"] = response.FormatMoney(initialAmount)
	}
	c.JSON(http.StatusCreated, resp)
}

func (h *Handler) ListPlans(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	status := c.DefaultQuery("status", "")

	query := `SELECT id, name, type, status, target_amount, current_amount, interest_rate,
			  lock_duration_days, maturity_date, auto_debit, auto_debit_amount, auto_debit_frequency, created_at
			  FROM savings_plans WHERE user_id = $1`
	args := []interface{}{userID}

	if status != "" {
		query += ` AND status = $2`
		args = append(args, status)
	}
	query += ` ORDER BY created_at DESC`

	rows, err := h.db.QueryContext(c, query, args...)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to query savings plans")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var plans []PlanResponse
	for rows.Next() {
		var p PlanResponse
		var currentAmt, rate float64
		var targetAmtNull sql.NullFloat64
		var lockDays sql.NullInt32
		var matDate sql.NullTime
		var autoAmt sql.NullFloat64
		var autoFreq sql.NullString

		err := rows.Scan(&p.ID, &p.Name, &p.Type, &p.Status, &targetAmtNull, &currentAmt, &rate,
			&lockDays, &matDate, &p.AutoDebit, &autoAmt, &autoFreq, &p.CreatedAt)
		if err != nil {
			log.WithError(err).WithField("user_id", userID).Error("Failed to scan savings plan row")
			continue
		}

		p.CurrentAmount = response.FormatMoney(currentAmt)
		p.InterestRate = strconv.FormatFloat(rate*100, 'f', 2, 64) + "%"
		p.TargetAmount = response.FloatStr(targetAmtNull)
		p.LockDurationDays = response.NullInt(lockDays)
		p.MaturityDate = response.NullTime(matDate)
		p.AutoDebitAmount = response.FloatStr(autoAmt)
		p.AutoDebitFrequency = response.NullStr(autoFreq)

		plans = append(plans, p)
	}

	c.JSON(http.StatusOK, gin.H{"plans": response.EmptySlice(plans), "total": len(response.EmptySlice(plans))})
}

func (h *Handler) GetPlan(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	planID := c.Param("id")

	var p PlanResponse
	var targetAmtNull sql.NullFloat64
	var currentAmt, rate float64
	var lockDays sql.NullInt32
	var matDate sql.NullTime
	var autoAmt sql.NullFloat64
	var autoFreq sql.NullString

	err := h.db.QueryRowContext(c,
		`SELECT id, name, type, status, target_amount, current_amount, interest_rate,
		 lock_duration_days, maturity_date, auto_debit, auto_debit_amount, auto_debit_frequency, created_at
		 FROM savings_plans WHERE id = $1 AND user_id = $2`,
		planID, userID,
	).Scan(&p.ID, &p.Name, &p.Type, &p.Status, &targetAmtNull, &currentAmt, &rate,
		&lockDays, &matDate, &p.AutoDebit, &autoAmt, &autoFreq, &p.CreatedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).WithField("user_id", userID).WithField("plan_id", planID).Error("Failed to get savings plan")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	p.CurrentAmount = response.FormatMoney(currentAmt)
	p.InterestRate = strconv.FormatFloat(rate*100, 'f', 2, 64) + "%"
	p.TargetAmount = response.FloatStr(targetAmtNull)
	p.LockDurationDays = response.NullInt(lockDays)
	p.MaturityDate = response.NullTime(matDate)
	p.AutoDebitAmount = response.FloatStr(autoAmt)
	p.AutoDebitFrequency = response.NullStr(autoFreq)

	c.JSON(http.StatusOK, p)
}

// DepositToPlan moves funds from wallet to a savings plan
func (h *Handler) DepositToPlan(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	planID := c.Param("id")

	var req struct {
		Amount float64 `json:"amount" binding:"required,gt=0"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin savings deposit transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	// Verify plan belongs to user and is active
	var planStatus, planType string
	var currentAmount float64
	var targetAmount sql.NullFloat64
	err = tx.QueryRowContext(c,
		`SELECT status, type, current_amount, target_amount FROM savings_plans WHERE id = $1 AND user_id = $2 FOR UPDATE`,
		planID, userID,
	).Scan(&planStatus, &planType, &currentAmount, &targetAmount)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get savings plan")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if planStatus != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Savings plan is not active"})
		return
	}

	// For target plans, don't exceed the target
	if targetAmount.Valid && currentAmount+req.Amount > targetAmount.Float64 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":  "Deposit would exceed target amount",
			"detail": fmt.Sprintf("Target: %s, Current: %s, Max deposit: %s", response.FormatMoney(targetAmount.Float64), response.FormatMoney(currentAmount), response.FormatMoney(targetAmount.Float64-currentAmount)),
		})
		return
	}

	// Debit wallet
	var walletID string
	var available float64
	err = tx.QueryRowContext(c,
		`SELECT id, available_balance FROM wallets WHERE user_id = $1 AND currency = 'TZS' FOR UPDATE`,
		userID,
	).Scan(&walletID, &available)
	if err != nil {
		log.WithError(err).Error("Failed to get wallet for savings deposit")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if available < req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrInsufficientBalance.Message})
		return
	}

	newBalance := available - req.Amount
	if _, err = tx.ExecContext(c, `UPDATE wallets SET available_balance = $1 WHERE id = $2`, newBalance, walletID); err != nil {
		log.WithError(err).Error("Failed to debit wallet for savings")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create transaction record
	txnID := uuid.New()
	ref := fmt.Sprintf("SAV-DEP-%s-%d", txnID.String()[:8], time.Now().UnixMilli())
	if _, err = tx.ExecContext(c,
		`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, reference, description, completed_at)
		 VALUES ($1, $2, $3, 'savings_lock', 'completed', $4, $5, $6, NOW())`,
		txnID, userID, walletID, req.Amount, ref, "Deposit to savings plan",
	); err != nil {
		log.WithError(err).Error("Failed to create savings deposit transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create ledger entry
	if _, err = tx.ExecContext(c,
		`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
		 VALUES ($1, $2, $3, 'debit', $4, $5, $6)`,
		uuid.New(), txnID, walletID, req.Amount, newBalance, "Savings plan deposit",
	); err != nil {
		log.WithError(err).Error("Failed to create ledger entry for savings deposit")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Update plan balance
	newPlanAmount := currentAmount + req.Amount
	updateQuery := `UPDATE savings_plans SET current_amount = $1 WHERE id = $2`
	if _, err = tx.ExecContext(c, updateQuery, newPlanAmount, planID); err != nil {
		log.WithError(err).Error("Failed to update savings plan amount")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// If target plan reached its goal, mark as matured
	if planType == "target" && targetAmount.Valid && newPlanAmount >= targetAmount.Float64 {
		if _, err = tx.ExecContext(c, `UPDATE savings_plans SET status = 'matured' WHERE id = $1`, planID); err != nil {
			log.WithError(err).Warn("Failed to mark plan as matured after deposit, continuing")
		}
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit savings deposit")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":        "Deposit to savings plan successful",
		"transaction_id": txnID.String(),
		"plan_balance":   response.FormatMoney(newPlanAmount),
		"wallet_balance": response.FormatMoney(newBalance),
	})
}

// WithdrawFromPlan moves funds from a savings plan back to wallet
func (h *Handler) WithdrawFromPlan(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	planID := c.Param("id")

	var req struct {
		Amount float64 `json:"amount" binding:"required,gt=0"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin savings withdrawal transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	var planStatus, planType string
	var currentAmount float64
	var maturityDate sql.NullTime
	err = tx.QueryRowContext(c,
		`SELECT status, type, current_amount, maturity_date FROM savings_plans WHERE id = $1 AND user_id = $2 FOR UPDATE`,
		planID, userID,
	).Scan(&planStatus, &planType, &currentAmount, &maturityDate)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get savings plan for withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if planStatus != "active" && planStatus != "matured" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot withdraw from this plan", "status": planStatus})
		return
	}

	// Locked plans cannot be withdrawn before maturity
	if planType == "locked" && planStatus == "active" {
		if maturityDate.Valid && time.Now().Before(maturityDate.Time) {
			c.JSON(http.StatusForbidden, gin.H{
				"error":         "Locked savings plan has not matured yet",
				"maturity_date": maturityDate.Time.Format(time.RFC3339),
			})
			return
		}
	}

	if currentAmount < req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Insufficient savings plan balance"})
		return
	}

	// Credit wallet
	var walletID string
	var available float64
	err = tx.QueryRowContext(c,
		`SELECT id, available_balance FROM wallets WHERE user_id = $1 AND currency = 'TZS' FOR UPDATE`,
		userID,
	).Scan(&walletID, &available)
	if err != nil {
		log.WithError(err).Error("Failed to get wallet for savings withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	newBalance := available + req.Amount
	if _, err = tx.ExecContext(c, `UPDATE wallets SET available_balance = $1 WHERE id = $2`, newBalance, walletID); err != nil {
		log.WithError(err).Error("Failed to credit wallet for savings withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create transaction record
	txnID := uuid.New()
	ref := fmt.Sprintf("SAV-WDR-%s-%d", txnID.String()[:8], time.Now().UnixMilli())
	if _, err = tx.ExecContext(c,
		`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, reference, description, completed_at)
		 VALUES ($1, $2, $3, 'savings_unlock', 'completed', $4, $5, $6, NOW())`,
		txnID, userID, walletID, req.Amount, ref, "Withdrawal from savings plan",
	); err != nil {
		log.WithError(err).Error("Failed to create savings withdrawal transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create ledger entry
	if _, err = tx.ExecContext(c,
		`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
		 VALUES ($1, $2, $3, 'credit', $4, $5, $6)`,
		uuid.New(), txnID, walletID, req.Amount, newBalance, "Savings plan withdrawal",
	); err != nil {
		log.WithError(err).Error("Failed to create ledger entry for savings withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Update plan balance
	newPlanAmount := currentAmount - req.Amount
	if _, err = tx.ExecContext(c, `UPDATE savings_plans SET current_amount = $1 WHERE id = $2`, newPlanAmount, planID); err != nil {
		log.WithError(err).Error("Failed to update savings plan amount after withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// If fully withdrawn, mark as withdrawn
	if newPlanAmount == 0 {
		if _, err = tx.ExecContext(c, `UPDATE savings_plans SET status = 'withdrawn' WHERE id = $1`, planID); err != nil {
			log.WithError(err).Warn("Failed to mark plan as withdrawn, continuing")
		}
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit savings withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":        "Withdrawal from savings plan successful",
		"transaction_id": txnID.String(),
		"plan_balance":   response.FormatMoney(newPlanAmount),
		"wallet_balance": response.FormatMoney(newBalance),
	})
}

// CancelPlan cancels a savings plan and returns funds to wallet
func (h *Handler) CancelPlan(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	planID := c.Param("id")

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin plan cancellation transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	var planStatus, planType string
	var currentAmount float64
	var maturityDate sql.NullTime
	err = tx.QueryRowContext(c,
		`SELECT status, type, current_amount, maturity_date FROM savings_plans WHERE id = $1 AND user_id = $2 FOR UPDATE`,
		planID, userID,
	).Scan(&planStatus, &planType, &currentAmount, &maturityDate)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get savings plan for cancellation")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if planStatus != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Only active plans can be cancelled", "status": planStatus})
		return
	}

	// Locked plans cannot be cancelled before maturity (funds would be forfeited)
	if planType == "locked" && maturityDate.Valid && time.Now().Before(maturityDate.Time) {
		c.JSON(http.StatusForbidden, gin.H{
			"error":         "Cannot cancel a locked plan before maturity",
			"maturity_date": maturityDate.Time.Format(time.RFC3339),
		})
		return
	}

	// Return funds to wallet if any
	if currentAmount > 0 {
		var walletID string
		var available float64
		err = tx.QueryRowContext(c,
			`SELECT id, available_balance FROM wallets WHERE user_id = $1 AND currency = 'TZS' FOR UPDATE`,
			userID,
		).Scan(&walletID, &available)
		if err != nil {
			log.WithError(err).Error("Failed to get wallet for plan cancellation")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}

		newBalance := available + currentAmount
		if _, err = tx.ExecContext(c, `UPDATE wallets SET available_balance = $1 WHERE id = $2`, newBalance, walletID); err != nil {
			log.WithError(err).Error("Failed to credit wallet for plan cancellation")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}

		txnID := uuid.New()
		ref := fmt.Sprintf("SAV-CAN-%s-%d", txnID.String()[:8], time.Now().UnixMilli())
		if _, err = tx.ExecContext(c,
			`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, reference, description, completed_at)
			 VALUES ($1, $2, $3, 'savings_unlock', 'completed', $4, $5, $6, NOW())`,
			txnID, userID, walletID, currentAmount, ref, "Savings plan cancelled - funds returned",
		); err != nil {
			log.WithError(err).Error("Failed to create cancellation transaction")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}

		if _, err = tx.ExecContext(c,
			`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
			 VALUES ($1, $2, $3, 'credit', $4, $5, $6)`,
			uuid.New(), txnID, walletID, currentAmount, newBalance, "Savings plan cancellation refund",
		); err != nil {
			log.WithError(err).Error("Failed to create ledger entry for cancellation")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}
	}

	// Mark plan as cancelled
	if _, err = tx.ExecContext(c,
		`UPDATE savings_plans SET status = 'cancelled', current_amount = 0 WHERE id = $1`,
		planID,
	); err != nil {
		log.WithError(err).Error("Failed to mark plan as cancelled")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit plan cancellation")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":         "Savings plan cancelled",
		"refunded_amount": response.FormatMoney(currentAmount),
	})
}
