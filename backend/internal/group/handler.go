package group

import (
	"database/sql"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	apperr "github.com/savingplus/backend/internal/errors"
	"github.com/savingplus/backend/pkg/logger"
	"github.com/savingplus/backend/pkg/response"
)

type Handler struct {
	db *sql.DB
}

func NewHandler(db *sql.DB) *Handler {
	return &Handler{db: db}
}

type CreateGroupRequest struct {
	Name               string  `json:"name" binding:"required,min=1,max=100"`
	Description        string  `json:"description"`
	Type               string  `json:"type" binding:"required,oneof=upatu goal challenge"`
	ContributionAmount float64 `json:"contribution_amount" binding:"required,gt=0"`
	Frequency          string  `json:"frequency" binding:"required,oneof=daily weekly biweekly monthly"`
	MaxMembers         int     `json:"max_members" binding:"required,min=2,max=50"`
}

type GroupResponse struct {
	ID                 string  `json:"id"`
	Name               string  `json:"name"`
	Description        *string `json:"description,omitempty"`
	Type               string  `json:"type"`
	Currency           string  `json:"currency"`
	ContributionAmount string  `json:"contribution_amount"`
	Frequency          string  `json:"frequency"`
	MaxMembers         int     `json:"max_members"`
	CurrentRound       int     `json:"current_round"`
	TotalRounds        *int    `json:"total_rounds,omitempty"`
	Status             string  `json:"status"`
	InviteCode         string  `json:"invite_code"`
	StartDate          *string `json:"start_date,omitempty"`
	NextPayoutDate     *string `json:"next_payout_date,omitempty"`
	CreatedAt          string  `json:"created_at"`
	MemberCount        int     `json:"member_count"`
}

type MemberResponse struct {
	ID             string `json:"id"`
	UserID         string `json:"user_id"`
	Role           string `json:"role"`
	PayoutPosition *int   `json:"payout_position,omitempty"`
	Status         string `json:"status"`
	JoinedAt       string `json:"joined_at"`
}

type ContributionResponse struct {
	ID          string  `json:"id"`
	UserID      string  `json:"user_id"`
	RoundNumber int     `json:"round_number"`
	Amount      string  `json:"amount"`
	Status      string  `json:"status"`
	PaidAt      *string `json:"paid_at,omitempty"`
	CreatedAt   string  `json:"created_at"`
}

