package response

import (
	"database/sql"
	"math"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// Pagination holds parsed pagination parameters.
type Pagination struct {
	Page     int
	PageSize int
	Offset   int
}

// GetPagination extracts pagination params from query string.
func GetPagination(c *gin.Context, defaultSize int) Pagination {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	if page < 1 {
		page = 1
	}
	if defaultSize < 1 || defaultSize > 100 {
		defaultSize = 20
	}
	return Pagination{
		Page:     page,
		PageSize: defaultSize,
		Offset:   (page - 1) * defaultSize,
	}
}

// TotalPages calculates the total number of pages.
func TotalPages(total, pageSize int) int {
	if pageSize <= 0 {
		return 0
	}
	return int(math.Ceil(float64(total) / float64(pageSize)))
}

// PagedList sends a standard paginated JSON response.
func PagedList(c *gin.Context, key string, data interface{}, p Pagination, total int) {
	c.JSON(http.StatusOK, gin.H{
		key:            data,
		"total":        total,
		"page":         p.Page,
		"page_size":    p.PageSize,
		"total_pages":  TotalPages(total, p.PageSize),
	})
}

// Error sends a standard error JSON response.
func Error(c *gin.Context, status int, errMsg string) {
	c.JSON(status, gin.H{"error": errMsg})
}

// ErrorWithDetail sends an error with additional detail.
func ErrorWithDetail(c *gin.Context, status int, errMsg, detail string) {
	c.JSON(status, gin.H{"error": errMsg, "detail": detail})
}

// InternalError sends a 500 error with generic message.
func InternalError(c *gin.Context) {
	c.JSON(http.StatusInternalServerError, gin.H{"error": "internal_error"})
}

// Success sends a standard success JSON response.
func Success(c *gin.Context, message string) {
	c.JSON(http.StatusOK, gin.H{"message": message})
}

// NullStr converts sql.NullString to *string.
func NullStr(ns sql.NullString) *string {
	if !ns.Valid {
		return nil
	}
	return &ns.String
}

// NullInt converts sql.NullInt32 to *int.
func NullInt(ni sql.NullInt32) *int {
	if !ni.Valid {
		return nil
	}
	v := int(ni.Int32)
	return &v
}

// NullFloat converts sql.NullFloat64 to *float64.
func NullFloat(nf sql.NullFloat64) *float64 {
	if !nf.Valid {
		return nil
	}
	return &nf.Float64
}

// NullTime converts sql.NullTime to *string (RFC3339).
func NullTime(nt sql.NullTime) *string {
	if !nt.Valid {
		return nil
	}
	s := nt.Time.Format("2006-01-02T15:04:05Z07:00")
	return &s
}

// FormatMoney formats a float64 as a 2-decimal string.
func FormatMoney(amount float64) string {
	return strconv.FormatFloat(amount, 'f', 2, 64)
}

// FloatStr converts a NullFloat64 to a formatted *string.
func FloatStr(nf sql.NullFloat64) *string {
	if !nf.Valid {
		return nil
	}
	s := FormatMoney(nf.Float64)
	return &s
}

// EmptySlice returns a non-nil empty slice if input is nil.
func EmptySlice[T any](s []T) []T {
	if s == nil {
		return []T{}
	}
	return s
}
