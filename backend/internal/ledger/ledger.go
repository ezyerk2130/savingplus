package ledger

import (
	"database/sql"
	"fmt"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// CreditWallet performs a double-entry credit to a user's wallet
func CreditWallet(db *sql.DB, ctx *gin.Context, walletID, txnID string, amount float64, description string) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Lock wallet row for update
	var balance float64
	err = tx.QueryRowContext(ctx,
		`SELECT available_balance FROM wallets WHERE id = $1 FOR UPDATE`,
		walletID,
	).Scan(&balance)
	if err != nil {
		return err
	}

	newBalance := balance + amount

	_, err = tx.ExecContext(ctx,
		`UPDATE wallets SET available_balance = $1 WHERE id = $2`,
		newBalance, walletID,
	)
	if err != nil {
		return err
	}

	// Create ledger entry
	_, err = tx.ExecContext(ctx,
		`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
		 VALUES ($1, $2, $3, 'credit', $4, $5, $6)`,
		uuid.New(), txnID, walletID, amount, newBalance, description,
	)
	if err != nil {
		return err
	}

	return tx.Commit()
}

// DebitWallet performs a double-entry debit from a user's wallet
func DebitWallet(db *sql.DB, ctx *gin.Context, walletID, txnID string, amount float64, description string) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var balance float64
	err = tx.QueryRowContext(ctx,
		`SELECT available_balance FROM wallets WHERE id = $1 FOR UPDATE`,
		walletID,
	).Scan(&balance)
	if err != nil {
		return err
	}

	if balance < amount {
		return fmt.Errorf("insufficient balance")
	}

	newBalance := balance - amount

	_, err = tx.ExecContext(ctx,
		`UPDATE wallets SET available_balance = $1 WHERE id = $2`,
		newBalance, walletID,
	)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx,
		`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
		 VALUES ($1, $2, $3, 'debit', $4, $5, $6)`,
		uuid.New(), txnID, walletID, amount, newBalance, description,
	)
	if err != nil {
		return err
	}

	return tx.Commit()
}
