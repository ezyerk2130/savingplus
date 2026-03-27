package loan

import (
	"database/sql"
	"fmt"
	"net/http"
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

type ApplyRequest struct {
	Amount   float64 `json:"amount" binding:"required,gt=0"`
	TermDays int     `json:"term_days" binding:"required"`
}

type LoanResponse struct {
	ID               string  `json:"id"`
	LoanNumber       string  `json:"loan_number"`
	Type             string  `json:"type"`
	Principal        string  `json:"principal"`
	InterestRate     string  `json:"interest_rate"`
	TotalDue         string  `json:"total_due"`
	AmountPaid       string  `json:"amount_paid"`
	Currency         string  `json:"currency"`
	TermDays         int     `json:"term_days"`
	Status           string  `json:"status"`
	CollateralType   *string `json:"collateral_type,omitempty"`
	CollateralAmount *string `json:"collateral_amount,omitempty"`
	DueDate          string  `json:"due_date"`
	DisbursedAt      *string `json:"disbursed_at,omitempty"`
	CreatedAt        string  `json:"created_at"`
}

// CheckEligibility checks if the user qualifies for a savings-backed loan.
func (h *Handler) CheckEligibility(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	// Get total savings balance across all active savings plans
	var savingsBalance float64
	err := h.db.QueryRowContext(c,
		`SELECT COALESCE(SUM(current_amount), 0) FROM savings_plans WHERE user_id = $1 AND status IN ('active', 'matured')`,
		userID,
	).Scan(&savingsBalance)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to query savings balance for eligibility")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Get user KYC tier
	var kycTier int
	err = h.db.QueryRowContext(c, `SELECT kyc_tier FROM users WHERE id = $1`, userID).Scan(&kycTier)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to query user tier for eligibility")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Check existing active loans
	var activeLoanCount int
	err = h.db.QueryRowContext(c,
		`SELECT COUNT(*) FROM loans WHERE user_id = $1 AND status IN ('pending', 'approved', 'disbursed', 'repaying')`,
		userID,
	).Scan(&activeLoanCount)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to count active loans")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	maxLoanAmount := savingsBalance * 0.80
	interestRate := 9.00
	eligible := savingsBalance > 0 && kycTier >= 1 && activeLoanCount == 0

	c.JSON(http.StatusOK, gin.H{
		"eligible":        eligible,
		"max_loan_amount": response.FormatMoney(maxLoanAmount),
		"interest_rate":   fmt.Sprintf("%.2f%%", interestRate),
		"savings_balance": response.FormatMoney(savingsBalance),
		"kyc_tier":        kycTier,
		"active_loans":    activeLoanCount,
	})
}

// ApplyForLoan creates a new savings-backed loan application.
func (h *Handler) ApplyForLoan(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	var req ApplyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	// Validate term_days
	if req.TermDays < 7 || req.TermDays > 90 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Term must be between 7 and 90 days"})
		return
	}

	// Check KYC tier
	var kycTier int
	err := h.db.QueryRowContext(c, `SELECT kyc_tier FROM users WHERE id = $1`, userID).Scan(&kycTier)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to query user tier")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	if kycTier < 1 {
		c.JSON(http.StatusForbidden, gin.H{"error": apperr.ErrKYCRequired.Message})
		return
	}

	// Get total savings balance
	var savingsBalance float64
	err = h.db.QueryRowContext(c,
		`SELECT COALESCE(SUM(current_amount), 0) FROM savings_plans WHERE user_id = $1 AND status IN ('active', 'matured')`,
		userID,
	).Scan(&savingsBalance)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to query savings balance")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	maxLoan := savingsBalance * 0.80
	if req.Amount > maxLoan {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":           "Loan amount exceeds maximum allowed",
			"max_loan_amount": response.FormatMoney(maxLoan),
			"savings_balance": response.FormatMoney(savingsBalance),
		})
		return
	}

	// Get wallet
	var walletID string
	err = h.db.QueryRowContext(c, `SELECT id FROM wallets WHERE user_id = $1 AND currency = 'TZS' LIMIT 1`, userID).Scan(&walletID)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to get wallet")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Calculate loan terms
	interestRate := 9.00 // 9% annual for savings_backed
	totalDue := req.Amount * (1 + (interestRate/100.0)*(float64(req.TermDays)/365.0))
	dueDate := time.Now().AddDate(0, 0, req.TermDays)

	loanID := uuid.New()
	loanNumber := fmt.Sprintf("LN-%s", loanID.String()[:8])

	_, err = h.db.ExecContext(c,
		`INSERT INTO loans (id, user_id, wallet_id, loan_number, type, principal, interest_rate, total_due,
		 currency, term_days, status, collateral_type, collateral_amount, due_date)
		 VALUES ($1, $2, $3, $4, 'savings_backed', $5, $6, $7, 'TZS', $8, 'pending', 'savings_balance', $9, $10)`,
		loanID, userID, walletID, loanNumber, req.Amount, interestRate, totalDue, req.TermDays, savingsBalance, dueDate,
	)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to create loan record")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"loan_id":     loanID.String(),
		"loan_number": loanNumber,
		"principal":   response.FormatMoney(req.Amount),
		"total_due":   response.FormatMoney(totalDue),
		"term_days":   req.TermDays,
		"due_date":    dueDate.Format("2006-01-02"),
		"status":      "pending",
		"message":     "Loan application submitted. Awaiting admin approval.",
	})
}

