package middleware

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"

	apperr "github.com/savingplus/backend/internal/errors"
)

func RateLimit(rdb *redis.Client, perSecond, perMinute int) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Use user ID if authenticated, otherwise IP
		identifier := c.ClientIP()
		if userID := c.GetString("user_id"); userID != "" {
			identifier = userID
		}

		// Per-second limit
		secKey := fmt.Sprintf("rate:sec:%s", identifier)
		secCount, _ := rdb.Incr(c, secKey).Result()
		if secCount == 1 {
			rdb.Expire(c, secKey, time.Second)
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
		minCount, _ := rdb.Incr(c, minKey).Result()
		if minCount == 1 {
			rdb.Expire(c, minKey, time.Minute)
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
