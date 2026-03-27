package investment

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

type ProductResponse struct {
	ID             string  `json:"id"`
	Name           string  `json:"name"`
	Description    *string `json:"description,omitempty"`
	Type           string  `json:"type"`
	Currency       string  `json:"currency"`
	MinAmount      string  `json:"min_amount"`
	MaxAmount      *string `json:"max_amount,omitempty"`
	ExpectedReturn string  `json:"expected_return"`
	DurationDays   *int    `json:"duration_days,omitempty"`
	RiskLevel      string  `json:"risk_level"`
	AvailablePool  string  `json:"available_pool"`
	Status         string  `json:"status"`
	CreatedAt      string  `json:"created_at"`
}

type InvestmentResponse struct {
	ID             string  `json:"id"`
	ProductID      string  `json:"product_id"`
	ProductName    string  `json:"product_name"`
	ProductType    string  `json:"product_type"`
	Amount         string  `json:"amount"`
	Currency       string  `json:"currency"`
	ExpectedReturn string  `json:"expected_return"`
	ActualReturn   *string `json:"actual_return,omitempty"`
	Status         string  `json:"status"`
	MaturityDate   *string `json:"maturity_date,omitempty"`
	MaturedAt      *string `json:"matured_at,omitempty"`
	CreatedAt      string  `json:"created_at"`
}

type InvestRequest struct {
	ProductID string  `json:"product_id" binding:"required"`
	Amount    float64 `json:"amount" binding:"required,gt=0"`
}

