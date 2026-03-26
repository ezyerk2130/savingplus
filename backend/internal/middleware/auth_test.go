package middleware_test

import (
	"net/http"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/savingplus/backend/internal/auth"
	"github.com/savingplus/backend/internal/middleware"
	"github.com/savingplus/backend/internal/testutil"
)

const testSecret = "test-secret-key-for-unit-tests-only-1234567890"

func newTestJWT() *auth.JWTService {
	return auth.NewJWTService(testSecret, 15*time.Minute, 7*24*time.Hour)
}

// generateTestToken creates a valid JWT for the given user/role.
func generateTestToken(jwtSvc *auth.JWTService, userID, phone, role string) string {
	pair, _, err := jwtSvc.GenerateTokenPair(userID, phone, role)
	if err != nil {
		panic("failed to generate test token: " + err.Error())
	}
	return pair.AccessToken
}

// ---------------------------------------------------------------------------
// AuthRequired
// ---------------------------------------------------------------------------

func TestAuthRequired_NoHeader(t *testing.T) {
	jwtSvc := newTestJWT()
	r := testutil.SetupRouter()
	r.GET("/protected", middleware.AuthRequired(jwtSvc), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeRequest(r, http.MethodGet, "/protected", nil)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}
}

func TestAuthRequired_InvalidFormat(t *testing.T) {
	jwtSvc := newTestJWT()
	r := testutil.SetupRouter()
	r.GET("/protected", middleware.AuthRequired(jwtSvc), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	// Missing "Bearer " prefix
	w := testutil.MakeRequestWithHeaders(r, http.MethodGet, "/protected",
		map[string]string{"Authorization": "Token abc123"}, nil)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for invalid format, got %d", w.Code)
	}

	// Only "Bearer" with no token
	w = testutil.MakeRequestWithHeaders(r, http.MethodGet, "/protected",
		map[string]string{"Authorization": "Bearer"}, nil)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for 'Bearer' only, got %d", w.Code)
	}
}

func TestAuthRequired_InvalidToken(t *testing.T) {
	jwtSvc := newTestJWT()
	r := testutil.SetupRouter()
	r.GET("/protected", middleware.AuthRequired(jwtSvc), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeAuthRequest(r, http.MethodGet, "/protected", "invalid.jwt.token", nil)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for invalid token, got %d", w.Code)
	}
}

func TestAuthRequired_ExpiredToken(t *testing.T) {
	// Create a JWT service with a very short TTL
	jwtSvc := auth.NewJWTService(testSecret, -1*time.Second, 7*24*time.Hour)
	token := generateTestToken(jwtSvc, "user-123", "+255712345678", "user")

	// Use the normal JWT service for validation (token is already expired)
	validationSvc := newTestJWT()
	r := testutil.SetupRouter()
	r.GET("/protected", middleware.AuthRequired(validationSvc), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeAuthRequest(r, http.MethodGet, "/protected", token, nil)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for expired token, got %d", w.Code)
	}
}

