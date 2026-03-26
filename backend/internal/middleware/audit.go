package middleware

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/savingplus/backend/pkg/crypto"
	"github.com/savingplus/backend/pkg/logger"
)

type bodyWriter struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

func (w *bodyWriter) Write(b []byte) (int, error) {
	if _, err := w.body.Write(b); err != nil {
		logger.Ctx(&gin.Context{}).WithError(err).Warn("Failed to capture response body for audit")
	}
	return w.ResponseWriter.Write(b)
}

func AuditLog(db *sql.DB, hmacKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Method == http.MethodGet {
			c.Next()
			return
		}

		var requestBody json.RawMessage
		if c.Request.Body != nil {
			bodyBytes, err := io.ReadAll(c.Request.Body)
			if err != nil {
				logger.Ctx(c).WithError(err).Warn("Failed to read request body for audit")
			} else {
				c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
				requestBody = sanitizeBody(bodyBytes)
			}
		}

		bw := &bodyWriter{body: bytes.NewBufferString(""), ResponseWriter: c.Writer}
		c.Writer = bw

		c.Next()

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
		device := logger.DeviceName(c.Request.UserAgent())

		entry := map[string]interface{}{
			"actor_type":  actorType,
			"action":      action,
			"ip":          c.ClientIP(),
			"user_agent":  c.Request.UserAgent(),
			"device":      device,
			"status_code": c.Writer.Status(),
		}

		entryJSON, err := json.Marshal(entry)
		if err != nil {
			logger.Ctx(c).WithError(err).Warn("Failed to marshal audit entry for HMAC")
		}

		signature := ""
		if hmacKey != "" && err == nil {
			signature = crypto.HMACSign(string(entryJSON), hmacKey)
		}

		metadataJSON, _ := json.Marshal(map[string]string{"device": device})

		_, dbErr := db.ExecContext(c,
			`INSERT INTO audit_logs (id, actor_type, actor_id, action, ip_address, user_agent, request_body, response_status, hmac_signature, metadata)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
			uuid.New(), actorType, actorID, action, c.ClientIP(), c.Request.UserAgent(),
			requestBody, c.Writer.Status(), signature,
			json.RawMessage(metadataJSON),
		)
		if dbErr != nil {
			logger.Ctx(c).WithError(dbErr).WithField("action", action).Error("Failed to write audit log - COMPLIANCE RISK")
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
		"new_pin": true, "mfa_code": true, "refresh_token": true,
	}

	for key := range data {
		if sensitiveFields[key] {
			data[key] = "[REDACTED]"
		}
	}

	sanitized, err := json.Marshal(data)
	if err != nil {
		return json.RawMessage("{}")
	}
	return sanitized
}
