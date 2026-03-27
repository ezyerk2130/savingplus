package content

import (
	"database/sql"
	"fmt"
	"net/http"

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

// CreateArticle creates a new content article (admin).
func (h *Handler) CreateArticle(c *gin.Context) {
	log := logger.Ctx(c)

	var req struct {
		Title       string `json:"title" binding:"required"`
		TitleSW     string `json:"title_sw"`
		Body        string `json:"body" binding:"required"`
		BodySW      string `json:"body_sw"`
		Category    string `json:"category" binding:"required,oneof=saving investing budgeting insurance credit general"`
		ReadTimeMin int    `json:"read_time_min"`
		Published   bool   `json:"published"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad_request", "detail": err.Error()})
		return
	}

	if req.ReadTimeMin < 1 {
		req.ReadTimeMin = 3
	}

	articleID := uuid.New()
	_, err := h.db.ExecContext(c,
		`INSERT INTO content_articles (id, title, title_sw, body, body_sw, category, read_time_min, published)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		articleID, req.Title, req.TitleSW, req.Body, req.BodySW, req.Category, req.ReadTimeMin, req.Published,
	)
	if err != nil {
		log.WithError(err).Error("Failed to create article")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"article_id": articleID.String(), "message": "Article created"})
}

// TogglePublish toggles the published status of an article.
func (h *Handler) TogglePublish(c *gin.Context) {
	log := logger.Ctx(c)
	articleID := c.Param("id")

	var req struct {
		Published bool `json:"published"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad_request", "detail": err.Error()})
		return
	}

	result, err := h.db.ExecContext(c,
		`UPDATE content_articles SET published = $1 WHERE id = $2`,
		req.Published, articleID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to toggle publish")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Article not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Article updated", "published": req.Published})
}