// ListLoans returns the user's loans with pagination and optional status filter.
func (h *Handler) ListLoans(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	status := c.DefaultQuery("status", "")
	pg := response.GetPagination(c, 20)

	countQuery := `SELECT COUNT(*) FROM loans WHERE user_id = $1`
	dataQuery := `SELECT id, loan_number, type, principal, interest_rate, total_due, amount_paid,
				  currency, term_days, status, collateral_type, collateral_amount, due_date, disbursed_at, created_at
				  FROM loans WHERE user_id = $1`
	args := []interface{}{userID}

	if status != "" {
		countQuery += ` AND status = $2`
		dataQuery += ` AND status = $2`
		args = append(args, status)
	}
	dataQuery += ` ORDER BY created_at DESC LIMIT $` + fmt.Sprintf("%d", len(args)+1) + ` OFFSET $` + fmt.Sprintf("%d", len(args)+2)

	var total int
	if err := h.db.QueryRowContext(c, countQuery, args...).Scan(&total); err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to count loans")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	dataArgs := append(args, pg.PageSize, pg.Offset)
	rows, err := h.db.QueryContext(c, dataQuery, dataArgs...)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to query loans")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var loans []LoanResponse
	for rows.Next() {
		var l LoanResponse
		var principal, interestRate, totalDue, amountPaid float64
		var collateralType sql.NullString
		var collateralAmount sql.NullFloat64
		var disbursedAt sql.NullTime

		err := rows.Scan(&l.ID, &l.LoanNumber, &l.Type, &principal, &interestRate, &totalDue, &amountPaid,
			&l.Currency, &l.TermDays, &l.Status, &collateralType, &collateralAmount, &l.DueDate, &disbursedAt, &l.CreatedAt)
		if err != nil {
			log.WithError(err).WithField("user_id", userID).Error("Failed to scan loan row")
			continue
		}

		l.Principal = response.FormatMoney(principal)
		l.InterestRate = fmt.Sprintf("%.2f%%", interestRate)
		l.TotalDue = response.FormatMoney(totalDue)
		l.AmountPaid = response.FormatMoney(amountPaid)
		l.CollateralType = response.NullStr(collateralType)
		l.CollateralAmount = response.FloatStr(collateralAmount)
		l.DisbursedAt = response.NullTime(disbursedAt)

		loans = append(loans, l)
	}

	response.PagedList(c, "loans", response.EmptySlice(loans), pg, total)
}

// GetLoan returns a single loan by ID.
func (h *Handler) GetLoan(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	loanID := c.Param("id")

	var l LoanResponse
	var principal, interestRate, totalDue, amountPaid float64
	var collateralType sql.NullString
	var collateralAmount sql.NullFloat64
	var disbursedAt sql.NullTime

	err := h.db.QueryRowContext(c,
		`SELECT id, loan_number, type, principal, interest_rate, total_due, amount_paid,
		 currency, term_days, status, collateral_type, collateral_amount, due_date, disbursed_at, created_at
		 FROM loans WHERE id = $1 AND user_id = $2`,
		loanID, userID,
	).Scan(&l.ID, &l.LoanNumber, &l.Type, &principal, &interestRate, &totalDue, &amountPaid,
		&l.Currency, &l.TermDays, &l.Status, &collateralType, &collateralAmount, &l.DueDate, &disbursedAt, &l.CreatedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).WithField("user_id", userID).WithField("loan_id", loanID).Error("Failed to get loan")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	l.Principal = response.FormatMoney(principal)
	l.InterestRate = fmt.Sprintf("%.2f%%", interestRate)
	l.TotalDue = response.FormatMoney(totalDue)
	l.AmountPaid = response.FormatMoney(amountPaid)
	l.CollateralType = response.NullStr(collateralType)
	l.CollateralAmount = response.FloatStr(collateralAmount)
	l.DisbursedAt = response.NullTime(disbursedAt)

	c.JSON(http.StatusOK, l)
}

