package transaction

import (
	"database/sql"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

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
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	p := response.GetPagination(c, 20)
	txnType := c.Query("type")
	status := c.Query("status")

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
	args = append(args, p.PageSize, p.Offset)

	// Count total
	var total int
	if err := h.db.QueryRowContext(c, countQuery, countArgs...).Scan(&total); err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to count transactions")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Fetch page
	rows, err := h.db.QueryContext(c, query, args...)
	if err != nil {
		log.WithError(err).WithField("user_id", userID).Error("Failed to query transactions")
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
			log.WithError(err).WithField("user_id", userID).Error("Failed to scan transaction row")
			c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
			return
		}

		t.Amount = response.FormatMoney(amount)
		t.Fee = response.FormatMoney(fee)
		t.Description = response.NullStr(desc)
		t.CompletedAt = response.NullStr(completedAt)
		txns = append(txns, t)
	}

	response.PagedList(c, "transactions", response.EmptySlice(txns), p, total)
}

func (h *Handler) GetByID(c *gin.Context) {
	log := logger.Ctx(c)
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
		log.WithError(err).WithField("user_id", userID).Error("Failed to get transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	t.Amount = response.FormatMoney(amount)
	t.Fee = response.FormatMoney(fee)
	t.Description = response.NullStr(desc)
	t.CompletedAt = response.NullStr(completedAt)

	c.JSON(http.StatusOK, t)
}
