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

		identifier := c.ClientIP()
		if userID := c.GetString("user_id"); userID != "" {
			identifier = userID
		}

		// Per-second limit
		secKey := fmt.Sprintf("rate:sec:%s", identifier)
		secCount, err := rdb.Incr(c, secKey).Result()
		if err != nil {
			log.WithError(err).WithField("key", secKey).Warn("Redis rate limit incr failed, allowing request")
			c.Next()
			return
		}
		if secCount == 1 {
			if err := rdb.Expire(c, secKey, time.Second).Err(); err != nil {
				log.WithError(err).Warn("Redis rate limit expire failed")
			}
		}
		if secCount > int64(perSecond) {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error":       apperr.ErrTooManyRequests.Message,
				"retry_after": "1s",
			})
			return
		}

		// Per-minute limit
		minKey := fmt.Sprintf("rate:min:%s", identifier)
		minCount, err := rdb.Incr(c, minKey).Result()
		if err != nil {
			log.WithError(err).WithField("key", minKey).Warn("Redis rate limit incr failed, allowing request")
			c.Next()
			return
		}
		if minCount == 1 {
			if err := rdb.Expire(c, minKey, time.Minute).Err(); err != nil {
				log.WithError(err).Warn("Redis rate limit expire failed")
			}
		}
		if minCount > int64(perMinute) {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error":       apperr.ErrTooManyRequests.Message,
				"retry_after": "60s",
			})
			return
		}

		c.Next()
	}
}
