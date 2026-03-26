package middleware

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"

	"github.com/savingplus/backend/pkg/crypto"
)

// bodyWriter captures the response body
type bodyWriter struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

func (w *bodyWriter) Write(b []byte) (int, error) {
	w.body.Write(b)
	return w.ResponseWriter.Write(b)
}

func AuditLog(db *sql.DB, hmacKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Skip audit for GET requests (read-only)
		if c.Request.Method == http.MethodGet {
			c.Next()
			return
		}

		// Read and restore request body
		var requestBody json.RawMessage
		if c.Request.Body != nil {
			bodyBytes, _ := io.ReadAll(c.Request.Body)
			c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
			// Sanitize sensitive fields before logging
			requestBody = sanitizeBody(bodyBytes)
		}

		// Capture response
		bw := &bodyWriter{body: bytes.NewBufferString(""), ResponseWriter: c.Writer}
		c.Writer = bw

		c.Next()

		// Determine actor
		actorType := "system"
		var actorID *string
		if uid := c.GetString("user_id"); uid != "" {
			actorType = "user"
			actorID = &uid
		} else if aid := c.GetString("admin_id"); aid != "" {
			actorType = "admin"
			actorID = &aid
		}

		action := c.Request.Method + " " + c.FullPath()

		entry := map[string]interface{}{
			"actor_type":  actorType,
			"action":      action,
			"ip":          c.ClientIP(),
			"user_agent":  c.Request.UserAgent(),
			"status_code": c.Writer.Status(),
		}

		// HMAC signature
		entryJSON, _ := json.Marshal(entry)
		signature := ""
		if hmacKey != "" {
			signature = crypto.HMACSign(string(entryJSON), hmacKey)
		}

		_, err := db.ExecContext(c,
			`INSERT INTO audit_logs (id, actor_type, actor_id, action, ip_address, user_agent, request_body, response_status, hmac_signature)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
			uuid.New(), actorType, actorID, action, c.ClientIP(), c.Request.UserAgent(),
			requestBody, c.Writer.Status(), signature,
		)
		if err != nil {
			log.WithError(err).Error("Failed to write audit log")
		}
	}
}

func sanitizeBody(body []byte) json.RawMessage {
	var data map[string]interface{}
	if err := json.Unmarshal(body, &data); err != nil {
		return json.RawMessage("{}")
	}

	sensitiveFields := map[string]bool{
		"password": true, "pin": true, "otp": true, "otp_code": true,
		"current_password": true, "new_password": true, "secret": true,
	}

	for key := range data {
		if sensitiveFields[key] {
			data[key] = "[REDACTED]"
		}
	}

	sanitized, _ := json.Marshal(data)
	return sanitized
}
