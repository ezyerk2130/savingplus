package response

import (
	"database/sql"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func init() {
	gin.SetMode(gin.TestMode)
}

// newTestContext creates a minimal Gin context with the given query string.
func newTestContext(query string) *gin.Context {
	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "/?"+query, nil)
	c, _ := gin.CreateTestContext(w)
	c.Request = r
	return c
}

// ---------------------------------------------------------------------------
// GetPagination
// ---------------------------------------------------------------------------

func TestGetPagination(t *testing.T) {
	tests := []struct {
		name        string
		query       string
		defaultSize int
		wantPage    int
		wantSize    int
		wantOffset  int
	}{
		{
			name:        "defaults when no query params",
			query:       "",
			defaultSize: 20,
			wantPage:    1,
			wantSize:    20,
			wantOffset:  0,
		},
		{
			name:        "custom page",
			query:       "page=3",
			defaultSize: 10,
			wantPage:    3,
			wantSize:    10,
			wantOffset:  20,
		},
		{
			name:        "negative page clamped to 1",
			query:       "page=-5",
			defaultSize: 20,
			wantPage:    1,
			wantSize:    20,
			wantOffset:  0,
		},
		{
			name:        "zero page clamped to 1",
			query:       "page=0",
			defaultSize: 20,
			wantPage:    1,
			wantSize:    20,
			wantOffset:  0,
		},
		{
			name:        "defaultSize out of range (too large) clamped to 20",
			query:       "",
			defaultSize: 200,
			wantPage:    1,
			wantSize:    20,
			wantOffset:  0,
		},
		{
			name:        "defaultSize out of range (zero) clamped to 20",
			query:       "",
			defaultSize: 0,
			wantPage:    1,
			wantSize:    20,
			wantOffset:  0,
		},
		{
			name:        "defaultSize out of range (negative) clamped to 20",
			query:       "",
			defaultSize: -1,
			wantPage:    1,
			wantSize:    20,
			wantOffset:  0,
		},
		{
			name:        "non-numeric page defaults to 1",
			query:       "page=abc",
			defaultSize: 10,
			wantPage:    1,
			wantSize:    10,
			wantOffset:  0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			c := newTestContext(tc.query)
			p := GetPagination(c, tc.defaultSize)
			if p.Page != tc.wantPage {
				t.Errorf("Page = %d, want %d", p.Page, tc.wantPage)
			}
			if p.PageSize != tc.wantSize {
				t.Errorf("PageSize = %d, want %d", p.PageSize, tc.wantSize)
			}
			if p.Offset != tc.wantOffset {
				t.Errorf("Offset = %d, want %d", p.Offset, tc.wantOffset)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// TotalPages
// ---------------------------------------------------------------------------

func TestTotalPages(t *testing.T) {
	tests := []struct {
		total    int
		pageSize int
		want     int
	}{
		{0, 10, 0},
		{1, 10, 1},
		{10, 10, 1},
		{11, 10, 2},
		{100, 20, 5},
		{101, 20, 6},
		{0, 0, 0},   // zero pageSize returns 0
		{10, -1, 0}, // negative pageSize returns 0
	}
	for _, tc := range tests {
		got := TotalPages(tc.total, tc.pageSize)
		if got != tc.want {
			t.Errorf("TotalPages(%d, %d) = %d, want %d", tc.total, tc.pageSize, got, tc.want)
		}
	}
}

// ---------------------------------------------------------------------------
// FormatMoney
// ---------------------------------------------------------------------------

func TestFormatMoney(t *testing.T) {
	tests := []struct {
		amount float64
		want   string
	}{
		{0, "0.00"},
		{1, "1.00"},
		{99.9, "99.90"},
		{100.456, "100.46"},
		{1000000.00, "1000000.00"},
		{-50.5, "-50.50"},
		{0.001, "0.00"},
		{0.005, "0.01"}, // banker's rounding may vary; strconv uses IEEE rounding
	}
	for _, tc := range tests {
		got := FormatMoney(tc.amount)
		if got != tc.want {
			t.Errorf("FormatMoney(%v) = %q, want %q", tc.amount, got, tc.want)
		}
	}
}

// ---------------------------------------------------------------------------
// NullStr
// ---------------------------------------------------------------------------

func TestNullStr(t *testing.T) {
	t.Run("valid", func(t *testing.T) {
		ns := sql.NullString{String: "hello", Valid: true}
		got := NullStr(ns)
		if got == nil || *got != "hello" {
			t.Errorf("NullStr(valid) = %v, want pointer to 'hello'", got)
		}
	})
	t.Run("invalid", func(t *testing.T) {
		ns := sql.NullString{Valid: false}
		got := NullStr(ns)
		if got != nil {
			t.Errorf("NullStr(invalid) = %v, want nil", got)
		}
	})
}

// ---------------------------------------------------------------------------
// NullInt
// ---------------------------------------------------------------------------

func TestNullInt(t *testing.T) {
	t.Run("valid", func(t *testing.T) {
		ni := sql.NullInt32{Int32: 42, Valid: true}
		got := NullInt(ni)
		if got == nil || *got != 42 {
			t.Errorf("NullInt(valid) = %v, want pointer to 42", got)
		}
	})
	t.Run("invalid", func(t *testing.T) {
		ni := sql.NullInt32{Valid: false}
		got := NullInt(ni)
		if got != nil {
			t.Errorf("NullInt(invalid) = %v, want nil", got)
		}
	})
}

// ---------------------------------------------------------------------------
// NullFloat
// ---------------------------------------------------------------------------

func TestNullFloat(t *testing.T) {
	t.Run("valid", func(t *testing.T) {
		nf := sql.NullFloat64{Float64: 3.14, Valid: true}
		got := NullFloat(nf)
		if got == nil || *got != 3.14 {
			t.Errorf("NullFloat(valid) = %v, want pointer to 3.14", got)
		}
	})
	t.Run("invalid", func(t *testing.T) {
		nf := sql.NullFloat64{Valid: false}
		got := NullFloat(nf)
		if got != nil {
			t.Errorf("NullFloat(invalid) = %v, want nil", got)
		}
	})
}

// ---------------------------------------------------------------------------
// NullTime
// ---------------------------------------------------------------------------

func TestNullTime(t *testing.T) {
	t.Run("valid", func(t *testing.T) {
		ts := time.Date(2025, 6, 15, 10, 30, 0, 0, time.UTC)
		nt := sql.NullTime{Time: ts, Valid: true}
		got := NullTime(nt)
		if got == nil {
			t.Fatal("NullTime(valid) = nil, want non-nil")
		}
		want := "2025-06-15T10:30:00Z"
		if *got != want {
			t.Errorf("NullTime(valid) = %q, want %q", *got, want)
		}
	})
	t.Run("invalid", func(t *testing.T) {
		nt := sql.NullTime{Valid: false}
		got := NullTime(nt)
		if got != nil {
			t.Errorf("NullTime(invalid) = %v, want nil", got)
		}
	})
}

// ---------------------------------------------------------------------------
// EmptySlice
// ---------------------------------------------------------------------------

func TestEmptySlice(t *testing.T) {
	t.Run("nil slice returns empty non-nil slice", func(t *testing.T) {
		var s []int
		got := EmptySlice(s)
		if got == nil {
			t.Error("EmptySlice(nil) returned nil, want non-nil empty slice")
		}
		if len(got) != 0 {
			t.Errorf("len = %d, want 0", len(got))
		}
	})

	t.Run("non-nil slice returned as-is", func(t *testing.T) {
		s := []string{"a", "b"}
		got := EmptySlice(s)
		if len(got) != 2 {
			t.Errorf("len = %d, want 2", len(got))
		}
		if got[0] != "a" || got[1] != "b" {
			t.Errorf("got %v, want [a b]", got)
		}
	})

	t.Run("empty non-nil slice returned as-is", func(t *testing.T) {
		s := make([]int, 0)
		got := EmptySlice(s)
		if got == nil {
			t.Error("returned nil for non-nil empty slice")
		}
		if len(got) != 0 {
			t.Errorf("len = %d, want 0", len(got))
		}
	})
}
