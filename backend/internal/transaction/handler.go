package transaction

import (
	"database/sql"
	"math"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	log "github.com/sirupsen/logrus"

	apperr "github.com/savingplus/backend/internal/errors"
)

type Handler struct {
	db *sql.DB
}

func NewHandler(db *sql.DB) *Handler {
	return &Handler{db: db}
}

type TransactionResponse struct {
	ID          string  `json:"id"`
	Type        string  `json:"type"`
	Status      string  `json:"status"`
	Amount      string  `json:"amount"`
	Fee         string  `json:"fee"`
	Currency    string  `json:"currency"`
	Reference   string  `json:"reference"`
	Description *string `json:"description,omitempty"`
	CreatedAt   string  `json:"created_at"`
	CompletedAt *string `json:"completed_at,omitempty"`
}

type ListResponse struct {
	Transactions []TransactionResponse `json:"transactions"`
	Total        int                   `json:"total"`
	Page         int                   `json:"page"`
	PageSize     int                   `json:"page_size"`
	TotalPages   int                   `json:"total_pages"`
}

func (h *Handler) List(c *gin.Context) {
	userID := c.GetString("user_id")

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	txnType := c.Query("type")
	status := c.Query("status")

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	// Build query
	query := `SELECT id, type, status, amount, fee, currency, reference, description, created_at, completed_at
			  FROM transactions WHERE user_id = $1`
	countQuery := `SELECT COUNT(*) FROM transactions WHERE user_id = $1`
	args := []interface{}{userID}
	countArgs := []interface{}{userID}
	argIdx := 2

	if txnType != "" {
		query += ` AND type = $` + strconv.Itoa(argIdx)
		countQuery += ` AND type = $` + strconv.Itoa(argIdx)
		args = append(args, txnType)
		countArgs = append(countArgs, txnType)
		argIdx++
	}
	if status != "" {
		query += ` AND status = $` + strconv.Itoa(argIdx)
		countQuery += ` AND status = $` + strconv.Itoa(argIdx)
		args = append(args, status)
		countArgs = append(countArgs, status)
		argIdx++
	}

	query += ` ORDER BY created_at DESC LIMIT $` + strconv.Itoa(argIdx) + ` OFFSET $` + strconv.Itoa(argIdx+1)
	args = append(args, pageSize, offset)

	// Count total
	var total int
	if err := h.db.QueryRowContext(c, countQuery, countArgs...).Scan(&total); err != nil {
		log.WithError(err).Error("Failed to count transactions")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Fetch page
	rows, err := h.db.QueryContext(c, query, args...)
	if err != nil {
		log.WithError(err).Error("Failed to query transactions")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var txns []TransactionResponse
	for rows.Next() {
		var t TransactionResponse
		var desc sql.NullString
		var completedAt sql.NullString
		var amount, fee float64

		if err := rows.Scan(&t.ID, &t.Type, &t.Status, &amount, &fee, &t.Currency, &t.Reference, &desc, &t.CreatedAt, &completedAt); err != nil {
			log.WithError(err).Error("Failed to scan transaction")
			continue
		}

		t.Amount = strconv.FormatFloat(amount, 'f', 2, 64)
		t.Fee = strconv.FormatFloat(fee, 'f', 2, 64)
		if desc.Valid {
			t.Description = &desc.String
		}
		if completedAt.Valid {
			t.CompletedAt = &completedAt.String
		}
		txns = append(txns, t)
	}

	if txns == nil {
		txns = []TransactionResponse{}
	}

	c.JSON(http.StatusOK, ListResponse{
		Transactions: txns,
		Total:        total,
		Page:         page,
		PageSize:     pageSize,
		TotalPages:   int(math.Ceil(float64(total) / float64(pageSize))),
	})
}

func (h *Handler) GetByID(c *gin.Context) {
	userID := c.GetString("user_id")
	txnID := c.Param("id")

	var t TransactionResponse
	var desc sql.NullString
	var completedAt sql.NullString
	var amount, fee float64

	err := h.db.QueryRowContext(c,
		`SELECT id, type, status, amount, fee, currency, reference, description, created_at, completed_at
		 FROM transactions WHERE id = $1 AND user_id = $2`,
		txnID, userID,
	).Scan(&t.ID, &t.Type, &t.Status, &amount, &fee, &t.Currency, &t.Reference, &desc, &t.CreatedAt, &completedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	t.Amount = strconv.FormatFloat(amount, 'f', 2, 64)
	t.Fee = strconv.FormatFloat(fee, 'f', 2, 64)
	if desc.Valid {
		t.Description = &desc.String
	}
	if completedAt.Valid {
		t.CompletedAt = &completedAt.String
	}

	c.JSON(http.StatusOK, t)
}
