package main

import (
	"context"
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
	log "github.com/sirupsen/logrus"

	"github.com/savingplus/backend/internal/admin"
	"github.com/savingplus/backend/internal/auth"
	"github.com/savingplus/backend/internal/content"
	"github.com/savingplus/backend/internal/db"
	"github.com/savingplus/backend/internal/group"
	"github.com/savingplus/backend/internal/insurance"
	"github.com/savingplus/backend/internal/investment"
	"github.com/savingplus/backend/internal/loan"
	"github.com/savingplus/backend/internal/middleware"
	"github.com/savingplus/backend/internal/notification"
	"github.com/savingplus/backend/internal/payment"
	"github.com/savingplus/backend/internal/queue"
	"github.com/savingplus/backend/internal/savings"
	"github.com/savingplus/backend/internal/transaction"
	"github.com/savingplus/backend/internal/user"
	"github.com/savingplus/backend/internal/wallet"
	"github.com/savingplus/backend/pkg/config"
	"github.com/savingplus/backend/pkg/logger"
)

func main() {
	// Load .env
	godotenv.Load()

	// Load config
	cfg := config.Load()

	// Configure logging
	setupLogging(cfg.Server.LogLevel)

	log.Info("Starting SavingPlus API server")

	// Connect to PostgreSQL
	database, err := db.Connect()
	if err != nil {
		log.WithError(err).Fatal("Failed to connect to database")
	}
	defer db.Close()

	// Run migrations on startup
	if err := runMigrations(database); err != nil {
		log.WithError(err).Warn("Migration check failed - ensure schema is up to date")
	}

	// Connect to Redis
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", cfg.Redis.Host, cfg.Redis.Port),
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.DB,
	})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		log.WithError(err).Fatal("Failed to connect to Redis")
	}
	defer rdb.Close()
	log.Info("Connected to Redis")

	// Initialize payment gateway
	gw, err := payment.NewGateway(cfg.Payment.Gateway)
	if err != nil {
		log.WithError(err).Fatal("Failed to initialize payment gateway")
	}

	// Initialize services
	jwtSvc := auth.NewJWTService(cfg.JWT.Secret, cfg.JWT.AccessTokenTTL, cfg.JWT.RefreshTokenTTL)
	otpSvc := auth.NewOTPService(rdb, cfg.OTP.Length, cfg.OTP.TTL)

	// Start Asynq worker and queue client
	redisAddr := fmt.Sprintf("%s:%s", cfg.Redis.Host, cfg.Redis.Port)
	queueClient := queue.NewClient(redisAddr)
	defer queueClient.Close()
	worker := queue.NewWorker(database, gw)
	workerSrv := queue.StartWorkerServer(redisAddr, worker)
	defer workerSrv.Stop()

	// Initialize handlers
	authHandler := auth.NewHandler(database, jwtSvc, otpSvc, cfg)
	userHandler := user.NewHandler(database, cfg)
	walletHandler := wallet.NewHandler(database, rdb, queueClient, cfg)
	txnHandler := transaction.NewHandler(database)
	savingsHandler := savings.NewHandler(database)
	notifHandler := notification.NewHandler(database, cfg)
	webhookHandler := payment.NewWebhookHandler(database, gw)
	investmentHandler := investment.NewHandler(database)
	groupHandler := group.NewHandler(database)
	insuranceHandler := insurance.NewHandler(database)
	loanHandler := loan.NewHandler(database)
	contentHandler := content.NewHandler(database)
	adminHandler := admin.NewHandler(database, jwtSvc, cfg)

	// Start scheduler for recurring jobs
	scheduler := queue.StartScheduler(redisAddr)
	defer scheduler.Shutdown()

	// Setup Gin
	if cfg.Server.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// ========================================
	// CUSTOMER API SERVER
	// ========================================
	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(middleware.CORS())
	router.Use(middleware.SecurityHeaders())
	router.Use(middleware.RequestID())
	router.Use(logger.RequestLogger(logger.FilterLevel(cfg.Server.LogLevel)))
	router.Use(middleware.RateLimit(rdb, cfg.Rate.PerSecond, cfg.Rate.PerMinute))

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "service": "savingplus-api", "time": time.Now().UTC()})
	})

	// API v1
	v1 := router.Group("/api/v1")
	{
		// Public routes (no auth required)
		authRoutes := v1.Group("/auth")
		{
			authRoutes.POST("/register", authHandler.Register)
			authRoutes.POST("/login", authHandler.Login)
			authRoutes.POST("/refresh", authHandler.RefreshToken)
			authRoutes.POST("/verify-otp", authHandler.VerifyOTP)
			authRoutes.POST("/send-otp", authHandler.SendOTP)
		}

		// Webhook routes (public, called by payment gateway)
		webhooks := v1.Group("/webhooks")
		{
			webhooks.POST("/payment", webhookHandler.HandlePaymentWebhook)
		}

		// Protected routes
		protected := v1.Group("")
		protected.Use(middleware.AuthRequired(jwtSvc))
		protected.Use(middleware.AuditLog(database, cfg.JWT.Secret))
		{
			// Auth (authenticated)
			protected.POST("/auth/change-password", authHandler.ChangePassword)
			protected.POST("/auth/change-pin", authHandler.ChangePIN)
			protected.POST("/auth/logout", authHandler.Logout)

			// User profile
			protected.GET("/profile", userHandler.GetProfile)
			protected.PUT("/profile", userHandler.UpdateProfile)
			protected.GET("/profile/limits", userHandler.GetTierLimits)

			// Wallet
			protected.GET("/wallet/balance", walletHandler.GetBalance)
			protected.POST("/wallet/deposit", walletHandler.Deposit)
			protected.POST("/wallet/withdraw", walletHandler.Withdraw)

			// Transactions
			protected.GET("/transactions", txnHandler.List)
			protected.GET("/transactions/:id", txnHandler.GetByID)

			// Savings
			protected.POST("/savings/plan", savingsHandler.CreatePlan)
			protected.GET("/savings/plans", savingsHandler.ListPlans)
			protected.GET("/savings/plans/:id", savingsHandler.GetPlan)
			protected.POST("/savings/plans/:id/deposit", savingsHandler.DepositToPlan)
			protected.POST("/savings/plans/:id/withdraw", savingsHandler.WithdrawFromPlan)
			protected.POST("/savings/plans/:id/cancel", savingsHandler.CancelPlan)

			// KYC
			protected.POST("/kyc/upload", userHandler.UploadKYCDocument)
			protected.GET("/kyc/status", userHandler.GetKYCStatus)

			// Notifications
			protected.GET("/notifications", notifHandler.ListNotifications)
			protected.PUT("/notifications/:id/read", notifHandler.MarkRead)
			protected.PUT("/notifications/read-all", notifHandler.MarkAllRead)

			// Investments (Investify TZ)
			protected.GET("/investments/products", investmentHandler.ListProducts)
			protected.GET("/investments/products/:id", investmentHandler.GetProduct)
			protected.POST("/investments", investmentHandler.Invest)
			protected.GET("/investments", investmentHandler.ListInvestments)
			protected.POST("/investments/:id/withdraw", investmentHandler.WithdrawInvestment)

			// Group Savings (Upatu)
			protected.POST("/groups", groupHandler.CreateGroup)
			protected.GET("/groups", groupHandler.ListGroups)
			protected.GET("/groups/:id", groupHandler.GetGroup)
			protected.POST("/groups/:id/join", groupHandler.JoinGroup)
			protected.POST("/groups/:id/leave", groupHandler.LeaveGroup)
			protected.POST("/groups/:id/contribute", groupHandler.Contribute)
			protected.POST("/groups/:id/start", groupHandler.StartGroup)

			// Insurance
			protected.GET("/insurance/products", insuranceHandler.ListProducts)
			protected.GET("/insurance/products/:id", insuranceHandler.GetProduct)
			protected.POST("/insurance/subscribe", insuranceHandler.Subscribe)
			protected.GET("/insurance/policies", insuranceHandler.ListPolicies)
			protected.POST("/insurance/policies/:id/cancel", insuranceHandler.CancelPolicy)

			// Loans (Savings-backed credit)
			protected.GET("/loans/eligibility", loanHandler.CheckEligibility)
			protected.POST("/loans", loanHandler.ApplyForLoan)
			protected.GET("/loans", loanHandler.ListLoans)
			protected.GET("/loans/:id", loanHandler.GetLoan)
			protected.POST("/loans/:id/repay", loanHandler.RepayLoan)

			// Financial Literacy Content
			protected.GET("/content/articles", contentHandler.ListArticles)
			protected.GET("/content/articles/:id", contentHandler.GetArticle)
		}
	}

	// ========================================
	// ADMIN API SERVER
	// ========================================
	// In single-port mode (Railway/production), mount admin on the same router.
	// In dual-port mode (local dev), use a separate router on AdminPort.
	singlePort := cfg.Server.Port == cfg.Server.AdminPort || cfg.Server.AdminPort == ""

	adminRouter := router // default: same router
	if !singlePort {
		adminRouter = gin.New()
		adminRouter.Use(gin.Recovery())
		adminRouter.Use(middleware.CORS())
		adminRouter.Use(middleware.SecurityHeaders())
		adminRouter.Use(middleware.RequestID())
		adminRouter.Use(logger.RequestLogger(logger.FilterLevel(cfg.Server.LogLevel)))
	}

	adminV1 := adminRouter.Group("/api/v1/admin")
	{
		// Admin auth (public)
		adminV1.POST("/login", adminHandler.Login)

		// Protected admin routes
		adminProtected := adminV1.Group("")
		adminProtected.Use(middleware.AdminAuthRequired(jwtSvc))
		adminProtected.Use(middleware.AuditLog(database, cfg.JWT.Secret))
		{
			// System health (all admin roles)
			adminProtected.GET("/health", adminHandler.SystemHealth)

			// Support panel
			support := adminProtected.Group("")
			support.Use(middleware.RequireRole("support", "super_admin"))
			{
				support.GET("/users/search", adminHandler.SearchUsers)
				support.GET("/users/:id", adminHandler.GetUserDetail)
				support.GET("/users/:id/transactions", adminHandler.GetUserTransactions)
				support.POST("/users/:id/kyc/approve", adminHandler.ApproveKYC)
				support.POST("/users/:id/kyc/reject", adminHandler.RejectKYC)
				support.POST("/users/:id/unlock", adminHandler.UnlockAccount)
				support.POST("/users/:id/suspend", adminHandler.SuspendAccount)
				support.POST("/users/:id/reset-pin", adminHandler.ResetUserPIN)
				support.GET("/kyc/pending", adminHandler.GetPendingKYC)
				support.GET("/users/:id/kyc", adminHandler.GetUserKYCDocuments)
			}

			// Finance panel
			finance := adminProtected.Group("")
			finance.Use(middleware.RequireRole("finance", "super_admin"))
			{
				finance.GET("/transactions", adminHandler.ListTransactions)
				finance.GET("/transactions/unreconciled", adminHandler.GetUnreconciledTransactions)
				finance.POST("/transactions/:id/reconcile", adminHandler.MarkTransactionReconciled)
				finance.GET("/reconciliation/summary", adminHandler.GetReconciliationSummary)
			}

			// Super admin
			superAdmin := adminProtected.Group("")
			superAdmin.Use(middleware.RequireRole("super_admin"))
			{
				superAdmin.POST("/admins", adminHandler.CreateAdmin)
				superAdmin.GET("/admins", adminHandler.ListAdmins)
				superAdmin.POST("/admins/:id/deactivate", adminHandler.DeactivateAdmin)
				superAdmin.POST("/admins/:id/reactivate", adminHandler.ReactivateAdmin)
				superAdmin.GET("/audit-logs", adminHandler.GetAuditLogs)
				superAdmin.GET("/feature-flags", adminHandler.GetFeatureFlags)
				superAdmin.PUT("/feature-flags/:id", adminHandler.ToggleFeatureFlag)
				superAdmin.GET("/tier-limits", adminHandler.GetTierLimits)
				superAdmin.PUT("/tier-limits/:tier", adminHandler.UpdateTierLimits)
				superAdmin.GET("/security-alerts", adminHandler.GetSecurityAlerts)

				// Admin views for new features (read-only monitoring)
				superAdmin.GET("/groups", groupHandler.ListAllGroups)
				superAdmin.GET("/investments/all", investmentHandler.ListAllInvestments)
				superAdmin.GET("/insurance/policies", insuranceHandler.ListAllPolicies)
				superAdmin.GET("/loans/all", loanHandler.ListAllLoans)
				superAdmin.POST("/loans/:id/approve", loanHandler.ApproveLoan)
				superAdmin.POST("/loans/:id/reject", loanHandler.RejectLoan)
				superAdmin.GET("/content/articles", contentHandler.ListArticles)
				superAdmin.POST("/content/articles", contentHandler.CreateArticle)
				superAdmin.PUT("/content/articles/:id/publish", contentHandler.TogglePublish)
			}
		}
	}

	// ========================================
	// START SERVERS
	// ========================================
	customerServer := &http.Server{
		Addr:         ":" + cfg.Server.Port,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.WithField("port", cfg.Server.Port).Info("Customer API server starting")
		if err := customerServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.WithError(err).Fatal("Customer API server failed")
		}
	}()

	// In dual-port mode, start admin on separate port
	var adminServer *http.Server
	if !singlePort {
		adminServer = &http.Server{
			Addr:         ":" + cfg.Server.AdminPort,
			Handler:      adminRouter,
			ReadTimeout:  15 * time.Second,
			WriteTimeout: 30 * time.Second,
			IdleTimeout:  60 * time.Second,
		}
		go func() {
			log.WithField("port", cfg.Server.AdminPort).Info("Admin API server starting")
			if err := adminServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
				log.WithError(err).Fatal("Admin API server failed")
			}
		}()
		log.Infof("SavingPlus is running - Customer API on :%s, Admin API on :%s", cfg.Server.Port, cfg.Server.AdminPort)
	} else {
		log.Infof("SavingPlus is running - all APIs on :%s (single-port mode)", cfg.Server.Port)
	}

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("Shutting down servers...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := customerServer.Shutdown(ctx); err != nil {
		log.WithError(err).Error("Customer server forced shutdown")
	}
	if adminServer != nil {
		if err := adminServer.Shutdown(ctx); err != nil {
			log.WithError(err).Error("Admin server forced shutdown")
		}
	}

	log.Info("SavingPlus server stopped")
}

func runMigrations(db *sql.DB) error {
	files := []string{
		"migrations/000001_init.up.sql",
		"migrations/000002_product_features.up.sql",
	}
	for _, f := range files {
		migration, err := os.ReadFile(f)
		if err != nil {
			return fmt.Errorf("failed to read %s: %w", f, err)
		}
		if _, err := db.Exec(string(migration)); err != nil {
			log.WithField("file", f).WithError(err).Warn("Migration may already be applied, continuing")
		} else {
			log.WithField("file", f).Info("Migration applied successfully")
		}
	}
	return nil
}

func setupLogging(level string) {
	log.SetFormatter(&log.JSONFormatter{
		TimestampFormat: time.RFC3339,
	})

	switch level {
	case "debug":
		log.SetLevel(log.DebugLevel)
	case "info":
		log.SetLevel(log.InfoLevel)
	case "warn":
		log.SetLevel(log.WarnLevel)
	case "error":
		log.SetLevel(log.ErrorLevel)
	default:
		log.SetLevel(log.InfoLevel)
	}
}
