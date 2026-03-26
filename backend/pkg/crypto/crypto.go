package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"math/big"

	"golang.org/x/crypto/argon2"
)

// Argon2id parameters
const (
	argonTime    = 1
	argonMemory  = 64 * 1024
	argonThreads = 4
	argonKeyLen  = 32
	saltLen      = 16
)

// HashPassword hashes a password using Argon2id
func HashPassword(password string) (string, error) {
	salt := make([]byte, saltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("failed to generate salt: %w", err)
	}

	hash := argon2.IDKey([]byte(password), salt, argonTime, argonMemory, argonThreads, argonKeyLen)
	return fmt.Sprintf("%x$%x", salt, hash), nil
}

// VerifyPassword verifies a password against an Argon2id hash
func VerifyPassword(password, encoded string) bool {
	var saltHex, hashHex string
	n, _ := fmt.Sscanf(encoded, "%64s", &saltHex)
	if n < 1 {
		return false
	}

	// Split on $
	for i, c := range encoded {
		if c == '$' {
			saltHex = encoded[:i]
			hashHex = encoded[i+1:]
			break
		}
	}

	salt, err := hex.DecodeString(saltHex)
	if err != nil {
		return false
	}

	expectedHash, err := hex.DecodeString(hashHex)
	if err != nil {
		return false
	}

	hash := argon2.IDKey([]byte(password), salt, argonTime, argonMemory, argonThreads, argonKeyLen)
	return hmac.Equal(hash, expectedHash)
}

// Encrypt encrypts plaintext using AES-256-GCM
func Encrypt(plaintext string, keyHex string) (string, error) {
	key, err := hex.DecodeString(keyHex)
	if err != nil {
		return "", fmt.Errorf("invalid encryption key: %w", err)
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	ciphertext := aesGCM.Seal(nonce, nonce, []byte(plaintext), nil)
	return hex.EncodeToString(ciphertext), nil
}

// Decrypt decrypts ciphertext using AES-256-GCM
func Decrypt(ciphertextHex string, keyHex string) (string, error) {
	key, err := hex.DecodeString(keyHex)
	if err != nil {
		return "", fmt.Errorf("invalid encryption key: %w", err)
	}

	ciphertext, err := hex.DecodeString(ciphertextHex)
	if err != nil {
		return "", fmt.Errorf("invalid ciphertext: %w", err)
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonceSize := aesGCM.NonceSize()
	if len(ciphertext) < nonceSize {
		return "", fmt.Errorf("ciphertext too short")
	}

	nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
	plaintext, err := aesGCM.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}

// GenerateOTP generates a numeric OTP of specified length
func GenerateOTP(length int) (string, error) {
	max := new(big.Int)
	max.SetString(fmt.Sprintf("%s", pow10(length)), 10)

	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("%0*d", length, n), nil
}

func pow10(n int) string {
	s := "1"
	for i := 0; i < n; i++ {
		s += "0"
	}
	return s
}

// HMACSign signs data with HMAC-SHA256
func HMACSign(data, key string) string {
	mac := hmac.New(sha256.New, []byte(key))
	mac.Write([]byte(data))
	return hex.EncodeToString(mac.Sum(nil))
}

// HMACVerify verifies HMAC-SHA256 signature
func HMACVerify(data, signature, key string) bool {
	expected := HMACSign(data, key)
	return hmac.Equal([]byte(expected), []byte(signature))
}