// CreateGroup creates a new savings group with the creator as admin member.
func (h *Handler) CreateGroup(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	var req CreateGroupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin create group transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	groupID := uuid.New()
	var desc *string
	if req.Description != "" {
		desc = &req.Description
	}

	// Create the group
	if _, err = tx.ExecContext(c,
		`INSERT INTO savings_groups (id, name, description, type, created_by, contribution_amount, frequency, max_members)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		groupID, req.Name, desc, req.Type, userID, req.ContributionAmount, req.Frequency, req.MaxMembers,
	); err != nil {
		log.WithError(err).Error("Failed to create savings group")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Add creator as admin member with payout_position=1
	memberID := uuid.New()
	if _, err = tx.ExecContext(c,
		`INSERT INTO group_members (id, group_id, user_id, role, payout_position)
		 VALUES ($1, $2, $3, 'admin', 1)`,
		memberID, groupID, userID,
	); err != nil {
		log.WithError(err).Error("Failed to add creator as group admin")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit create group transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Fetch the generated invite_code
	var inviteCode string
	h.db.QueryRowContext(c, `SELECT invite_code FROM savings_groups WHERE id = $1`, groupID).Scan(&inviteCode)

	c.JSON(http.StatusCreated, gin.H{
		"group_id":    groupID.String(),
		"name":        req.Name,
		"type":        req.Type,
		"invite_code": inviteCode,
		"message":     "Group created successfully. Share the invite code with members.",
	})
}

// ListGroups lists all groups the user belongs to.
func (h *Handler) ListGroups(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	rows, err := h.db.QueryContext(c,
		`SELECT g.id, g.name, g.description, g.type, g.currency, g.contribution_amount, g.frequency,
		 g.max_members, g.current_round, g.total_rounds, g.status, g.invite_code, g.start_date, g.next_payout_date, g.created_at,
		 (SELECT COUNT(*) FROM group_members gm2 WHERE gm2.group_id = g.id AND gm2.status = 'active') AS member_count
		 FROM savings_groups g
		 JOIN group_members gm ON g.id = gm.group_id
		 WHERE gm.user_id = $1 AND gm.status = 'active'
		 ORDER BY g.created_at DESC`,
		userID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query user groups")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	var groups []GroupResponse
	for rows.Next() {
		var g GroupResponse
		var desc sql.NullString
		var totalRounds sql.NullInt32
		var startDate, nextPayout sql.NullTime
		var contribAmt float64

		err := rows.Scan(&g.ID, &g.Name, &desc, &g.Type, &g.Currency, &contribAmt, &g.Frequency,
			&g.MaxMembers, &g.CurrentRound, &totalRounds, &g.Status, &g.InviteCode, &startDate, &nextPayout, &g.CreatedAt, &g.MemberCount)
		if err != nil {
			log.WithError(err).Error("Failed to scan group row")
			continue
		}

		g.Description = response.NullStr(desc)
		g.ContributionAmount = response.FormatMoney(contribAmt)
		g.TotalRounds = response.NullInt(totalRounds)
		g.StartDate = response.NullTime(startDate)
		g.NextPayoutDate = response.NullTime(nextPayout)

		groups = append(groups, g)
	}

	c.JSON(http.StatusOK, gin.H{"groups": response.EmptySlice(groups), "total": len(response.EmptySlice(groups))})
}

// GetGroup returns group detail with members and contribution history.
func (h *Handler) GetGroup(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	groupID := c.Param("id")

	// Verify user is a member
	var memberStatus string
	err := h.db.QueryRowContext(c,
		`SELECT status FROM group_members WHERE group_id = $1 AND user_id = $2`,
		groupID, userID,
	).Scan(&memberStatus)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to check group membership")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Get group details
	var g GroupResponse
	var desc sql.NullString
	var totalRounds sql.NullInt32
	var startDate, nextPayout sql.NullTime
	var contribAmt float64

	err = h.db.QueryRowContext(c,
		`SELECT id, name, description, type, currency, contribution_amount, frequency,
		 max_members, current_round, total_rounds, status, start_date, next_payout_date, created_at
		 FROM savings_groups WHERE id = $1`,
		groupID,
	).Scan(&g.ID, &g.Name, &desc, &g.Type, &g.Currency, &contribAmt, &g.Frequency,
		&g.MaxMembers, &g.CurrentRound, &totalRounds, &g.Status, &startDate, &nextPayout, &g.CreatedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get group details")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	g.Description = response.NullStr(desc)
	g.ContributionAmount = response.FormatMoney(contribAmt)
	g.TotalRounds = response.NullInt(totalRounds)
	g.StartDate = response.NullTime(startDate)
	g.NextPayoutDate = response.NullTime(nextPayout)

	// Get members
	memberRows, err := h.db.QueryContext(c,
		`SELECT id, user_id, role, payout_position, status, joined_at
		 FROM group_members WHERE group_id = $1 ORDER BY payout_position ASC NULLS LAST`,
		groupID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query group members")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer memberRows.Close()

	var members []MemberResponse
	for memberRows.Next() {
		var m MemberResponse
		var payoutPos sql.NullInt32
		if err := memberRows.Scan(&m.ID, &m.UserID, &m.Role, &payoutPos, &m.Status, &m.JoinedAt); err != nil {
			log.WithError(err).Error("Failed to scan member row")
			continue
		}
		m.PayoutPosition = response.NullInt(payoutPos)
		members = append(members, m)
	}

	// Get contributions
	contribRows, err := h.db.QueryContext(c,
		`SELECT id, user_id, round_number, amount, status, paid_at, created_at
		 FROM group_contributions WHERE group_id = $1 ORDER BY round_number DESC, created_at DESC LIMIT 50`,
		groupID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query group contributions")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer contribRows.Close()

	var contributions []ContributionResponse
	for contribRows.Next() {
		var cr ContributionResponse
		var amt float64
		var paidAt sql.NullTime
		if err := contribRows.Scan(&cr.ID, &cr.UserID, &cr.RoundNumber, &amt, &cr.Status, &paidAt, &cr.CreatedAt); err != nil {
			log.WithError(err).Error("Failed to scan contribution row")
			continue
		}
		cr.Amount = response.FormatMoney(amt)
		cr.PaidAt = response.NullTime(paidAt)
		contributions = append(contributions, cr)
	}

	c.JSON(http.StatusOK, gin.H{
		"group":         g,
		"members":       response.EmptySlice(members),
		"contributions": response.EmptySlice(contributions),
	})
}

// JoinGroup allows a user to join a forming group.
func (h *Handler) JoinGroup(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	groupID := c.Param("id")

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin join group transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	// Get group with lock
	var groupStatus string
	var maxMembers int
	err = tx.QueryRowContext(c,
		`SELECT status, max_members FROM savings_groups WHERE id = $1 FOR UPDATE`,
		groupID,
	).Scan(&groupStatus, &maxMembers)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get group for joining")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if groupStatus != "forming" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Group is not accepting new members", "status": groupStatus})
		return
	}

	// Check if already a member
	var existingID string
	err = tx.QueryRowContext(c,
		`SELECT id FROM group_members WHERE group_id = $1 AND user_id = $2`,
		groupID, userID,
	).Scan(&existingID)
	if err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "You are already a member of this group"})
		return
	}
	if err != sql.ErrNoRows {
		log.WithError(err).Error("Failed to check existing membership")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Count current active members
	var currentMembers int
	err = tx.QueryRowContext(c,
		`SELECT COUNT(*) FROM group_members WHERE group_id = $1 AND status = 'active'`,
		groupID,
	).Scan(&currentMembers)
	if err != nil {
		log.WithError(err).Error("Failed to count group members")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if currentMembers >= maxMembers {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Group is full"})
		return
	}

	// Assign next payout position
	nextPosition := currentMembers + 1
	memberID := uuid.New()
	if _, err = tx.ExecContext(c,
		`INSERT INTO group_members (id, group_id, user_id, role, payout_position)
		 VALUES ($1, $2, $3, 'member', $4)`,
		memberID, groupID, userID, nextPosition,
	); err != nil {
		log.WithError(err).Error("Failed to add member to group")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit join group transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":         "Joined group successfully",
		"payout_position": nextPosition,
	})
}

// LeaveGroup allows a user to leave a forming group.
func (h *Handler) LeaveGroup(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	groupID := c.Param("id")

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin leave group transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	// Get group status
	var groupStatus string
	err = tx.QueryRowContext(c,
		`SELECT status FROM savings_groups WHERE id = $1 FOR UPDATE`,
		groupID,
	).Scan(&groupStatus)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get group for leaving")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if groupStatus != "forming" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot leave an active group"})
		return
	}

	// Verify membership and not admin
	var memberRole string
	err = tx.QueryRowContext(c,
		`SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2 AND status = 'active'`,
		groupID, userID,
	).Scan(&memberRole)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "You are not an active member of this group"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to check membership for leaving")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if memberRole == "admin" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Group admin cannot leave. Transfer admin role or dissolve the group."})
		return
	}

	// Mark member as left
	if _, err = tx.ExecContext(c,
		`UPDATE group_members SET status = 'left' WHERE group_id = $1 AND user_id = $2`,
		groupID, userID,
	); err != nil {
		log.WithError(err).Error("Failed to update member status")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit leave group transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Left group successfully"})
}

// Contribute makes a contribution to the group for the current round.
func (h *Handler) Contribute(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	groupID := c.Param("id")

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin contribution transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	// Get group details with lock
	var groupStatus, currency string
	var contributionAmount float64
	var currentRound int
	err = tx.QueryRowContext(c,
		`SELECT status, currency, contribution_amount, current_round FROM savings_groups WHERE id = $1 FOR UPDATE`,
		groupID,
	).Scan(&groupStatus, &currency, &contributionAmount, &currentRound)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": apperr.ErrNotFound.Message})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get group for contribution")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if groupStatus != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Group is not active", "status": groupStatus})
		return
	}

	// Verify user is an active member
	var memberStatus string
	err = tx.QueryRowContext(c,
		`SELECT status FROM group_members WHERE group_id = $1 AND user_id = $2`,
		groupID, userID,
	).Scan(&memberStatus)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to check membership for contribution")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	if memberStatus != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Your membership is not active"})
		return
	}

	// Check if already contributed this round
	var existingContrib string
	err = tx.QueryRowContext(c,
		`SELECT id FROM group_contributions WHERE group_id = $1 AND user_id = $2 AND round_number = $3 AND status = 'paid'`,
		groupID, userID, currentRound,
	).Scan(&existingContrib)
	if err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "You have already contributed for this round"})
		return
	}
	if err != sql.ErrNoRows {
		log.WithError(err).Error("Failed to check existing contribution")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Get and lock wallet
	var walletID string
	var available float64
	err = tx.QueryRowContext(c,
		`SELECT id, available_balance FROM wallets WHERE user_id = $1 AND currency = $2 FOR UPDATE`,
		userID, currency,
	).Scan(&walletID, &available)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("No %s wallet found", currency)})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to get wallet for contribution")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if available < contributionAmount {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrInsufficientBalance.Message})
		return
	}

	// Debit wallet
	newBalance := available - contributionAmount
	if _, err = tx.ExecContext(c, `UPDATE wallets SET available_balance = $1 WHERE id = $2`, newBalance, walletID); err != nil {
		log.WithError(err).Error("Failed to debit wallet for contribution")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create transaction
	txnID := uuid.New()
	ref := fmt.Sprintf("GRP-%s-%d", txnID.String()[:8], time.Now().UnixMilli())
	if _, err = tx.ExecContext(c,
		`INSERT INTO transactions (id, user_id, wallet_id, type, status, amount, currency, reference, description, completed_at)
		 VALUES ($1, $2, $3, 'group_contribution', 'completed', $4, $5, $6, $7, NOW())`,
		txnID, userID, walletID, contributionAmount, currency, ref, fmt.Sprintf("Group contribution round %d", currentRound),
	); err != nil {
		log.WithError(err).Error("Failed to create contribution transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create ledger entry
	if _, err = tx.ExecContext(c,
		`INSERT INTO ledger_entries (id, transaction_id, wallet_id, entry_type, amount, balance_after, description)
		 VALUES ($1, $2, $3, 'debit', $4, $5, $6)`,
		uuid.New(), txnID, walletID, contributionAmount, newBalance, "Group contribution",
	); err != nil {
		log.WithError(err).Error("Failed to create ledger entry for contribution")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Create group contribution record
	contribID := uuid.New()
	if _, err = tx.ExecContext(c,
		`INSERT INTO group_contributions (id, group_id, user_id, round_number, amount, status, paid_at)
		 VALUES ($1, $2, $3, $4, $5, 'paid', NOW())`,
		contribID, groupID, userID, currentRound, contributionAmount,
	); err != nil {
		log.WithError(err).Error("Failed to create group contribution record")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit contribution transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":        "Contribution paid successfully",
		"contribution_id": contribID.String(),
		"transaction_id": txnID.String(),
		"round":          currentRound,
		"amount":         response.FormatMoney(contributionAmount),
		"wallet_balance": response.FormatMoney(newBalance),
	})
}

// StartGroup starts a forming group, setting it to active.
func (h *Handler) StartGroup(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")
	groupID := c.Param("id")

	tx, err := h.db.BeginTx(c, nil)
	if err != nil {
		log.WithError(err).Error("Failed to begin start group transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer tx.Rollback()

	// Verify the user is admin of this group
	var memberRole string
	err = tx.QueryRowContext(c,
		`SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2 AND status = 'active'`,
		groupID, userID,
	).Scan(&memberRole)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to check admin role")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if memberRole != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Only the group admin can start the group"})
		return
	}

	// Get group with lock
	var groupStatus, frequency string
	var maxMembers int
	err = tx.QueryRowContext(c,
		`SELECT status, frequency, max_members FROM savings_groups WHERE id = $1 FOR UPDATE`,
		groupID,
	).Scan(&groupStatus, &frequency, &maxMembers)
	if err != nil {
		log.WithError(err).Error("Failed to get group for starting")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if groupStatus != "forming" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Group is not in forming state", "status": groupStatus})
		return
	}

	// Count active members
	var activeMembers int
	err = tx.QueryRowContext(c,
		`SELECT COUNT(*) FROM group_members WHERE group_id = $1 AND status = 'active'`,
		groupID,
	).Scan(&activeMembers)
	if err != nil {
		log.WithError(err).Error("Failed to count active members")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if activeMembers < 2 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "At least 2 members required to start the group", "current_members": activeMembers})
		return
	}

	// Calculate next payout date based on frequency
	now := time.Now()
	startDate := now
	var nextPayoutDate time.Time
	switch frequency {
	case "daily":
		nextPayoutDate = startDate.AddDate(0, 0, 1)
	case "weekly":
		nextPayoutDate = startDate.AddDate(0, 0, 7)
	case "biweekly":
		nextPayoutDate = startDate.AddDate(0, 0, 14)
	case "monthly":
		nextPayoutDate = startDate.AddDate(0, 1, 0)
	default:
		nextPayoutDate = startDate.AddDate(0, 1, 0)
	}

	// Update group
	if _, err = tx.ExecContext(c,
		`UPDATE savings_groups SET status = 'active', current_round = 1, total_rounds = $1,
		 start_date = $2, next_payout_date = $3 WHERE id = $4`,
		activeMembers, startDate.Format("2006-01-02"), nextPayoutDate.Format("2006-01-02"), groupID,
	); err != nil {
		log.WithError(err).Error("Failed to update group to active")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := tx.Commit(); err != nil {
		log.WithError(err).Error("Failed to commit start group transaction")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":          "Group started successfully",
		"status":           "active",
		"current_round":    1,
		"total_rounds":     activeMembers,
		"start_date":       startDate.Format("2006-01-02"),
		"next_payout_date": nextPayoutDate.Format("2006-01-02"),
	})
}

// ListAllGroups returns all savings groups (admin view, no user filter).
func (h *Handler) ListAllGroups(c *gin.Context) {
	log := logger.Ctx(c)
	p := response.GetPagination(c, 20)

	var total int
	if err := h.db.QueryRowContext(c, `SELECT COUNT(*) FROM savings_groups`).Scan(&total); err != nil {
		log.WithError(err).Warn("Failed to count groups")
	}

	rows, err := h.db.QueryContext(c,
		`SELECT sg.id, sg.name, sg.type, sg.currency, sg.contribution_amount, sg.frequency,
		        sg.max_members, sg.current_round, sg.status, sg.created_at,
		        (SELECT COUNT(*) FROM group_members gm WHERE gm.group_id = sg.id AND gm.status = 'active') AS member_count
		 FROM savings_groups sg ORDER BY sg.created_at DESC LIMIT $1 OFFSET $2`,
		p.PageSize, p.Offset,
	)
	if err != nil {
		log.WithError(err).Error("Failed to list all groups")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type AdminGroup struct {
		ID                 string `json:"id"`
		Name               string `json:"name"`
		Type               string `json:"type"`
		Currency           string `json:"currency"`
		ContributionAmount string `json:"contribution_amount"`
		Frequency          string `json:"frequency"`
		MaxMembers         int    `json:"max_members"`
		MemberCount        int    `json:"member_count"`
		CurrentRound       int    `json:"current_round"`
		Status             string `json:"status"`
		CreatedAt          string `json:"created_at"`
	}

	var groups []AdminGroup
	for rows.Next() {
		var g AdminGroup
		var amount float64
		if err := rows.Scan(&g.ID, &g.Name, &g.Type, &g.Currency, &amount, &g.Frequency,
			&g.MaxMembers, &g.CurrentRound, &g.Status, &g.CreatedAt, &g.MemberCount); err != nil {
			continue
		}
		g.ContributionAmount = response.FormatMoney(amount)
		groups = append(groups, g)
	}

	response.PagedList(c, "groups", response.EmptySlice(groups), p, total)
}

// JoinByCode allows a user to join a group using a 6-digit invite code.
func (h *Handler) JoinByCode(c *gin.Context) {
	log := logger.Ctx(c)
	userID := c.GetString("user_id")

	var req struct {
		InviteCode string `json:"invite_code" binding:"required,len=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": apperr.ErrBadRequest.Message, "detail": err.Error()})
		return
	}

	// Find group by invite code
	var groupID, groupStatus string
	var maxMembers int
	err := h.db.QueryRowContext(c,
		`SELECT id, status, max_members FROM savings_groups WHERE invite_code = $1`,
		req.InviteCode,
	).Scan(&groupID, &groupStatus, &maxMembers)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "Invalid invite code. No group found."})
		return
	}
	if err != nil {
		log.WithError(err).Error("Failed to find group by invite code")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if groupStatus != "forming" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "This group is no longer accepting new members"})
		return
	}

	// Check if already a member
	var exists bool
	h.db.QueryRowContext(c,
		`SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2 AND status = 'active')`,
		groupID, userID,
	).Scan(&exists)
	if exists {
		c.JSON(http.StatusConflict, gin.H{"error": "You are already a member of this group"})
		return
	}

	// Check member count
	var memberCount int
	h.db.QueryRowContext(c,
		`SELECT COUNT(*) FROM group_members WHERE group_id = $1 AND status = 'active'`,
		groupID,
	).Scan(&memberCount)
	if memberCount >= maxMembers {
		c.JSON(http.StatusBadRequest, gin.H{"error": "This group is full"})
		return
	}

	// Join
	memberID := uuid.New()
	payoutPos := memberCount + 1
	if _, err = h.db.ExecContext(c,
		`INSERT INTO group_members (id, group_id, user_id, role, payout_position) VALUES ($1, $2, $3, 'member', $4)`,
		memberID, groupID, userID, payoutPos,
	); err != nil {
		log.WithError(err).Error("Failed to join group by code")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Return group preview
	var name, groupType string
	var contribAmt float64
	var frequency string
	h.db.QueryRowContext(c,
		`SELECT name, type, contribution_amount, frequency FROM savings_groups WHERE id = $1`,
		groupID,
	).Scan(&name, &groupType, &contribAmt, &frequency)

	c.JSON(http.StatusOK, gin.H{
		"message":             "Successfully joined the group!",
		"group_id":            groupID,
		"group_name":          name,
		"type":                groupType,
		"contribution_amount": response.FormatMoney(contribAmt),
		"frequency":           frequency,
		"member_count":        memberCount + 1,
	})
}

// LookupByCode returns group preview info without joining (for the "Join a Circle" bottom sheet).
func (h *Handler) LookupByCode(c *gin.Context) {
	code := c.Query("code")
	if len(code) != 6 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invite code must be 6 digits"})
		return
	}

	var groupID, name, groupType, frequency, status string
	var contribAmt float64
	var maxMembers int
	err := h.db.QueryRowContext(c,
		`SELECT id, name, type, contribution_amount, frequency, max_members, status FROM savings_groups WHERE invite_code = $1`,
		code,
	).Scan(&groupID, &name, &groupType, &contribAmt, &frequency, &maxMembers, &status)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "No group found with this code"})
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	var memberCount int
	h.db.QueryRowContext(c, `SELECT COUNT(*) FROM group_members WHERE group_id = $1 AND status = 'active'`, groupID).Scan(&memberCount)

	c.JSON(http.StatusOK, gin.H{
		"group_id":            groupID,
		"name":                name,
		"type":                groupType,
		"contribution_amount": response.FormatMoney(contribAmt),
		"frequency":           frequency,
		"max_members":         maxMembers,
		"member_count":        memberCount,
		"status":              status,
	})
}
