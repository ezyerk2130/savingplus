package logger

import (
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	log "github.com/sirupsen/logrus"
)

// Ctx extracts standard fields from a Gin context for structured logging.
// Every log call in a handler should use logger.Ctx(c).WithError(err).Error(...)
func Ctx(c *gin.Context) *log.Entry {
	fields := log.Fields{}

	if rid := c.GetString("request_id"); rid != "" {
		fields["request_id"] = rid
	}
	if uid := c.GetString("user_id"); uid != "" {
		fields["user_id"] = uid
	}
	if aid := c.GetString("admin_id"); aid != "" {
		fields["admin_id"] = aid
	}
	if c.Request != nil {
		fields["ip"] = c.ClientIP()
		fields["method"] = c.Request.Method
		fields["path"] = c.Request.URL.Path
	}

	return log.WithFields(fields)
}

// DeviceName extracts a readable device/client name from User-Agent.
func DeviceName(ua string) string {
	if ua == "" {
		return "unknown"
	}
	ua = strings.ToLower(ua)

	// Mobile detection
	switch {
	case strings.Contains(ua, "savingplus-android"):
		return "android-app"
	case strings.Contains(ua, "savingplus-ios"):
		return "ios-app"
	case strings.Contains(ua, "dart") || strings.Contains(ua, "flutter"):
		return "flutter-app"
	case strings.Contains(ua, "okhttp"):
		return "android-native"
	case strings.Contains(ua, "cfnetwork"):
		return "ios-native"
	}

	// Browser detection
	switch {
	case strings.Contains(ua, "edg/"):
		return "edge"
	case strings.Contains(ua, "chrome") && !strings.Contains(ua, "edg"):
		return "chrome"
	case strings.Contains(ua, "firefox"):
		return "firefox"
	case strings.Contains(ua, "safari") && !strings.Contains(ua, "chrome"):
		return "safari"
	}

	// Tool detection
	switch {
	case strings.Contains(ua, "postman"):
		return "postman"
	case strings.Contains(ua, "insomnia"):
		return "insomnia"
	case strings.Contains(ua, "curl"):
		return "curl"
	case strings.Contains(ua, "axios"):
		return "axios"
	case strings.Contains(ua, "python"):
		return "python"
	case strings.Contains(ua, "go-http"):
		return "go-client"
	}

	return "other"
}

// RequestLogger is Gin middleware that logs every HTTP request with structured fields,
// latency, status code, device name, and supports log-level filtering.
func RequestLogger(minLevel log.Level) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()
		device := DeviceName(c.Request.UserAgent())

		fields := log.Fields{
			"status":     status,
			"latency_ms": latency.Milliseconds(),
			"method":     c.Request.Method,
			"path":       c.Request.URL.Path,
			"ip":         c.ClientIP(),
			"device":     device,
			"user_agent": c.Request.UserAgent(),
			"size":       c.Writer.Size(),
		}

		if rid := c.GetString("request_id"); rid != "" {
			fields["request_id"] = rid
		}
		if uid := c.GetString("user_id"); uid != "" {
			fields["user_id"] = uid
		}
		if aid := c.GetString("admin_id"); aid != "" {
			fields["admin_id"] = aid
		}
		if q := c.Request.URL.RawQuery; q != "" {
			fields["query"] = q
		}

		entry := log.WithFields(fields)

		// Filter by status code → log level
		switch {
		case status >= 500:
			entry.Error("Server error")
		case status >= 400:
			if minLevel <= log.WarnLevel {
				entry.Warn("Client error")
			}
		default:
			if minLevel <= log.InfoLevel {
				entry.Info("Request completed")
			}
		}
	}
}

// FilterLevel returns a logrus level from a string for use with RequestLogger.
func FilterLevel(level string) log.Level {
	switch strings.ToLower(level) {
	case "debug":
		return log.DebugLevel
	case "info":
		return log.InfoLevel
	case "warn", "warning":
		return log.WarnLevel
	case "error":
		return log.ErrorLevel
	default:
		return log.InfoLevel
	}
}
