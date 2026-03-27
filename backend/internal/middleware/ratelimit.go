package middleware

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	log "github.com/sirupsen/logrus"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/pkg/logger"
)

func RateLimit(rdb *redis.Client, perSecond, perMinute int) gin.HandlerFunc {
	return func(c *gin.Context) {
		identifier := c.ClientIP()

		// Per-second check
		if blocked := checkLimit(c, rdb, identifier, int64(perSecond), time.Second, "1"); blocked {
			return
		}

		// Per-minute check
		if blocked := checkLimit(c, rdb, identifier, int64(perMinute), time.Minute, "60"); blocked {
			return
		}

		c.Next()
	}
}

func checkLimit(c *gin.Context, rdb *redis.Client, ip string, limit int64, window time.Duration, retryAfter string) bool {
	l := logger.Ctx(c)

	prefix := "sec"
	if window == time.Minute {
		prefix = "min"
	}
	key := fmt.Sprintf("rate:%s:%s", prefix, ip)

	count, err := rdb.Incr(c, key).Result()
	if err != nil {
		l.WithError(err).Warn("Redis rate limit check failed, allowing request")
		return false
	}

	if count == 1 {
		if err := rdb.Expire(c, key, window).Err(); err != nil {
			// Expire failed — delete key so it doesn't persist forever and permanently block this IP
			l.WithError(err).WithField("key", key).Warn("Redis expire failed, deleting key to prevent permanent block")
			if delErr := rdb.Del(c, key).Err(); delErr != nil {
				l.WithError(delErr).WithField("key", key).Error("Failed to delete orphaned rate limit key")
			}
			return false
		}
	}

	if count > limit {
		l.WithFields(log.Fields{
			"ip":      ip,
			"count":   count,
			"limit":   limit,
			"window":  prefix,
		}).Warn("Rate limit exceeded")

		c.Header("Retry-After", retryAfter)
		c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
			"error":       apperr.ErrTooManyRequests.Message,
			"detail":      fmt.Sprintf("Too many requests. Please try again in %ss.", retryAfter),
			"retry_after": retryAfter + "s",
		})
		return true
	}

	return false
}
