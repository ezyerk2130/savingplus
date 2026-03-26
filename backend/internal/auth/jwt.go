package auth

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
	TokenType    string `json:"token_type"`
}

type Claims struct {
	UserID string `json:"user_id"`
	Phone  string `json:"phone"`
	Role   string `json:"role,omitempty"`
	jwt.RegisteredClaims
}

type JWTService struct {
	secret          string
	accessTokenTTL  time.Duration
	refreshTokenTTL time.Duration
}

func NewJWTService(secret string, accessTTL, refreshTTL time.Duration) *JWTService {
	return &JWTService{
		secret:          secret,
		accessTokenTTL:  accessTTL,
		refreshTokenTTL: refreshTTL,
	}
}

func (s *JWTService) GenerateTokenPair(userID, phone, role string) (*TokenPair, string, error) {
	now := time.Now()

	// Access token
	accessClaims := &Claims{
		UserID: userID,
		Phone:  phone,
		Role:   role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(s.accessTokenTTL)),
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			Issuer:    "savingplus",
			Subject:   userID,
			ID:        uuid.New().String(),
		},
	}

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenStr, err := accessToken.SignedString([]byte(s.secret))
	if err != nil {
		return nil, "", fmt.Errorf("failed to sign access token: %w", err)
	}

	// Refresh token (opaque)
	refreshTokenRaw := uuid.New().String()
	refreshTokenHash := hashToken(refreshTokenRaw)

	return &TokenPair{
		AccessToken:  accessTokenStr,
		RefreshToken: refreshTokenRaw,
		ExpiresIn:    int64(s.accessTokenTTL.Seconds()),
		TokenType:    "Bearer",
	}, refreshTokenHash, nil
}

func (s *JWTService) ValidateAccessToken(tokenStr string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(s.secret), nil
	})
	if err != nil {
		return nil, fmt.Errorf("invalid token: %w", err)
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}

	return claims, nil
}

func (s *JWTService) RefreshTokenTTL() time.Duration {
	return s.refreshTokenTTL
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

func HashRefreshToken(token string) string {
	return hashToken(token)
}