// ListProducts returns all active investment products, optionally filtered by type.
func (h *Handler) ListProducts(c *gin.Context) {
	log := logger.Ctx(c)
	typeFilter := c.Query("type")

	query := `SELECT id, name, description, type, currency, min_amount, max_amount,
			  expected_return, duration_days, risk_level, available_pool, status, created_at
			  FROM investment_products WHERE status = 'active'`
	args := []interface{}{}

	if typeFilter != "" {
		query += ` AND type = $1`
		args = append(args, typeFilter)
	}
	query += ` ORDER BY created_at DESC`

	rows, err := h.db.QueryContext(c, query, args...)
	if err != nil {
		log.WithError(err).Error("Failed to query investment products")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var products []ProductResponse
	for rows.Next() {
		var p ProductResponse
		var desc sql.NullString
		var maxAmt sql.NullFloat64
		var durDays sql.NullInt32
		var minAmt, expectedRet, availPool float64

		err := rows.Scan(&p.ID, &p.Name, &desc, &p.Type, &p.Currency, &minAmt, &maxAmt,
			&expectedRet, &durDays, &p.RiskLevel, &availPool, &p.Status, &p.CreatedAt)
		if err != nil {
			log.WithError(err).Error("Failed to scan investment product row")
			continue
		}

		p.Description = response.NullStr(desc)
		p.MinAmount = response.FormatMoney(minAmt)
		p.MaxAmount = response.FloatStr(maxAmt)
		p.ExpectedReturn = fmt.Sprintf("%.2f%%", expectedRet)
		p.DurationDays = response.NullInt(durDays)
		p.AvailablePool = response.FormatMoney(availPool)

		products = append(products, p)
	}

	c.JSON(http.StatusOK, gin.H{"products": response.EmptySlice(products), "total": len(response.EmptySlice(products))})
}

// GetProduct returns a single investment product by ID.
func (h *Handler) GetProduct(c *gin.Context) {
	log := logger.Ctx(c)
	productID := c.Param("id")

	var p ProductResponse
	var desc sql.NullString
	var maxAmt sql.NullFloat64
	var durDays sql.NullInt32
	var minAmt, expectedRet, availPool float64

	err := h.db.QueryRowContext(c,
		`SELECT id, name, description, type, currency, min_amount, max_amount,
		 expected_return, duration_days, risk_level, available_pool, status, created_at
		 FROM investment_products WHERE id = $1`,
		productID,
	).Scan(&p.ID, &p.Name, &desc, &p.Type, &p.Currency, &minAmt, &maxAmt,
		&expectedRet, &durDays, &p.RiskLevel, &availPool, &p.Status, &p.CreatedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).WithField("product_id", productID).Error("Failed to get investment product")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	p.Description = response.NullStr(desc)
	p.MinAmount = response.FormatMoney(minAmt)
	p.MaxAmount = response.FloatStr(maxAmt)
	p.ExpectedReturn = fmt.Sprintf("%.2f%%", expectedRet)
	p.DurationDays = response.NullInt(durDays)
	p.AvailablePool = response.FormatMoney(availPool)

	c.JSON(http.StatusOK, p)
}

// Invest creates a new investment by debiting the user's wallet.
func (h *Handler) Invest(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	var req InvestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin investment transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	// Fetch and validate the product
	var productName, productType, productStatus, currency string
	var minAmount, expectedReturn, availablePool float64
	var maxAmount sql.NullFloat64
	var durationDays sql.NullInt32

	err = tx.QueryRowContext(c,
		`SELECT name, type, status, currency, min_amount, max_amount, expected_return, duration_days, available_pool
		 FROM investment_products WHERE id = $1 FOR UPDATE`,
		req.ProductID,
	).Scan(&productName, &productType, &productStatus, &currency, &minAmount, &maxAmount, &expectedReturn, &durationDays, &availablePool)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "Investment product not found"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get investment product")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if productStatus != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Investment product is not currently available"})
		return
	}

	if req.Amount < minAmount {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Minimum investment amount is %s", response.FormatMoney(minAmount))})
		return
	}

	if maxAmount.Valid && req.Amount > maxAmount.Float64 {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Maximum investment amount is %s", response.FormatMoney(maxAmount.Float64))})
		return
	}

	if req.Amount > availablePool {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Investment amount exceeds available pool"})
		return
	}

	// Get and lock user wallet
	var walletID string
	var available float64
	err = tx.QueryRowContext(c,
		`SELECT id, available_balance FROM wallets WHERE user_id = $1 AND currency = $2 FOR UPDATE`,
		userID, currency,
	).Scan(&walletID, &available)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("No %s wallet found", currency)})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get wallet for investment")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if available < req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrInsufficientBalance.Message})
		return
	}

	// Debit wallet
	newBalance := available - req.Amount
	if _, err = tx.ExecContext(c, `UPDATE wallets SET available_balance = $1 WHERE id = $2`, newBalance, walletID); err != nil {
		log.WithError(err).Error("Failed to debit wallet for investment")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create transaction record
	txnID := uuid.New()
	ref := fmt.Sprintf("INV-%s-%d", txnID.String()[:8], time.Now().UnixMilli())
	if _, err = tx.ExecContext(c,
		`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, currency, reference, description, completed_at)
		 VALUES ($1, $2, $3, 'investment', 'completed', $4, $5, $6, $7, NOW())`,
		txnID, userID, walletID, req.Amount, currency, ref, "Investment in "+productName,
	); err != nil {
		log.WithError(err).Error("Failed to create investment transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create ledger entry
	if _, err = tx.ExecContext(c,
		`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
		 VALUES ($1, $2, $3, 'debit', $4, $5, $6)`,
		uuid.New(), txnID, walletID, req.Amount, newBalance, "Investment in "+productName,
	); err != nil {
		log.WithError(err).Error("Failed to create ledger entry for investment")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create investment record
	investmentID := uuid.New()
	var maturityDate *time.Time
	if durationDays.Valid {
		t := time.Now().AddDate(0, 0, int(durationDays.Int32))
		maturityDate = &t
	}

	if _, err = tx.ExecContext(c,
		`INSERT INTO investments (id, user_id, product_id, wallet_id, amount, currency, expected_return, status, maturity_date)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, 'active', $8)`,
		investmentID, userID, req.ProductID, walletID, req.Amount, currency, expectedReturn, maturityDate,
	); err != nil {
		log.WithError(err).Error("Failed to create investment record")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Update product available pool
	if _, err = tx.ExecContext(c,
		`UPDATE investment_products SET available_pool = available_pool - $1, total_pool = total_pool + $1 WHERE id = $2`,
		req.Amount, req.ProductID,
	); err != nil {
		log.WithError(err).Error("Failed to update investment product pool")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit investment transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	resp := gin.H{
		"investment_id":   investmentID.String(),
		"product_name":    productName,
		"amount":          response.FormatMoney(req.Amount),
		"expected_return": fmt.Sprintf("%.2f%%", expectedReturn),
		"wallet_balance":  response.FormatMoney(newBalance),
		"message":         "Investment created successfully",
	}
	if maturityDate != nil {
		resp["maturity_date"] = maturityDate.Format(time.RFC3339)
	}
	c.JSON(http.StatusCreated, resp)
}

// ListInvestments returns the user's investments with pagination.
func (h *Handler) ListInvestments(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	statusFilter := c.Query("status")
	pg := response.GetPagination(c, 20)

	countQuery := `SELECT COUNT(*) FROM investments WHERE user_id = $1`
	dataQuery := `SELECT i.id, i.product_id, p.name, p.type, i.amount, i.currency, i.expected_return,
				  i.actual_return, i.status, i.maturity_date, i.matured_at, i.created_at
				  FROM investments i JOIN investment_products p ON i.product_id = p.id
				  WHERE i.user_id = $1`
	args := []interface{}{userID}

	if statusFilter != "" {
		countQuery += ` AND status = $2`
		dataQuery += ` AND i.status = $2`
		args = append(args, statusFilter)
	}

	var total int
	if err := h.db.QueryRowContext(c, countQuery, args...).Scan(&total); err != nil {
		log.WithError(err).Error("Failed to count investments")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	dataQuery += fmt.Sprintf(` ORDER BY i.created_at DESC LIMIT %d OFFSET %d`, pg.PageSize, pg.Offset)

	rows, err := h.db.QueryContext(c, dataQuery, args...)
	if err != nil {
		log.WithError(err).Error("Failed to query investments")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var investments []InvestmentResponse
	for rows.Next() {
		var inv InvestmentResponse
		var amount, expectedRet float64
		var actualRet sql.NullFloat64
		var matDate, maturedAt sql.NullTime

		err := rows.Scan(&inv.ID, &inv.ProductID, &inv.ProductName, &inv.ProductType, &amount, &inv.Currency,
			&expectedRet, &actualRet, &inv.Status, &matDate, &maturedAt, &inv.CreatedAt)
		if err != nil {
			log.WithError(err).Error("Failed to scan investment row")
			continue
		}

		inv.Amount = response.FormatMoney(amount)
		inv.ExpectedReturn = fmt.Sprintf("%.2f%%", expectedRet)
		inv.ActualReturn = response.FloatStr(actualRet)
		inv.MaturityDate = response.NullTime(matDate)
		inv.MaturedAt = response.NullTime(maturedAt)

		investments = append(investments, inv)
	}

	response.PagedList(c, "investments", response.EmptySlice(investments), pg, total)
}

// WithdrawInvestment withdraws from a matured or money_market investment.
func (h *Handler) WithdrawInvestment(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	investmentID := c.Param("id")

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin investment withdrawal transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	// Fetch investment with lock
	var invStatus, invCurrency, walletID, productID string
	var invAmount, expectedReturn float64
	var maturityDate sql.NullTime

	err = tx.QueryRowContext(c,
		`SELECT i.status, i.amount, i.currency, i.wallet_id, i.product_id, i.expected_return, i.maturity_date
		 FROM investments i WHERE i.id = $1 AND i.user_id = $2 FOR UPDATE`,
		investmentID, userID,
	).Scan(&invStatus, &invAmount, &invCurrency, &walletID, &productID, &expectedReturn, &maturityDate)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get investment for withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if invStatus != "active" && invStatus != "matured" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Investment cannot be withdrawn", "status": invStatus})
		return
	}

	// Check product type - money_market can withdraw anytime, others must be matured
	var productType string
	err = tx.QueryRowContext(c, `SELECT type FROM investment_products WHERE id = $1`, productID).Scan(&productType)
	if err != nil {
		log.WithError(err).Error("Failed to get product type")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if productType != "money_market" && invStatus == "active" {
		if maturityDate.Valid && time.Now().Before(maturityDate.Time) {
			c.JSON(http.StatusForbidden, gin.H{
				"error":         "Investment has not matured yet",
				"maturity_date": maturityDate.Time.Format(time.RFC3339),
			})
			return
		}
	}

	// Calculate return amount (principal + accrued return)
	returnAmount := invAmount
	if invStatus == "matured" || (maturityDate.Valid && !time.Now().Before(maturityDate.Time)) {
		// Full expected return
		returnAmount = invAmount * (1 + expectedReturn/100)
	}

	// Credit wallet
	var available float64
	err = tx.QueryRowContext(c,
		`SELECT available_balance FROM wallets WHERE id = $1 FOR UPDATE`,
		walletID,
	).Scan(&available)
	if err != nil {
		log.WithError(err).Error("Failed to get wallet for investment withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	newBalance := available + returnAmount
	if _, err = tx.ExecContext(c, `UPDATE wallets SET available_balance = $1 WHERE id = $2`, newBalance, walletID); err != nil {
		log.WithError(err).Error("Failed to credit wallet for investment withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create transaction
	txnID := uuid.New()
	ref := fmt.Sprintf("INV-WDR-%s-%d", txnID.String()[:8], time.Now().UnixMilli())
	if _, err = tx.ExecContext(c,
		`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, currency, reference, description, completed_at)
		 VALUES ($1, $2, $3, 'investment_return', 'completed', $4, $5, $6, $7, NOW())`,
		txnID, userID, walletID, returnAmount, invCurrency, ref, "Investment withdrawal",
	); err != nil {
		log.WithError(err).Error("Failed to create investment withdrawal transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create ledger entry
	if _, err = tx.ExecContext(c,
		`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
		 VALUES ($1, $2, $3, 'credit', $4, $5, $6)`,
		uuid.New(), txnID, walletID, returnAmount, newBalance, "Investment withdrawal",
	); err != nil {
		log.WithError(err).Error("Failed to create ledger entry for investment withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Update investment status
	actualReturn := returnAmount - invAmount
	if _, err = tx.ExecContext(c,
		`UPDATE investments SET status = 'withdrawn', actual_return = $1, updated_at = NOW() WHERE id = $2`,
		actualReturn, investmentID,
	); err != nil {
		log.WithError(err).Error("Failed to update investment status")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit investment withdrawal")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":        "Investment withdrawn successfully",
		"transaction_id": txnID.String(),
		"principal":      response.FormatMoney(invAmount),
		"return":         response.FormatMoney(actualReturn),
		"total_payout":   response.FormatMoney(returnAmount),
		"wallet_balance": response.FormatMoney(newBalance),
	})
}

// ListAllInvestments returns all investments across all users (admin view).
func (h *Handler) ListAllInvestments(c *gin.Context) {
	log := logger.Ctx(c)
	p := response.GetPagination(c, 20)

	var total int
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM investments`).Scan(&total); err != nil {
		log.WithError(err).Warn("Failed to count investments")
	}

	rows, err := h.db.QueryContext(c,
		`SELECT i.id, u.phone, ip.name, ip.type, i.amount, i.currency, i.expected_return,
		        i.status, i.created_at
		 FROM investments i
		 JOIN users u ON i.user_id = u.id
		 JOIN investment_products ip ON i.product_id = ip.id
		 ORDER BY i.created_at DESC LIMIT $1 OFFSET $2`,
		p.PageSize, p.Offset,
	)
	if err != nil {
		log.WithError(err).Error("Failed to list all investments")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type AdminInvestment struct {
		ID             string `json:"id"`
		Phone          string `json:"phone"`
		ProductName    string `json:"product_name"`
		ProductType    string `json:"product_type"`
		Amount         string `json:"amount"`
		Currency       string `json:"currency"`
		ExpectedReturn string `json:"expected_return"`
		Status         string `json:"status"`
		CreatedAt      string `json:"created_at"`
	}

	var investments []AdminInvestment
	for rows.Next() {
		var inv AdminInvestment
		var amount, expectedReturn float64
		if err := rows.Scan(&inv.ID, &inv.Phone, &inv.ProductName, &inv.ProductType,
			&amount, &inv.Currency, &expectedReturn, &inv.Status, &inv.CreatedAt); err != nil {
			continue
		}
		inv.Amount = response.FormatMoney(amount)
		inv.ExpectedReturn = response.FormatMoney(expectedReturn)
		investments = append(investments, inv)
	}

	response.PagedList(c, "investments", response.EmptySlice(investments), p, total)
}