func TestAuthRequired_ValidToken(t *testing.T) {
	jwtSvc := newTestJWT()
	token := generateTestToken(jwtSvc, "user-123", "+255712345678", "user")

	var capturedUserID, capturedPhone, capturedRole string
	r := testutil.SetupRouter()
	r.GET("/protected", middleware.AuthRequired(jwtSvc), func(c *gin.Context) {
		capturedUserID = c.GetString("user_id")
		capturedPhone = c.GetString("phone")
		capturedRole = c.GetString("role")
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeAuthRequest(r, http.MethodGet, "/protected", token, nil)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if capturedUserID != "user-123" {
		t.Errorf("expected user_id=user-123, got %s", capturedUserID)
	}
	if capturedPhone != "+255712345678" {
		t.Errorf("expected phone=+255712345678, got %s", capturedPhone)
	}
	if capturedRole != "user" {
		t.Errorf("expected role=user, got %s", capturedRole)
	}
}

// ---------------------------------------------------------------------------
// AdminAuthRequired
// ---------------------------------------------------------------------------

func TestAdminAuthRequired_NonAdminRole(t *testing.T) {
	jwtSvc := newTestJWT()
	token := generateTestToken(jwtSvc, "user-123", "+255712345678", "user")

	r := testutil.SetupRouter()
	r.GET("/admin", middleware.AdminAuthRequired(jwtSvc), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeAuthRequest(r, http.MethodGet, "/admin", token, nil)
	if w.Code != http.StatusForbidden {
		t.Errorf("expected 403 for non-admin role, got %d", w.Code)
	}
}

func TestAdminAuthRequired_NoHeader(t *testing.T) {
	jwtSvc := newTestJWT()
	r := testutil.SetupRouter()
	r.GET("/admin", middleware.AdminAuthRequired(jwtSvc), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeRequest(r, http.MethodGet, "/admin", nil)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}
}

func TestAdminAuthRequired_ValidSupportToken(t *testing.T) {
	jwtSvc := newTestJWT()
	token := generateTestToken(jwtSvc, "admin-1", "+255700000001", "support")

	var capturedAdminID, capturedAdminRole string
	r := testutil.SetupRouter()
	r.GET("/admin", middleware.AdminAuthRequired(jwtSvc), func(c *gin.Context) {
		capturedAdminID = c.GetString("admin_id")
		capturedAdminRole = c.GetString("admin_role")
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeAuthRequest(r, http.MethodGet, "/admin", token, nil)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if capturedAdminID != "admin-1" {
		t.Errorf("expected admin_id=admin-1, got %s", capturedAdminID)
	}
	if capturedAdminRole != "support" {
		t.Errorf("expected admin_role=support, got %s", capturedAdminRole)
	}
}

func TestAdminAuthRequired_ValidFinanceToken(t *testing.T) {
	jwtSvc := newTestJWT()
	token := generateTestToken(jwtSvc, "admin-2", "+255700000002", "finance")

	r := testutil.SetupRouter()
	r.GET("/admin", middleware.AdminAuthRequired(jwtSvc), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeAuthRequest(r, http.MethodGet, "/admin", token, nil)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200 for finance role, got %d", w.Code)
	}
}

func TestAdminAuthRequired_ValidSuperAdminToken(t *testing.T) {
	jwtSvc := newTestJWT()
	token := generateTestToken(jwtSvc, "admin-3", "+255700000003", "super_admin")

	var capturedAdminRole string
	r := testutil.SetupRouter()
	r.GET("/admin", middleware.AdminAuthRequired(jwtSvc), func(c *gin.Context) {
		capturedAdminRole = c.GetString("admin_role")
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeAuthRequest(r, http.MethodGet, "/admin", token, nil)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200 for super_admin, got %d", w.Code)
	}
	if capturedAdminRole != "super_admin" {
		t.Errorf("expected admin_role=super_admin, got %s", capturedAdminRole)
	}
}

func TestAdminAuthRequired_InvalidToken(t *testing.T) {
	jwtSvc := newTestJWT()
	r := testutil.SetupRouter()
	r.GET("/admin", middleware.AdminAuthRequired(jwtSvc), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeAuthRequest(r, http.MethodGet, "/admin", "bad.token.here", nil)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for invalid token, got %d", w.Code)
	}
}

// ---------------------------------------------------------------------------
// RequireRole
// ---------------------------------------------------------------------------

func TestRequireRole_MatchingRole(t *testing.T) {
	var handlerCalled bool
	r := testutil.SetupRouter()
	r.GET("/role-test",
		func(c *gin.Context) {
			c.Set("admin_role", "super_admin")
			c.Next()
		},
		middleware.RequireRole("support", "super_admin"),
		func(c *gin.Context) {
			handlerCalled = true
			c.JSON(http.StatusOK, gin.H{"ok": true})
		},
	)

	w := testutil.MakeRequest(r, http.MethodGet, "/role-test", nil)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200 for matching role, got %d", w.Code)
	}
	if !handlerCalled {
		t.Error("expected handler to be called for matching role")
	}
}

func TestRequireRole_NonMatchingRole(t *testing.T) {
	r := testutil.SetupRouter()
	r.GET("/role-test",
		func(c *gin.Context) {
			c.Set("admin_role", "finance")
			c.Next()
		},
		middleware.RequireRole("support", "super_admin"),
		func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"ok": true})
		},
	)

	w := testutil.MakeRequest(r, http.MethodGet, "/role-test", nil)
	if w.Code != http.StatusForbidden {
		t.Errorf("expected 403 for non-matching role, got %d", w.Code)
	}
	resp := testutil.ParseResponse(w)
	if detail, ok := resp["detail"].(string); !ok || detail != "Insufficient role" {
		t.Errorf("expected detail='Insufficient role', got %v", resp["detail"])
	}
}

func TestRequireRole_NoRoleSet(t *testing.T) {
	r := testutil.SetupRouter()
	r.GET("/role-test",
		middleware.RequireRole("support", "super_admin"),
		func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"ok": true})
		},
	)

	w := testutil.MakeRequest(r, http.MethodGet, "/role-test", nil)
	if w.Code != http.StatusForbidden {
		t.Errorf("expected 403 when no role is set, got %d", w.Code)
	}
}
