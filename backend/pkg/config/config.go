package config

import (
	"os"
	"strconv"
	"time"
)

type Config struct {
	Server   ServerConfig
	DB       DBConfig
	Redis    RedisConfig
	JWT      JWTConfig
	OTP      OTPConfig
	Rate     RateConfig
	Payment  PaymentConfig
	SMS      SMSConfig
	Email    EmailConfig
	Security SecurityConfig
}

type ServerConfig struct {
	Port      string
	AdminPort string
	Env       string
	LogLevel  string
}

type DBConfig struct {
	Host         string
	Port         string
	User         string
	Password     string
	Name         string
	SSLMode      string
	MaxOpenConns int
	MaxIdleConns int
}

type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
}

type JWTConfig struct {
	Secret          string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration
}

type OTPConfig struct {
	Length int
	TTL    time.Duration
}

type RateConfig struct {
	PerSecond int
	PerMinute int
}

type PaymentConfig struct {
	Gateway     string
	APIUrl      string
	APIKey      string
	APISecret   string
	CallbackURL string
}

type SMSConfig struct {
	APIKey   string
	Username string
	SenderID string
}

type EmailConfig struct {
	APIKey    string
	FromEmail string
	FromName  string
}

type SecurityConfig struct {
	EncryptionKey    string
	StepUpThreshold  float64
	TOTPIssuer       string
}

func Load() *Config {
	return &Config{
		Server: ServerConfig{
			Port:      getEnv("SERVER_PORT", "8080"),
			AdminPort: getEnv("ADMIN_SERVER_PORT", "8081"),
			Env:       getEnv("ENV", "development"),
			LogLevel:  getEnv("LOG_LEVEL", "debug"),
		},
		DB: DBConfig{
			Host:         getEnv("DB_HOST", "localhost"),
			Port:         getEnv("DB_PORT", "5432"),
			User:         getEnv("DB_USER", "savingplus"),
			Password:     getEnv("DB_PASSWORD", "savingplus_secret"),
			Name:         getEnv("DB_NAME", "savingplus"),
			SSLMode:      getEnv("DB_SSLMODE", "disable"),
			MaxOpenConns: getEnvInt("DB_MAX_OPEN_CONNS", 25),
			MaxIdleConns: getEnvInt("DB_MAX_IDLE_CONNS", 5),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     getEnv("REDIS_PORT", "6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       getEnvInt("REDIS_DB", 0),
		},
		JWT: JWTConfig{
			Secret:          getEnv("JWT_SECRET", "change-me-to-a-random-64-char-string"),
			AccessTokenTTL:  getEnvDuration("JWT_ACCESS_TOKEN_TTL", 15*time.Minute),
			RefreshTokenTTL: getEnvDuration("JWT_REFRESH_TOKEN_TTL", 7*24*time.Hour),
		},
		OTP: OTPConfig{
			Length: getEnvInt("OTP_LENGTH", 6),
			TTL:    getEnvDuration("OTP_TTL", 5*time.Minute),
		},
		Rate: RateConfig{
			PerSecond: getEnvInt("RATE_LIMIT_PER_SECOND", 30),
			PerMinute: getEnvInt("RATE_LIMIT_PER_MINUTE", 300),
		},
		Payment: PaymentConfig{
			Gateway:     getEnv("PAYMENT_GATEWAY", "mock"),
			APIUrl:      getEnv("CELLULANT_API_URL", ""),
			APIKey:      getEnv("CELLULANT_API_KEY", ""),
			APISecret:   getEnv("CELLULANT_API_SECRET", ""),
			CallbackURL: getEnv("CELLULANT_CALLBACK_URL", ""),
		},
		SMS: SMSConfig{
			APIKey:   getEnv("AT_API_KEY", ""),
			Username: getEnv("AT_USERNAME", "sandbox"),
			SenderID: getEnv("AT_SENDER_ID", "SavingPlus"),
		},
		Email: EmailConfig{
			APIKey:    getEnv("SENDGRID_API_KEY", ""),
			FromEmail: getEnv("SENDGRID_FROM_EMAIL", "noreply@savingplus.co.tz"),
			FromName:  getEnv("SENDGRID_FROM_NAME", "SavingPlus"),
		},
		Security: SecurityConfig{
			EncryptionKey:   getEnv("ENCRYPTION_KEY", ""),
			StepUpThreshold: getEnvFloat("STEPUP_THRESHOLD", 100000),
			TOTPIssuer:      getEnv("TOTP_ISSUER", "SavingPlus"),
		},
	}
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if val := os.Getenv(key); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			return i
		}
	}
	return fallback
}

func getEnvFloat(key string, fallback float64) float64 {
	if val := os.Getenv(key); val != "" {
		if f, err := strconv.ParseFloat(val, 64); err == nil {
			return f
		}
	}
	return fallback
}

func getEnvDuration(key string, fallback time.Duration) time.Duration {
	if val := os.Getenv(key); val != "" {
		if d, err := time.ParseDuration(val); err == nil {
			return d
		}
		// Try parsing as seconds (integer)
		if secs, err := strconv.Atoi(val); err == nil {
			return time.Duration(secs) * time.Second
		}
	}
	return fallback
}
