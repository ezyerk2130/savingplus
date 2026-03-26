package savings

import (
	"database/sql"
	"math"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"

	apperr "github.com/savingplus/backend/internal/errors"
)

type Handler struct {
	db *sql.DB
}

func NewHandler(db *sql.DB) *Handler {
	return &Handler{db: db}
}

type CreatePlanRequest struct {
	Name              string   `json:"name" binding:"required,min=1,max=100"`
	Type              string   `json:"type" binding:"required,oneof=flexible locked target"`
	TargetAmount      *float64 `json:"target_amount,omitempty"`
	LockDurationDays  *int     `json:"lock_duration_days,omitempty"`
	AutoDebit         bool     `json:"auto_debit"`
	AutoDebitAmount   *float64 `json:"auto_debit_amount,omitempty"`
	AutoDebitFrequency *string `json:"auto_debit_frequency,omitempty"`
}

type PlanResponse struct {
	ID                string   `json:"id"`
	Name              string   `json:"name"`
	Type              string   `json:"type"`
	Status            string   `json:"status"`
	TargetAmount      *string  `json:"target_amount,omitempty"`
	CurrentAmount     string   `json:"current_amount"`
	InterestRate      string   `json:"interest_rate"`
	LockDurationDays  *int     `json:"lock_duration_days,omitempty"`
	MaturityDate      *string  `json:"maturity_date,omitempty"`
	AutoDebit         bool     `json:"auto_debit"`
	AutoDebitAmount   *string  `json:"auto_debit_amount,omitempty"`
	AutoDebitFrequency *string `json:"auto_debit_frequency,omitempty"`
	CreatedAt         string   `json:"created_at"`
}

func (h *Handler) CreatePlan(c *gin.Context) {
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

	// Get wallet
	var walletID string
	err := h.db.QueryRowContext(c, `SELECT id FROM wallets WHERE user_id = $1`, userID).Scan(&walletID)
	if err != nil {
		log.WithError(err).Error("Failed to get wallet")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
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

	_, err = h.db.ExecContext(c,
		`INSERT INTO savings_plans (id, user_id, wallet_id, name, type, target_amount, interest_rate,
		 lock_duration_days, maturity_date, auto_debit, auto_debit_amount, auto_debit_frequency)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
		planID, userID, walletID, req.Name, req.Type, req.TargetAmount, interestRate,
		req.LockDurationDays, maturityDate, req.AutoDebit, req.AutoDebitAmount, req.AutoDebitFrequency,
	)
	if err != nil {
		log.WithError(err).Error("Failed to create savings plan")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"plan_id":       planID.String(),
		"name":          req.Name,
		"type":          req.Type,
		"interest_rate": strconv.FormatFloat(interestRate*100, 'f', 2, 64) + "%",
		"message":       "Savings plan created successfully",
	})
}

func (h *Handler) ListPlans(c *gin.Context) {
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
		log.WithError(err).Error("Failed to query savings plans")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var plans []PlanResponse
	for rows.Next() {
		var p PlanResponse
		var targetAmt, currentAmt, rate float64
		var targetAmtNull sql.NullFloat64
		var lockDays sql.NullInt32
		var matDate sql.NullTime
		var autoAmt sql.NullFloat64
		var autoFreq sql.NullString

		err := rows.Scan(&p.ID, &p.Name, &p.Type, &p.Status, &targetAmtNull, &currentAmt, &rate,
			&lockDays, &matDate, &p.AutoDebit, &autoAmt, &autoFreq, &p.CreatedAt)
		if err != nil {
			log.WithError(err).Error("Failed to scan savings plan")
			continue
		}

		p.CurrentAmount = strconv.FormatFloat(currentAmt, 'f', 2, 64)
		p.InterestRate = strconv.FormatFloat(rate*100, 'f', 2, 64) + "%"

		if targetAmtNull.Valid {
			s := strconv.FormatFloat(targetAmt, 'f', 2, 64)
			p.TargetAmount = &s
		}
		if lockDays.Valid {
			d := int(lockDays.Int32)
			p.LockDurationDays = &d
		}
		if matDate.Valid {
			s := matDate.Time.Format(time.RFC3339)
			p.MaturityDate = &s
		}
		if autoAmt.Valid {
			s := strconv.FormatFloat(autoAmt.Float64, 'f', 2, 64)
			p.AutoDebitAmount = &s
		}
		if autoFreq.Valid {
			p.AutoDebitFrequency = &autoFreq.String
		}

		plans = append(plans, p)
	}

	if plans == nil {
		plans = []PlanResponse{}
	}

	c.JSON(http.StatusOK, gin.H{"plans": plans, "total": len(plans)})
}

func (h *Handler) GetPlan(c *gin.Context) {
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
		log.WithError(err).Error("Failed to get savings plan")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	p.CurrentAmount = strconv.FormatFloat(currentAmt, 'f', 2, 64)
	p.InterestRate = strconv.FormatFloat(rate*100, 'f', 2, 64) + "%"

	if targetAmtNull.Valid {
		s := strconv.FormatFloat(targetAmtNull.Float64, 'f', 2, 64)
		p.TargetAmount = &s
	}
	if lockDays.Valid {
		d := int(lockDays.Int32)
		p.LockDurationDays = &d
	}
	if matDate.Valid {
		s := matDate.Time.Format(time.RFC3339)
		p.MaturityDate = &s
	}
	if autoAmt.Valid {
		s := strconv.FormatFloat(autoAmt.Float64, 'f', 2, 64)
		p.AutoDebitAmount = &s
	}
	if autoFreq.Valid {
		p.AutoDebitFrequency = &autoFreq.String
	}

	c.JSON(http.StatusOK, p)
}

// unused guard
var _ = math.Ceil
