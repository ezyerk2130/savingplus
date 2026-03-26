# SavingPlus - Architecture & Maintenance Guide

## Overview

SavingPlus is a bank-grade fintech platform (savings & investment) for Tanzania. It consists of:

1. **Go Backend** - REST API serving both customer and admin endpoints on separate ports
2. **Customer Web App** - React + TypeScript SPA for end users
3. **Admin Panel** - React + TypeScript SPA with role-based access (support, finance, super_admin)
4. **PostgreSQL** - Primary database with double-entry ledger
5. **Redis** - Caching, rate limiting, OTP storage, idempotency keys, job queue

## Architecture Decisions

### Monolith with Clean Packages
The backend is a Go monolith organized into `internal/` packages. Each package owns its domain logic and SQL queries. No ORM - raw SQL with `database/sql` and `pgx` driver for full control over queries and transactions.

### Two HTTP Servers
Customer API runs on port 8080, Admin API on port 8081. This allows separate network policies (e.g., admin only accessible from VPN/whitelist).

### Double-Entry Ledger
All wallet operations use `ledger_entries` table with `debit`/`credit` entries. Balance changes happen inside database transactions with `SELECT ... FOR UPDATE` to prevent race conditions.

### Async Payment Processing
Deposits and withdrawals are created as `pending` transactions, then processed asynchronously via Asynq (Redis-backed job queue). The payment gateway calls back via webhooks to complete the flow.

### Idempotency
All state-changing endpoints accept an `idempotency_key`. Results are cached in Redis for 24 hours to prevent duplicate processing.

## Database Schema

### Core Tables
- `users` - User accounts with phone, password_hash, pin_hash, kyc_status, tier
- `wallets` - One per user, tracks available_balance and locked_balance
- `ledger_entries` - Immutable double-entry records
- `transactions` - All financial transactions with status tracking
- `savings_plans` - Flexible, locked, and target savings plans
- `kyc_documents` - Uploaded identity documents with review status
- `audit_logs` - Append-only, HMAC-signed audit trail
- `payment_gateway_logs` - Raw request/response logs for gateway interactions
- `admin_users` - Internal staff with roles and MFA
- `feature_flags` - Runtime feature toggles
- `refresh_tokens` - JWT refresh token tracking (rotated on use)
- `notifications` - In-app notifications
- `tier_limits` - KYC tier deposit/withdrawal/balance limits

### Key Constraints
- All PKs are UUID v4
- All timestamps are `timestamptz`
- All monetary amounts are `NUMERIC(20,2)`
- Foreign keys with appropriate cascades
- Check constraints on enum-like columns
- Auto-updated `updated_at` via triggers

## Security Measures

### Authentication
- Passwords: Argon2id (time=1, memory=64KB, threads=4, keyLen=32)
- JWT access tokens: 15-minute TTL, HS256
- Refresh tokens: 7-day TTL, rotated on use, stored as SHA-256 hash
- OTP: 6-digit, stored in Redis with 5-minute TTL
- Account lockout: 5 failed attempts -> 30-minute lock

### API Protection
- Rate limiting: 5 req/sec, 100 req/min per user/IP
- Input validation: Gin's binding + custom validators
- CORS with credential support
- Security headers (HSTS, CSP, X-Frame-Options, X-Content-Type-Options)
- Request ID tracking

### Data Protection
- Sensitive fields (passwords, PINs, OTPs) never logged
- Audit log request bodies sanitized (passwords redacted)
- PII encryption available via AES-256-GCM
- Audit entries optionally HMAC-signed

### Admin Security
- MFA required (Google Authenticator / TOTP)
- Role-based access control (support, finance, super_admin)
- Separate server port for network isolation
- All admin actions logged

## How to Extend

### Adding a New Product (e.g., Investment Plans)

1. **Database**: Create a new migration file (e.g., `000002_investments.up.sql`) with the new table
2. **Backend**: Create `internal/investment/` package with:
   - `handler.go` - HTTP handlers
   - Data models as structs
   - SQL queries inline
3. **Routes**: Add routes in `cmd/api/main.go` under the protected group
4. **Frontend**: Add new page in `frontend/customer-app/src/pages/`
5. **API client**: Add service functions in `frontend/customer-app/src/api/services.ts`
6. **Admin**: If admin views needed, add to admin app similarly

### Adding a New Payment Gateway

1. Implement the `PaymentGateway` interface in `internal/payment/`:
   ```go
   type PaymentGateway interface {
       InitiateDeposit(ctx context.Context, req DepositRequest) (*GatewayResponse, error)
       InitiateWithdrawal(ctx context.Context, req WithdrawalRequest) (*GatewayResponse, error)
       HandleWebhook(ctx context.Context, payload []byte) (*WebhookEvent, error)
   }
   ```
2. Register it in `NewGateway()` factory function
3. Set `PAYMENT_GATEWAY=<name>` environment variable

### Adding New Admin Roles

1. Add the role to the `admin_users.role` CHECK constraint via migration
2. Add role check in `middleware.RequireRole()`
3. Create route group in `main.go` with the new role
4. Add navigation item in admin app's `AdminLayout.tsx`

## Code Style

- **Go**: Standard Go conventions. Structured logging with logrus. Error handling at every level.
- **React**: Functional components with hooks. Zustand for global state. React Hook Form + Zod for forms.
- **SQL**: Snake_case column names. UUIDs for PKs. TIMESTAMPTZ for all dates.
- **API**: RESTful with `/api/v1/` prefix. JSON responses. Standard HTTP status codes.

## Key Libraries

### Backend
- `gin-gonic/gin` - HTTP framework
- `jackc/pgx/v5` - PostgreSQL driver
- `golang-jwt/jwt/v5` - JWT tokens
- `redis/go-redis/v9` - Redis client
- `hibiken/asynq` - Async job queue
- `pquerna/otp` - TOTP for admin MFA
- `sirupsen/logrus` - Structured logging
- `golang.org/x/crypto` - Argon2id

### Frontend
- `react` + `react-dom` - UI framework
- `react-router-dom` - Client-side routing
- `axios` - HTTP client
- `react-hook-form` + `zod` - Form handling & validation
- `zustand` - State management
- `tailwindcss` - Utility-first CSS
- `lucide-react` - Icons
- `react-hot-toast` - Toast notifications
