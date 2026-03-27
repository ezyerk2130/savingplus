package content

import (
	"database/sql"
	"fmt"
	"net/http"

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

type ArticleResponse struct {
	ID          string  `json:"id"`
	Title       string  `json:"title"`
	Body        string  `json:"body"`
	Category    string  `json:"category"`
	ImageURL    *string `json:"image_url,omitempty"`
	ReadTimeMin int     `json:"read_time_min"`
	CreatedAt   string  `json:"created_at"`
}

// ListArticles returns published articles with optional category filter and language support.
func (h *Handler) ListArticles(c *gin.Context) {
	log := logger.Ctx(c)
	category := c.DefaultQuery("category", "")
	lang := c.DefaultQuery("language", "sw")
	pg := response.GetPagination(c, 20)

	if lang != "en" && lang != "sw" {
		lang = "sw"
	}

	countQuery := `SELECT COUNT(*) FROM content_articles WHERE published = TRUE`
	args := []interface{}{}
	argIdx := 1

	if category != "" {
		countQuery += ` AND category = $1`
		args = append(args, category)
		argIdx = 2
	}

	var total int
	if err := h.db.QueryRowContext(c, countQuery, args...).Scan(&total); err != nil {
		log.WithError(err).Error("Failed to count articles")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Build data query with language-aware title/body selection
	// For Swahili: use title_sw/body_sw if available, fall back to title/body (English)
	titleExpr := "title"
	bodyExpr := "body"
	if lang == "sw" {
		titleExpr = "COALESCE(NULLIF(title_sw, ''), title)"
		bodyExpr = "COALESCE(NULLIF(body_sw, ''), body)"
	}

	dataQuery := `SELECT id, ` + titleExpr + `, ` + bodyExpr + `, category, image_url, read_time_min, created_at
				  FROM content_articles WHERE published = TRUE`

	if category != "" {
		dataQuery += ` AND category = $1`
	}

	dataQuery += ` ORDER BY sort_order ASC, created_at DESC`
	dataQuery += ` LIMIT $` + itoa(argIdx) + ` OFFSET $` + itoa(argIdx+1)

	dataArgs := append(args, pg.PageSize, pg.Offset)
	rows, err := h.db.QueryContext(c, dataQuery, dataArgs...)
	if err != nil {
		log.WithError(err).Error("Failed to query articles")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var articles []ArticleResponse
	for rows.Next() {
		var a ArticleResponse
		var imageURL sql.NullString

		err := rows.Scan(&a.ID, &a.Title, &a.Body, &a.Category, &imageURL, &a.ReadTimeMin, &a.CreatedAt)
		if err != nil {
			log.WithError(err).Error("Failed to scan article row")
			continue
		}

		a.ImageURL = response.NullStr(imageURL)
		articles = append(articles, a)
	}

	response.PagedList(c, "articles", response.EmptySlice(articles), pg, total)
}

// GetArticle returns a single article by ID with language support.
func (h *Handler) GetArticle(c *gin.Context) {
	log := logger.Ctx(c)
	articleID := c.Param("id")
	lang := c.DefaultQuery("language", "sw")

	if lang != "en" && lang != "sw" {
		lang = "sw"
	}

	titleExpr := "title"
	bodyExpr := "body"
	if lang == "sw" {
		titleExpr = "COALESCE(NULLIF(title_sw, ''), title)"
		bodyExpr = "COALESCE(NULLIF(body_sw, ''), body)"
	}

	query := `SELECT id, ` + titleExpr + `, ` + bodyExpr + `, category, image_url, read_time_min, created_at
			  FROM content_articles WHERE id = $1 AND published = TRUE`

	var a ArticleResponse
	var imageURL sql.NullString

	err := h.db.QueryRowContext(c, query, articleID).Scan(
		&a.ID, &a.Title, &a.Body, &a.Category, &imageURL, &a.ReadTimeMin, &a.CreatedAt,
	)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).WithField("article_id", articleID).Error("Failed to get article")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	a.ImageURL = response.NullStr(imageURL)
	c.JSON(http.StatusOK, a)
}

// itoa is a small helper to convert int to string for query building.
func itoa(i int) string {
	return fmt.Sprintf("%d", i)
}
