package notification

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/pkg/config"
)

type Handler struct {
	db  *sql.DB
	cfg *config.Config
}

func NewHandler(db *sql.DB, cfg *config.Config) *Handler {
	return &Handler{db: db, cfg: cfg}
}

type NotificationResponse struct {
	ID        string `json:"id"`
	Type      string `json:"type"`
	Title     string `json:"title"`
	Message   string `json:"message"`
	Read      bool   `json:"read"`
	CreatedAt string `json:"created_at"`
}

func (h *Handler) ListNotifications(c *gin.Context) {
	userID := c.GetString("user_id")

	rows, err := h.db.QueryContext(c,
		`SELECT id, type, COALESCE(title, ''), message, read, created_at
		 FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`,
		userID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query notifications")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var notifs []NotificationResponse
	for rows.Next() {
		var n NotificationResponse
		if err := rows.Scan(&n.ID, &n.Type, &n.Title, &n.Message, &n.Read, &n.CreatedAt); err != nil {
			continue
		}
		notifs = append(notifs, n)
	}

	if notifs == nil {
		notifs = []NotificationResponse{}
	}

	// Count unread
	var unread int
	h.db.QueryRowContext(c, `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND read = FALSE`, userID).Scan(&unread)

	c.JSON(http.StatusOK, gin.H{
		"notifications": notifs,
		"unread_count":  unread,
	})
}

func (h *Handler) MarkRead(c *gin.Context) {
	userID := c.GetString("user_id")
	notifID := c.Param("id")

	result, err := h.db.ExecContext(c,
		`UPDATE notifications SET read = TRUE WHERE id = $1 AND user_id = $2`,
		notifID, userID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to mark notification read")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notification marked as read"})
}

func (h *Handler) MarkAllRead(c *gin.Context) {
	userID := c.GetString("user_id")

	_, err := h.db.ExecContext(c,
		`UPDATE notifications SET read = TRUE WHERE user_id = $1 AND read = FALSE`,
		userID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to mark all notifications read")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "All notifications marked as read"})
}

// CreateNotification is a helper to create notifications from other packages
func CreateNotification(db *sql.DB, userID, notifType, title, message string) error {
	_, err := db.Exec(
		`INSERT INTO notifications (id, user_id, type, title, message) VALUES ($1, $2, $3, $4, $5)`,
		uuid.New(), userID, notifType, title, message,
	)
	return err
}

// SendSMS sends an SMS via Africa's Talking (placeholder)
func SendSMS(cfg *config.Config, phone, message string) error {
	log.WithFields(log.Fields{
		"phone":   phone,
		"message": message,
	}).Info("[SMS] Would send SMS in production via Africa's Talking")
	return nil
}

// SendEmail sends an email via SendGrid (placeholder)
func SendEmail(cfg *config.Config, to, subject, body string) error {
	log.WithFields(log.Fields{
		"to":      to,
		"subject": subject,
	}).Info("[EMAIL] Would send email in production via SendGrid")
	return nil
}
