package middleware_test

import (
	"net/http"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/savingplus/backend/internal/middleware"
	"github.com/savingplus/backend/internal/testutil"
)

// ---------------------------------------------------------------------------
// CORS
// ---------------------------------------------------------------------------

func TestCORS_HeadersSet(t *testing.T) {
	r := testutil.SetupRouter()
	r.Use(middleware.CORS())
	r.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeRequestWithHeaders(r, http.MethodGet, "/test",
		map[string]string{"Origin": "http://localhost:3000"}, nil)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	tests := []struct {
		header   string
		expected string
	}{
		{"Access-Control-Allow-Origin", "http://localhost:3000"},
		{"Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS"},
		{"Access-Control-Allow-Headers", "Content-Type, Authorization, Idempotency-Key, X-Request-ID"},
		{"Access-Control-Allow-Credentials", "true"},
		{"Access-Control-Max-Age", "86400"},
		{"Access-Control-Expose-Headers", "X-Request-ID"},
	}

	for _, tt := range tests {
		got := w.Header().Get(tt.header)
		if got != tt.expected {
			t.Errorf("header %s: expected %q, got %q", tt.header, tt.expected, got)
		}
	}
}

func TestCORS_OptionsReturns204(t *testing.T) {
	r := testutil.SetupRouter()
	r.Use(middleware.CORS())
	r.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeRequestWithHeaders(r, http.MethodOptions, "/test",
		map[string]string{"Origin": "http://localhost:3000"}, nil)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected 204 for OPTIONS, got %d", w.Code)
	}
}

func TestCORS_OptionsDoesNotCallNext(t *testing.T) {
	handlerCalled := false
	r := testutil.SetupRouter()
	r.Use(middleware.CORS())
	r.OPTIONS("/test", func(c *gin.Context) {
		handlerCalled = true
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	testutil.MakeRequestWithHeaders(r, http.MethodOptions, "/test",
		map[string]string{"Origin": "http://localhost:3000"}, nil)

	if handlerCalled {
		t.Error("handler should not be called for OPTIONS request")
	}
}

func TestCORS_ReflectsOrigin(t *testing.T) {
	r := testutil.SetupRouter()
	r.Use(middleware.CORS())
	r.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	origin := "https://savingplus.co.tz"
	w := testutil.MakeRequestWithHeaders(r, http.MethodGet, "/test",
		map[string]string{"Origin": origin}, nil)

	got := w.Header().Get("Access-Control-Allow-Origin")
	if got != origin {
		t.Errorf("expected origin %q to be reflected, got %q", origin, got)
	}
}

// ---------------------------------------------------------------------------
// SecurityHeaders
// ---------------------------------------------------------------------------

func TestSecurityHeaders_AllSet(t *testing.T) {
	r := testutil.SetupRouter()
	r.Use(middleware.SecurityHeaders())
	r.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeRequest(r, http.MethodGet, "/test", nil)

	tests := []struct {
		header   string
		expected string
	}{
		{"X-Content-Type-Options", "nosniff"},
		{"X-Frame-Options", "DENY"},
		{"X-XSS-Protection", "1; mode=block"},
		{"Strict-Transport-Security", "max-age=31536000; includeSubDomains"},
		{"Referrer-Policy", "strict-origin-when-cross-origin"},
		{"Content-Security-Policy", "default-src 'self'"},
	}

	for _, tt := range tests {
		got := w.Header().Get(tt.header)
		if got != tt.expected {
			t.Errorf("header %s: expected %q, got %q", tt.header, tt.expected, got)
		}
	}
}

func TestSecurityHeaders_DoesNotOverrideExisting(t *testing.T) {
	r := testutil.SetupRouter()
	r.Use(middleware.SecurityHeaders())
	r.GET("/test", func(c *gin.Context) {
		// Handler runs after middleware has set headers
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w := testutil.MakeRequest(r, http.MethodGet, "/test", nil)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

// ---------------------------------------------------------------------------
// RequestID
// ---------------------------------------------------------------------------

func TestRequestID_GeneratesNewID(t *testing.T) {
	r := testutil.SetupRouter()
	r.Use(middleware.RequestID())
	r.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"request_id": c.GetString("request_id")})
	})

	w := testutil.MakeRequest(r, http.MethodGet, "/test", nil)

	respID := w.Header().Get("X-Request-ID")
	if respID == "" {
		t.Error("expected X-Request-ID header to be set")
	}

	// The ID should be a UUID-like string (36 chars with hyphens)
	if len(respID) != 36 {
		t.Errorf("expected UUID-length request ID, got %q (len=%d)", respID, len(respID))
	}

	// Context should also have it
	resp := testutil.ParseResponse(w)
	if resp["request_id"] != respID {
		t.Errorf("context request_id %v does not match header %s", resp["request_id"], respID)
	}
}

func TestRequestID_UsesExistingID(t *testing.T) {
	r := testutil.SetupRouter()
	r.Use(middleware.RequestID())
	r.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"request_id": c.GetString("request_id")})
	})

	existingID := "my-custom-request-id-12345"
	w := testutil.MakeRequestWithHeaders(r, http.MethodGet, "/test",
		map[string]string{"X-Request-ID": existingID}, nil)

	respID := w.Header().Get("X-Request-ID")
	if respID != existingID {
		t.Errorf("expected X-Request-ID=%q, got %q", existingID, respID)
	}

	resp := testutil.ParseResponse(w)
	if resp["request_id"] != existingID {
		t.Errorf("context request_id should be %q, got %v", existingID, resp["request_id"])
	}
}

func TestRequestID_UniquePerRequest(t *testing.T) {
	r := testutil.SetupRouter()
	r.Use(middleware.RequestID())
	r.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	w1 := testutil.MakeRequest(r, http.MethodGet, "/test", nil)
	w2 := testutil.MakeRequest(r, http.MethodGet, "/test", nil)

	id1 := w1.Header().Get("X-Request-ID")
	id2 := w2.Header().Get("X-Request-ID")
	if id1 == id2 {
		t.Errorf("expected unique request IDs, both were %q", id1)
	}
}
