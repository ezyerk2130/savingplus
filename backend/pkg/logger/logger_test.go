package logger

import (
	"testing"

	log "github.com/sirupsen/logrus"
)

// ---------------------------------------------------------------------------
// DeviceName
// ---------------------------------------------------------------------------

func TestDeviceName(t *testing.T) {
	tests := []struct {
		name string
		ua   string
		want string
	}{
		// Mobile apps
		{"android app", "SavingPlus-Android/1.0", "android-app"},
		{"ios app", "SavingPlus-iOS/2.3", "ios-app"},
		{"flutter", "Dart/2.19 (dart:io) flutter", "flutter-app"},
		{"dart only", "Dart/2.19 (dart:io)", "flutter-app"},
		{"android native okhttp", "okhttp/4.9.3", "android-native"},
		{"ios native cfnetwork", "CFNetwork/1404.0.5 Darwin/22.3.0", "ios-native"},

		// Browsers
		{"chrome", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", "chrome"},
		{"firefox", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0", "firefox"},
		{"safari", "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15", "safari"},
		{"edge", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0", "edge"},

		// Tools
		{"postman", "PostmanRuntime/7.36.0", "postman"},
		{"curl", "curl/8.4.0", "curl"},
		{"insomnia", "insomnia/8.0.0", "insomnia"},
		{"axios", "axios/1.6.2", "axios"},
		{"python", "python-requests/2.31.0", "python"},
		{"go client", "Go-http-client/2.0", "go-client"},

		// Edge cases
		{"empty string", "", "unknown"},
		{"random unknown UA", "SomeRandomClient/1.0", "other"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := DeviceName(tc.ua)
			if got != tc.want {
				t.Errorf("DeviceName(%q) = %q, want %q", tc.ua, got, tc.want)
			}
		})
	}
}

func TestDeviceName_CaseInsensitive(t *testing.T) {
	// The function lowercases UA before matching
	got := DeviceName("CHROME/120")
	if got != "chrome" {
		t.Errorf("DeviceName(uppercase CHROME) = %q, want 'chrome'", got)
	}
}

// ---------------------------------------------------------------------------
// FilterLevel
// ---------------------------------------------------------------------------

func TestFilterLevel(t *testing.T) {
	tests := []struct {
		input string
		want  log.Level
	}{
		{"debug", log.DebugLevel},
		{"DEBUG", log.DebugLevel},
		{"info", log.InfoLevel},
		{"Info", log.InfoLevel},
		{"warn", log.WarnLevel},
		{"warning", log.WarnLevel},
		{"WARNING", log.WarnLevel},
		{"error", log.ErrorLevel},
		{"Error", log.ErrorLevel},
		{"unknown", log.InfoLevel},    // default
		{"", log.InfoLevel},           // default
		{"trace", log.InfoLevel},      // not handled, defaults to info
		{"fatal", log.InfoLevel},      // not handled, defaults to info
	}

	for _, tc := range tests {
		t.Run(tc.input, func(t *testing.T) {
			got := FilterLevel(tc.input)
			if got != tc.want {
				t.Errorf("FilterLevel(%q) = %v, want %v", tc.input, got, tc.want)
			}
		})
	}
}
