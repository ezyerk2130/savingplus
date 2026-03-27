package insurance

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
	ID               string `json:"id"`
	Name             string `json:"name"`
	Description      *string `json:"description,omitempty"`
	Type             string `json:"type"`
	Provider         string `json:"provider"`
	PremiumAmount    string `json:"premium_amount"`
	PremiumFrequency string `json:"premium_frequency"`
	CoverageAmount   string `json:"coverage_amount"`
	CoverageDetails  string `json:"coverage_details"`
	MinAge           int    `json:"min_age"`
	MaxAge           int    `json:"max_age"`
	Status           string `json:"status"`
	CreatedAt        string `json:"created_at"`
}

type PolicyResponse struct {
	ID              string  `json:"id"`
	ProductID       string  `json:"product_id"`
	ProductName     string  `json:"product_name"`
	ProductType     string  `json:"product_type"`
	PolicyNumber    string  `json:"policy_number"`
	Status          string  `json:"status"`
	CoverageStart   string  `json:"coverage_start"`
	CoverageEnd     string  `json:"coverage_end"`
	PremiumPaid     string  `json:"premium_paid"`
	AutoRenew       bool    `json:"auto_renew"`
	Beneficiary     *string `json:"beneficiary,omitempty"`
	CreatedAt       string  `json:"created_at"`
}

type SubscribeRequest struct {
	ProductID        string `json:"product_id" binding:"required"`
	BeneficiaryName  string `json:"beneficiary_name" binding:"required,min=1,max=100"`
	BeneficiaryPhone string `json:"beneficiary_phone" binding:"required"`
}

