package auth

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	log "github.com/sirupsen/logrus"

	"github.com/savingplus/backend/pkg/crypto"
)

type OTPService struct {
	redis  *redis.Client
	length int
	ttl    time.Duration
}

func NewOTPService(rdb *redis.Client, length int, ttl time.Duration) *OTPService {
	return &OTPService{
		redis:  rdb,
		length: length,
		ttl:    ttl,
	}
}

func (s *OTPService) SendOTP(ctx context.Context, phone string) error {
	code, err := crypto.GenerateOTP(s.length)
	if err != nil {
		return fmt.Errorf("failed to generate OTP: %w", err)
	}

	key := fmt.Sprintf("otp:%s", phone)
	if err := s.redis.Set(ctx, key, code, s.ttl).Err(); err != nil {
		return fmt.Errorf("failed to store OTP: %w", err)
	}

	// In production, send via SMS (Africa's Talking)
	// For development, log the OTP
	log.WithFields(log.Fields{
		"phone": phone,
		"otp":   code,
	}).Info("OTP generated (dev mode - would send SMS in production)")

	return nil
}

func (s *OTPService) VerifyOTP(ctx context.Context, phone, code string) (bool, error) {
	key := fmt.Sprintf("otp:%s", phone)

	stored, err := s.redis.Get(ctx, key).Result()
	if err == redis.Nil {
		return false, nil // OTP expired or not found
	}
	if err != nil {
		return false, fmt.Errorf("failed to retrieve OTP: %w", err)
	}

	if stored != code {
		return false, nil
	}

	// Delete OTP after successful verification
	s.redis.Del(ctx, key)
	return true, nil
}
