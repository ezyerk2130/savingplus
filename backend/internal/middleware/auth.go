package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/savingplus/backend/internal/auth"
	apperr "github.com/savingplus/backend/internal/errors"
)

func AuthRequired(jwtSvc *auth.JWTService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message})
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization header format"})
			return
		}

		claims, err := jwtSvc.ValidateAccessToken(parts[1])
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message, "detail": "Token expired or invalid"})
			return
		}

		c.Set("user_id", claims.UserID)
		c.Set("phone", claims.Phone)
		c.Set("role", claims.Role)
		c.Next()
	}
}

func AdminAuthRequired(jwtSvc *auth.JWTService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message})
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization header format"})
			return
		}

		claims, err := jwtSvc.ValidateAccessToken(parts[1])
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message})
			return
		}

		role := claims.Role
		if role != "support" && role != "finance" && role != "super_admin" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": apperr.ErrForbidden.Message})
			return
		}

		c.Set("admin_id", claims.UserID)
		c.Set("admin_role", role)
		c.Next()
	}
}

func RequireRole(roles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		adminRole := c.GetString("admin_role")
		for _, r := range roles {
			if adminRole == r {
				c.Next()
				return
			}
		}
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": apperr.ErrForbidden.Message, "detail": "Insufficient role"})
	}
}