// RepayLoan processes a loan repayment from the user's wallet.
func (h *Handler) RepayLoan(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	loanID := c.Param("id")

	var req struct {
		Amount float64 `json:"amount" binding:"required,gt=0"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin loan repayment transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	// Get loan details
	var loanStatus string
	var totalDue, amountPaid float64
	var walletID string
	err = tx.QueryRowContext(c,
		`SELECT status, total_due, amount_paid, wallet_id FROM loans WHERE id = $1 AND user_id = $2 FOR UPDATE`,
		loanID, userID,
	).Scan(&loanStatus, &totalDue, &amountPaid, &walletID)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get loan for repayment")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if loanStatus != "disbursed" && loanStatus != "repaying" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Loan is not in a repayable state", "status": loanStatus})
		return
	}

	remaining := totalDue - amountPaid
	if req.Amount > remaining {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":            "Repayment amount exceeds remaining balance",
			"remaining_amount": response.FormatMoney(remaining),
		})
		return
	}

	// Debit wallet
	var available float64
	err = tx.QueryRowContext(c,
		`SELECT available_balance FROM wallets WHERE id = $1 FOR UPDATE`,
		walletID,
	).Scan(&available)
	if err != nil {
		log.WithError(err).Error("Failed to get wallet for loan repayment")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if available < req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrInsufficientBalance.Message})
		return
	}

	newBalance := available - req.Amount
	if _, err = tx.ExecContext(c, `UPDATE wallets SET available_balance = $1 WHERE id = $2`, newBalance, walletID); err != nil {
		log.WithError(err).Error("Failed to debit wallet for loan repayment")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create transaction record
	txnID := uuid.New()
	ref := fmt.Sprintf("LN-REP-%s-%d", txnID.String()[:8], time.Now().UnixMilli())
	if _, err = tx.ExecContext(c,
		`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, currency, reference, description, completed_at)
		 VALUES ($1, $2, $3, 'loan_repayment', 'completed', $4, 'TZS', $5, $6, NOW())`,
		txnID, userID, walletID, req.Amount, ref, "Loan repayment",
	); err != nil {
		log.WithError(err).Error("Failed to create loan repayment transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create ledger entry
	if _, err = tx.ExecContext(c,
		`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
		 VALUES ($1, $2, $3, 'debit', $4, $5, $6)`,
		uuid.New(), txnID, walletID, req.Amount, newBalance, "Loan repayment",
	); err != nil {
		log.WithError(err).Error("Failed to create ledger entry for loan repayment")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create loan_repayment record
	repaymentID := uuid.New()
	if _, err = tx.ExecContext(c,
		`INSERT INTO loan_repayments (id, loan_id, user_id, amount, principal_portion, interest_portion, payment_method, status)
		 VALUES ($1, $2, $3, $4, $5, $6, 'wallet', 'completed')`,
		repaymentID, loanID, userID, req.Amount, req.Amount, 0.00,
	); err != nil {
		log.WithError(err).Error("Failed to create loan repayment record")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Update loan amount_paid and status
	newAmountPaid := amountPaid + req.Amount
	newStatus := "repaying"
	if newAmountPaid >= totalDue {
		newStatus = "paid"
	}

	if _, err = tx.ExecContext(c,
		`UPDATE loans SET amount_paid = $1, status = $2 WHERE id = $3`,
		newAmountPaid, newStatus, loanID,
	); err != nil {
		log.WithError(err).Error("Failed to update loan after repayment")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit loan repayment")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":          "Loan repayment successful",
		"repayment_id":     repaymentID.String(),
		"transaction_id":   txnID.String(),
		"amount_paid":      response.FormatMoney(req.Amount),
		"total_paid":       response.FormatMoney(newAmountPaid),
		"remaining_amount": response.FormatMoney(totalDue - newAmountPaid),
		"loan_status":      newStatus,
		"wallet_balance":   response.FormatMoney(newBalance),
	})
}
