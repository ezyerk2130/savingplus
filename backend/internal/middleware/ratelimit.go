package middleware

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/pkg/logger"
)

func RateLimit(rdb *redis.Client, perSecond, perMinute int) gin.HandlerFunc {
	return func(c *gin.Context) {
		log := logger.Ctx(c)

		// Use IP as identifier (runs before auth, so user_id not available yet)
		identifier := c.ClientIP()

		// Per-second limit
		secKey := fmt.Sprintf("rate:sec:%s", identifier)
		secCount, err := rdb.Incr(c, secKey).Result()
		if err != nil {
			log.WithError(err).Warn("Redis rate limit check failed, allowing request")
			c.Next()
			return
		}
		if secCount == 1 {
			rdb.Expire(c, secKey, time.Second)
		}
		if secCount > int64(perSecond) {
			log.WithField("ip", identifier).WithField("count", secCount).Warn("Rate limit exceeded (per-second)")
			c.Header("Retry-After", "1")
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error":       apperr.ErrTooManyRequests.Message,
				"detail":      "Too many requests. Please slow down.",
				"retry_after": "1s",
			})
			return
		}

		// Per-minute limit
		minKey := fmt.Sprintf("rate:min:%s", identifier)
		minCount, err := rdb.Incr(c, minKey).Result()
		if err != nil {
			log.WithError(err).Warn("Redis rate limit check failed, allowing request")
			c.Next()
			return
		}
		if minCount == 1 {
			rdb.Expire(c, minKey, time.Minute)
		}
		if minCount > int64(perMinute) {
			log.WithField("ip", identifier).WithField("count", minCount).Warn("Rate limit exceeded (per-minute)")
			c.Header("Retry-After", "60")
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error":       apperr.ErrTooManyRequests.Message,
				"detail":      "Too many requests. Please try again in a minute.",
				"retry_after": "60s",
			})
			return
		}

		c.Next()
	}
}
