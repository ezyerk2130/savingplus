package crypto

import (
	"encoding/hex"
	"strings"
	"testing"
)

// ---------------------------------------------------------------------------
// HashPassword / VerifyPassword
// ---------------------------------------------------------------------------

func TestHashPassword_ReturnsValidFormat(t *testing.T) {
	hash, err := HashPassword("secureP@ss1")
	if err != nil {
		t.Fatalf("HashPassword returned error: %v", err)
	}
	// Format: <hex-salt>$<hex-hash>
	parts := strings.SplitN(hash, "$", 2)
	if len(parts) != 2 {
		t.Fatalf("expected salt$hash format, got %q", hash)
	}
	if len(parts[0]) != saltLen*2 { // hex-encoded 16-byte salt = 32 hex chars
		t.Errorf("salt hex length = %d, want %d", len(parts[0]), saltLen*2)
	}
	if len(parts[1]) != argonKeyLen*2 { // hex-encoded 32-byte key = 64 hex chars
		t.Errorf("hash hex length = %d, want %d", len(parts[1]), argonKeyLen*2)
	}
}

func TestHashPassword_DifferentSaltsEachTime(t *testing.T) {
	h1, _ := HashPassword("same")
	h2, _ := HashPassword("same")
	if h1 == h2 {
		t.Error("two calls with the same password should produce different hashes (different salts)")
	}
}

func TestVerifyPassword(t *testing.T) {
	tests := []struct {
		name     string
		password string
		check    string
		want     bool
	}{
		{"correct password", "hello123", "hello123", true},
		{"wrong password", "hello123", "wrong", false},
		{"empty password hashed then verified", "", "", true},
		{"empty vs non-empty", "", "notempty", false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			hash, err := HashPassword(tc.password)
			if err != nil {
				t.Fatalf("HashPassword error: %v", err)
			}
			got := VerifyPassword(tc.check, hash)
			if got != tc.want {
				t.Errorf("VerifyPassword(%q, hash_of(%q)) = %v, want %v", tc.check, tc.password, got, tc.want)
			}
		})
	}
}

