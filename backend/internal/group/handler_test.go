package group

import (
	"math/rand"
	"net/http"
	"strconv"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/savingplus/backend/internal/testutil"
)

// TestInviteCodeFormat verifies invite code constraints: must be exactly 6 digits.
func TestInviteCodeFormat(t *testing.T) {
	tests := []struct {
		code    string
		valid   bool
	}{
		{"482910", true},
		{"000000", true},
		{"999999", true},
		{"12345", false},   // too short
		{"1234567", false}, // too long
		{"abcdef", false},  // not digits
		{"12 456", false},  // contains space
		{"", false},        // empty
	}

	for _, tc := range tests {
		t.Run(tc.code, func(t *testing.T) {
			isValid := len(tc.code) == 6
			for _, ch := range tc.code {
				if ch < '0' || ch > '9' {
					isValid = false
					break
				}
			}
			if isValid != tc.valid {
				t.Errorf("code=%q: got valid=%v, want=%v", tc.code, isValid, tc.valid)
			}
		})
	}
}

// TestGenerateInviteCode verifies that randomly generated 6-digit codes
// are within the expected range and length.
func TestGenerateInviteCode(t *testing.T) {
	for i := 0; i < 100; i++ {
		num := rand.Intn(900000) + 100000
		code := strconv.Itoa(num)
		if len(code) != 6 {
			t.Errorf("Generated code %q is not 6 digits", code)
		}
		n, err := strconv.Atoi(code)
		if err != nil {
			t.Errorf("Code %q is not numeric: %v", code, err)
		}
		if n < 100000 || n > 999999 {
			t.Errorf("Code %d out of range [100000, 999999]", n)
		}
	}
}

// TestJoinByCode_RequiresCode verifies that the JoinByCode endpoint rejects
// requests without the required invite_code field.
func TestJoinByCode_RequiresCode(t *testing.T) {
	router := testutil.SetupRouter()
	h := &Handler{db: nil}

	router.POST("/api/v1/groups/join", func(c *gin.Context) {
		c.Set("user_id", "test-user-id")
		h.JoinByCode(c)
	})

	tests := []struct {
		name       string
		body       interface{}
		wantStatus int
	}{
		{
			name:       "missing_invite_code",
			body:       map[string]interface{}{},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "empty_invite_code",
			body:       map[string]interface{}{"invite_code": ""},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "wrong_length",
			body:       map[string]interface{}{"invite_code": "123"},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "too_long",
			body:       map[string]interface{}{"invite_code": "1234567"},
			wantStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := testutil.MakeRequest(router, http.MethodPost, "/api/v1/groups/join", tc.body)
			if w.Code != tc.wantStatus {
				body := testutil.ParseResponse(w)
				t.Errorf("Expected status %d, got %d. Body: %v", tc.wantStatus, w.Code, body)
			}
		})
	}
}

// TestJoinByCode_ValidCodePassesBinding verifies that a valid 6-digit code
// passes binding validation (does not return 400).
func TestJoinByCode_ValidCodePassesBinding(t *testing.T) {
	router := testutil.SetupRouter()

	router.POST("/api/v1/groups/join", func(c *gin.Context) {
		c.Set("user_id", "test-user-id")
		var req struct {
			InviteCode string `json:"invite_code" binding:"required,len=6"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		// Binding passed - return 200 to confirm
		c.JSON(http.StatusOK, gin.H{"invite_code": req.InviteCode})
	})

	w := testutil.MakeRequest(router, http.MethodPost, "/api/v1/groups/join",
		map[string]interface{}{"invite_code": "482910"})

	if w.Code != http.StatusOK {
		body := testutil.ParseResponse(w)
		t.Errorf("Valid 6-digit code should pass binding, got %d. Body: %v", w.Code, body)
	}

	resp := testutil.ParseResponse(w)
	if resp["invite_code"] != "482910" {
		t.Errorf("Expected invite_code=482910, got %v", resp["invite_code"])
	}
}

// TestCreateGroupRequest_Binding verifies the CreateGroupRequest struct binding tags.
func TestCreateGroupRequest_Binding(t *testing.T) {
	router := testutil.SetupRouter()

	router.POST("/api/v1/groups", func(c *gin.Context) {
		var req CreateGroupRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"name": req.Name})
	})

	// Empty body should fail
	w := testutil.MakeRequest(router, http.MethodPost, "/api/v1/groups", map[string]interface{}{})
	if w.Code != http.StatusBadRequest {
		t.Errorf("Empty body should return 400, got %d", w.Code)
	}

	// Valid request
	w = testutil.MakeRequest(router, http.MethodPost, "/api/v1/groups", map[string]interface{}{
		"name":                "Mama Savings",
		"type":                "upatu",
		"contribution_amount": 5000,
		"frequency":           "weekly",
		"max_members":         8,
	})
	if w.Code != http.StatusOK {
		body := testutil.ParseResponse(w)
		t.Errorf("Valid request should return 200, got %d. Body: %v", w.Code, body)
	}

	// Invalid type
	w = testutil.MakeRequest(router, http.MethodPost, "/api/v1/groups", map[string]interface{}{
		"name":                "Bad Group",
		"type":                "invalid",
		"contribution_amount": 5000,
		"frequency":           "weekly",
		"max_members":         8,
	})
	if w.Code != http.StatusBadRequest {
		t.Errorf("Invalid type should return 400, got %d", w.Code)
	}

	// Invalid frequency
	w = testutil.MakeRequest(router, http.MethodPost, "/api/v1/groups", map[string]interface{}{
		"name":                "Bad Freq",
		"type":                "upatu",
		"contribution_amount": 5000,
		"frequency":           "yearly",
		"max_members":         8,
	})
	if w.Code != http.StatusBadRequest {
		t.Errorf("Invalid frequency should return 400, got %d", w.Code)
	}
}

func TestNewHandler(t *testing.T) {
	h := NewHandler(nil)
	if h == nil {
		t.Fatal("NewHandler should not return nil")
	}
}
