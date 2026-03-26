package user

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"

	apperr "github.com/savingplus/backend/internal/errors"
)

type KYCUploadResponse struct {
	DocumentID string `json:"document_id"`
	Status     string `json:"status"`
	Message    string `json:"message"`
}

func (h *Handler) UploadKYCDocument(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": apperr.ErrUnauthorized.Message})
		return
	}

	docType := c.PostForm("document_type")
	validTypes := map[string]bool{
		"national_id": true, "passport": true, "driving_license": true,
		"voter_id": true, "selfie": true, "proof_of_address": true,
	}
	if !validTypes[docType] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid document type"})
		return
	}

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "File is required"})
		return
	}
	defer file.Close()

	// Validate file size (max 10MB)
	if header.Size > 10*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "File size exceeds 10MB limit"})
		return
	}

	// Read file and compute hash
	data, err := io.ReadAll(file)
	if err != nil {
		log.WithError(err).Error("Failed to read uploaded file")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	hash := sha256.Sum256(data)
	fileHash := hex.EncodeToString(hash[:])

	// Save file
	docID := uuid.New()
	ext := filepath.Ext(header.Filename)
	filePath := fmt.Sprintf("uploads/kyc/%s/%s%s", userID, docID.String(), ext)

	if err := os.MkdirAll(filepath.Dir(filePath), 0750); err != nil {
		log.WithError(err).Error("Failed to create upload directory")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	if err := os.WriteFile(filePath, data, 0640); err != nil {
		log.WithError(err).Error("Failed to save file")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Insert KYC document record
	_, err = h.db.ExecContext(c,
		`INSERT INTO kyc_documents (id, user_id, document_type, file_path, file_hash) VALUES ($1, $2, $3, $4, $5)`,
		docID, userID, docType, filePath, fileHash,
	)
	if err != nil {
		log.WithError(err).Error("Failed to insert KYC document")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Update user KYC status if it was pending
	h.db.ExecContext(c,
		`UPDATE users SET kyc_status = 'submitted' WHERE id = $1 AND kyc_status = 'pending'`,
		userID,
	)

	c.JSON(http.StatusCreated, KYCUploadResponse{
		DocumentID: docID.String(),
		Status:     "pending",
		Message:    "Document uploaded successfully and pending review",
	})
}

func (h *Handler) GetKYCStatus(c *gin.Context) {
	userID := c.GetString("user_id")

	var kycStatus string
	var kycTier int
	err := h.db.QueryRowContext(c,
		`SELECT kyc_status, kyc_tier FROM users WHERE id = $1`,
		userID,
	).Scan(&kycStatus, &kycTier)
	if err != nil {
		log.WithError(err).Error("Failed to get KYC status")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}

	// Get documents
	rows, err := h.db.QueryContext(c,
		`SELECT id, document_type, status, rejection_reason, created_at
		 FROM kyc_documents WHERE user_id = $1 ORDER BY created_at DESC`,
		userID,
	)
	if err != nil {
		log.WithError(err).Error("Failed to query KYC documents")
		c.JSON(http.StatusInternalServerError, gin.H{"error": apperr.ErrInternal.Message})
		return
	}
	defer rows.Close()

	type Doc struct {
		ID              string  `json:"id"`
		DocumentType    string  `json:"document_type"`
		Status          string  `json:"status"`
		RejectionReason *string `json:"rejection_reason,omitempty"`
		CreatedAt       string  `json:"created_at"`
	}

	var docs []Doc
	for rows.Next() {
		var d Doc
		var rejReason sql.NullString
		if err := rows.Scan(&d.ID, &d.DocumentType, &d.Status, &rejReason, &d.CreatedAt); err != nil {
			continue
		}
		if rejReason.Valid {
			d.RejectionReason = &rejReason.String
		}
		docs = append(docs, d)
	}

	c.JSON(http.StatusOK, gin.H{
		"kyc_status": kycStatus,
		"kyc_tier":   kycTier,
		"documents":  docs,
	})
}