func TestVerifyPassword_InvalidEncoded(t *testing.T) {
	tests := []struct {
		name    string
		encoded string
	}{
		{"empty string", ""},
		{"no dollar sign", "abcdef1234567890"},
		{"bad hex in salt", "ZZZZZZ$abcdef"},
		{"bad hex in hash", "aabbccdd$ZZZZZZ"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if VerifyPassword("anything", tc.encoded) {
				t.Error("expected false for malformed encoded string")
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Encrypt / Decrypt
// ---------------------------------------------------------------------------

func validAES256Key() string {
	// 32-byte key -> 64 hex chars
	return "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}

func TestEncryptDecrypt_Roundtrip(t *testing.T) {
	key := validAES256Key()
	tests := []string{
		"hello world",
		"",
		"🇹🇿 Tanzania Shilling",
		strings.Repeat("a", 10000),
	}
	for _, pt := range tests {
		ct, err := Encrypt(pt, key)
		if err != nil {
			t.Fatalf("Encrypt(%q) error: %v", pt, err)
		}
		got, err := Decrypt(ct, key)
		if err != nil {
			t.Fatalf("Decrypt error: %v", err)
		}
		if got != pt {
			t.Errorf("roundtrip failed: got %q, want %q", got, pt)
		}
	}
}

func TestEncrypt_DifferentCiphertextEachTime(t *testing.T) {
	key := validAES256Key()
	ct1, _ := Encrypt("same", key)
	ct2, _ := Encrypt("same", key)
	if ct1 == ct2 {
		t.Error("encrypting the same plaintext twice should produce different ciphertexts (random nonce)")
	}
}

func TestDecrypt_WrongKey(t *testing.T) {
	key1 := validAES256Key()
	key2 := "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
	ct, _ := Encrypt("secret", key1)
	_, err := Decrypt(ct, key2)
	if err == nil {
		t.Error("expected error when decrypting with wrong key")
	}
}

func TestDecrypt_InvalidCiphertext(t *testing.T) {
	key := validAES256Key()
	tests := []struct {
		name string
		ct   string
	}{
		{"not hex", "zzzz"},
		{"too short", "aabb"},
		{"tampered", func() string {
			ct, _ := Encrypt("data", key)
			// Flip a byte in the middle
			b, _ := hex.DecodeString(ct)
			b[len(b)/2] ^= 0xff
			return hex.EncodeToString(b)
		}()},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := Decrypt(tc.ct, key)
			if err == nil {
				t.Error("expected error for invalid ciphertext")
			}
		})
	}
}

func TestEncrypt_InvalidKey(t *testing.T) {
	_, err := Encrypt("data", "not-hex")
	if err == nil {
		t.Error("expected error for invalid key hex")
	}

	// Key too short (16 bytes = AES-128, not AES-256... actually aes.NewCipher
	// accepts 16/24/32 byte keys, so 15 bytes should fail)
	shortKey := hex.EncodeToString([]byte("fifteen_bytes!!"))
	_, err = Encrypt("data", shortKey)
	if err == nil {
		t.Error("expected error for 15-byte key")
	}
}

// ---------------------------------------------------------------------------
// GenerateOTP
// ---------------------------------------------------------------------------

func TestGenerateOTP(t *testing.T) {
	tests := []struct {
		length int
	}{
		{4},
		{6},
		{8},
	}
	for _, tc := range tests {
		t.Run("length_"+string(rune('0'+tc.length)), func(t *testing.T) {
			otp, err := GenerateOTP(tc.length)
			if err != nil {
				t.Fatalf("GenerateOTP(%d) error: %v", tc.length, err)
			}
			if len(otp) != tc.length {
				t.Errorf("len(otp) = %d, want %d", len(otp), tc.length)
			}
			// All characters should be digits
			for _, c := range otp {
				if c < '0' || c > '9' {
					t.Errorf("OTP contains non-digit character: %c", c)
				}
			}
		})
	}
}

func TestGenerateOTP_PaddedWithZeros(t *testing.T) {
	// Run many times to increase chance of hitting a small number that needs padding
	for i := 0; i < 100; i++ {
		otp, err := GenerateOTP(6)
		if err != nil {
			t.Fatalf("GenerateOTP error: %v", err)
		}
		if len(otp) != 6 {
			t.Fatalf("OTP length = %d, want 6 (value: %s)", len(otp), otp)
		}
	}
}

// ---------------------------------------------------------------------------
// HMACSign / HMACVerify
// ---------------------------------------------------------------------------

func TestHMACSign_Deterministic(t *testing.T) {
	sig1 := HMACSign("data", "key")
	sig2 := HMACSign("data", "key")
	if sig1 != sig2 {
		t.Error("HMAC of same data+key should be deterministic")
	}
}

func TestHMACSign_DifferentData(t *testing.T) {
	s1 := HMACSign("data1", "key")
	s2 := HMACSign("data2", "key")
	if s1 == s2 {
		t.Error("different data should produce different signatures")
	}
}

func TestHMACSign_DifferentKeys(t *testing.T) {
	s1 := HMACSign("data", "key1")
	s2 := HMACSign("data", "key2")
	if s1 == s2 {
		t.Error("different keys should produce different signatures")
	}
}

func TestHMACVerify(t *testing.T) {
	tests := []struct {
		name     string
		data     string
		signKey  string
		verData  string
		verKey   string
		wantOK   bool
	}{
		{"valid", "payload", "secret", "payload", "secret", true},
		{"tampered data", "payload", "secret", "tampered", "secret", false},
		{"wrong key", "payload", "secret", "payload", "wrong", false},
		{"empty data", "", "key", "", "key", true},
		{"empty key", "data", "", "data", "", true},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			sig := HMACSign(tc.data, tc.signKey)
			got := HMACVerify(tc.verData, sig, tc.verKey)
			if got != tc.wantOK {
				t.Errorf("HMACVerify = %v, want %v", got, tc.wantOK)
			}
		})
	}
}

func TestHMACSign_OutputIsHex(t *testing.T) {
	sig := HMACSign("data", "key")
	_, err := hex.DecodeString(sig)
	if err != nil {
		t.Errorf("signature is not valid hex: %v", err)
	}
	// SHA-256 produces 32 bytes = 64 hex chars
	if len(sig) != 64 {
		t.Errorf("signature length = %d, want 64", len(sig))
	}
}