// ListProducts returns all active insurance products, optionally filtered by type.
func (h *Handler) ListProducts(c *gin.Context) {
	log := logger.Ctx(c)
	typeFilter := c.Query("type")

	query := `SELECT id, name, description, type, provider, premium_amount, premium_frequency,
			  coverage_amount, coverage_details::text, min_age, max_age, status, created_at
			  FROM insurance_products WHERE status = 'active'`
	args := []interface{}{}

	if typeFilter != "" {
		query += ` AND type = $1`
		args = append(args, typeFilter)
	}
	query += ` ORDER BY created_at DESC`

	rows, err := h.db.QueryContext(c, query, args...)
	if err != nil {
		log.WithError(err).Error("Failed to query insurance products")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var products []ProductResponse
	for rows.Next() {
		var p ProductResponse
		var desc sql.NullString
		var premiumAmt, coverageAmt float64

		err := rows.Scan(&p.ID, &p.Name, &desc, &p.Type, &p.Provider, &premiumAmt, &p.PremiumFrequency,
			&coverageAmt, &p.CoverageDetails, &p.MinAge, &p.MaxAge, &p.Status, &p.CreatedAt)
		if err != nil {
			log.WithError(err).Error("Failed to scan insurance product row")
			continue
		}

		p.Description = response.NullStr(desc)
		p.PremiumAmount = response.FormatMoney(premiumAmt)
		p.CoverageAmount = response.FormatMoney(coverageAmt)

		products = append(products, p)
	}

	c.JSON(http.StatusOK, gin.H{"products": response.EmptySlice(products), "total": len(response.EmptySlice(products))})
}

// GetProduct returns a single insurance product by ID.
func (h *Handler) GetProduct(c *gin.Context) {
	log := logger.Ctx(c)
	productID := c.Param("id")

	var p ProductResponse
	var desc sql.NullString
	var premiumAmt, coverageAmt float64

	err := h.db.QueryRowContext(c,
		`SELECT id, name, description, type, provider, premium_amount, premium_frequency,
		 coverage_amount, coverage_details::text, min_age, max_age, status, created_at
		 FROM insurance_products WHERE id = $1`,
		productID,
	).Scan(&p.ID, &p.Name, &desc, &p.Type, &p.Provider, &premiumAmt, &p.PremiumFrequency,
		&coverageAmt, &p.CoverageDetails, &p.MinAge, &p.MaxAge, &p.Status, &p.CreatedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).WithField("product_id", productID).Error("Failed to get insurance product")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	p.Description = response.NullStr(desc)
	p.PremiumAmount = response.FormatMoney(premiumAmt)
	p.CoverageAmount = response.FormatMoney(coverageAmt)

	c.JSON(http.StatusOK, p)
}

// Subscribe creates a new insurance policy by debiting the first premium from wallet.
func (h *Handler) Subscribe(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	var req SubscribeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin subscribe transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	// Fetch product details
	var productName, productStatus, premiumFrequency string
	var premiumAmount float64
	err = tx.QueryRowContext(c,
		`SELECT name, status, premium_amount, premium_frequency FROM insurance_products WHERE id = $1`,
		req.ProductID,
	).Scan(&productName, &productStatus, &premiumAmount, &premiumFrequency)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "Insurance product not found"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get insurance product")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if productStatus != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Insurance product is not currently available"})
		return
	}

	// Calculate coverage end based on premium frequency
	now := time.Now()
	coverageStart := now
	var coverageEnd time.Time
	switch premiumFrequency {
	case "daily":
		coverageEnd = coverageStart.AddDate(0, 0, 1)
	case "weekly":
		coverageEnd = coverageStart.AddDate(0, 0, 7)
	case "monthly":
		coverageEnd = coverageStart.AddDate(0, 1, 0)
	case "annually":
		coverageEnd = coverageStart.AddDate(1, 0, 0)
	default:
		coverageEnd = coverageStart.AddDate(0, 1, 0)
	}

	// Get and lock user wallet (TZS default)
	var walletID string
	var available float64
	err = tx.QueryRowContext(c,
		`SELECT id, available_balance FROM wallets WHERE user_id = $1 AND currency = 'TZS' FOR UPDATE`,
		userID,
	).Scan(&walletID, &available)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No TZS wallet found"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get wallet for insurance subscription")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if available < premiumAmount {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrInsufficientBalance.Message})
		return
	}

	// Debit wallet
	newBalance := available - premiumAmount
	if _, err = tx.ExecContext(c, `UPDATE wallets SET available_balance = $1 WHERE id = $2`, newBalance, walletID); err != nil {
		log.WithError(err).Error("Failed to debit wallet for insurance premium")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create transaction
	txnID := uuid.New()
	ref := fmt.Sprintf("INS-%s-%d", txnID.String()[:8], time.Now().UnixMilli())
	if _, err = tx.ExecContext(c,
		`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, currency, reference, description, completed_at)
		 VALUES ($1, $2, $3, 'insurance_premium', 'completed', $4, 'TZS', $5, $6, NOW())`,
		txnID, userID, walletID, premiumAmount, ref, "Insurance premium for "+productName,
	); err != nil {
		log.WithError(err).Error("Failed to create insurance premium transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create ledger entry
	if _, err = tx.ExecContext(c,
		`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
		 VALUES ($1, $2, $3, 'debit', $4, $5, $6)`,
		uuid.New(), txnID, walletID, premiumAmount, newBalance, "Insurance premium payment",
	); err != nil {
		log.WithError(err).Error("Failed to create ledger entry for insurance premium")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Generate policy number
	policyNumber := fmt.Sprintf("POL-%s-%d", uuid.New().String()[:8], time.Now().UnixMilli())

	// Build beneficiary JSON
	beneficiaryJSON := fmt.Sprintf(`{"name": "%s", "phone": "%s"}`, req.BeneficiaryName, req.BeneficiaryPhone)

	// Create insurance policy
	policyID := uuid.New()
	if _, err = tx.ExecContext(c,
		`INSERT INTO insurance_policies (id, user_id, product_id, policy_number, status, coverage_start, coverage_end, premium_paid, beneficiary)
		 VALUES ($1, $2, $3, $4, 'active', $5, $6, $7, $8::jsonb)`,
		policyID, userID, req.ProductID, policyNumber,
		coverageStart.Format("2006-01-02"), coverageEnd.Format("2006-01-02"),
		premiumAmount, beneficiaryJSON,
	); err != nil {
		log.WithError(err).Error("Failed to create insurance policy")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit insurance subscription")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"policy_id":      policyID.String(),
		"policy_number":  policyNumber,
		"product_name":   productName,
		"premium_paid":   response.FormatMoney(premiumAmount),
		"coverage_start": coverageStart.Format("2006-01-02"),
		"coverage_end":   coverageEnd.Format("2006-01-02"),
		"wallet_balance": response.FormatMoney(newBalance),
		"message":        "Insurance policy created successfully",
	})
}

// ListPolicies returns the user's insurance policies with product info.
func (h *Handler) ListPolicies(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	rows, err := h.db.QueryContext(c,
		`SELECT ip.id, ip.product_id, p.name, p.type, ip.policy_number, ip.status,
		 ip.coverage_start, ip.coverage_end, ip.premium_paid, ip.auto_renew, ip.beneficiary::text, ip.created_at
		 FROM insurance_policies ip
		 JOIN insurance_products p ON ip.product_id = p.id
		 WHERE ip.user_id = $1
		 ORDER BY ip.created_at DESC`,
		userID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query insurance policies")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var policies []PolicyResponse
	for rows.Next() {
		var p PolicyResponse
		var premiumPaid float64
		var beneficiary sql.NullString

		err := rows.Scan(&p.ID, &p.ProductID, &p.ProductName, &p.ProductType, &p.PolicyNumber,
			&p.Status, &p.CoverageStart, &p.CoverageEnd, &premiumPaid, &p.AutoRenew, &beneficiary, &p.CreatedAt)
		if err != nil {
			log.WithError(err).Error("Failed to scan policy row")
			continue
		}

		p.PremiumPaid = response.FormatMoney(premiumPaid)
		p.Beneficiary = response.NullStr(beneficiary)

		policies = append(policies, p)
	}

	c.JSON(http.StatusOK, gin.H{"policies": response.EmptySlice(policies), "total": len(response.EmptySlice(policies))})
}

// CancelPolicy cancels an active insurance policy.
func (h *Handler) CancelPolicy(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	policyID := c.Param("id")

	// Verify policy belongs to user
	var policyStatus string
	err := h.db.QueryRowContext(c,
		`SELECT status FROM insurance_policies WHERE id = $1 AND user_id = $2`,
		policyID, userID,
	).Scan(&policyStatus)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).WithField("policy_id", policyID).Error("Failed to get insurance policy")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if policyStatus != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Only active policies can be cancelled", "status": policyStatus})
		return
	}

	// Cancel the policy
	if _, err = h.db.ExecContext(c,
		`UPDATE insurance_policies SET status = 'cancelled' WHERE id = $1`,
		policyID,
	); err != nil {
		log.WithError(err).Error("Failed to cancel insurance policy")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Insurance policy cancelled successfully"})
}
