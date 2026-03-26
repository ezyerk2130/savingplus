package main

import (
	"database/sql"
	"fmt"
	"os"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/joho/godotenv"

	"github.com/savingplus/backend/pkg/crypto"
)

func main() {
	godotenv.Load()

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		getEnv("DB_HOST", "localhost"),
		getEnv("DB_PORT", "5432"),
		getEnv("DB_USER", "savingplus"),
		getEnv("DB_PASSWORD", "savingplus_secret"),
		getEnv("DB_NAME", "savingplus"),
		getEnv("DB_SSLMODE", "disable"),
	)

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		fmt.Println("DB error:", err)
		os.Exit(1)
	}
	defer db.Close()

	password := "Admin@123456"
	hash, err := crypto.HashPassword(password)
	if err != nil {
		fmt.Println("Hash error:", err)
		os.Exit(1)
	}

	// Update all three seed admin users with the real hash
	emails := []string{"admin@savingplus.co.tz", "support@savingplus.co.tz", "finance@savingplus.co.tz"}
	for _, email := range emails {
		_, err := db.Exec(`UPDATE admin_users SET password_hash = $1, mfa_enabled = FALSE WHERE email = $2`, hash, email)
		if err != nil {
			fmt.Printf("Failed to update %s: %v\n", email, err)
		} else {
			fmt.Printf("Updated %s\n", email)
		}
	}

	fmt.Println("\n=== Admin Login Credentials ===")
	fmt.Println("Super Admin:  admin@savingplus.co.tz   / Admin@123456  (role: super_admin)")
	fmt.Println("Support:      support@savingplus.co.tz / Admin@123456  (role: support)")
	fmt.Println("Finance:      finance@savingplus.co.tz / Admin@123456  (role: finance)")
	fmt.Println("MFA is disabled for dev — any 6-digit code (e.g. 000000) will work.")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
