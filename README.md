# SavingPlus

Bank-grade savings and investment platform for Tanzania. Built with Go, PostgreSQL, Redis, TypeScript, and React.

## Architecture

```
savingplus/
├── backend/              Go API server (Gin framework)
│   ├── cmd/api/          Entry point, server setup, route wiring
│   ├── internal/         Business logic packages
│   │   ├── auth/         JWT, OTP, registration, login
│   │   ├── user/         Profile, KYC state machine
│   │   ├── wallet/       Double-entry ledger, balance
│   │   ├── transaction/  Transaction history, filtering
│   │   ├── payment/      Mobile money gateway (mock + real)
│   │   ├── savings/      Savings plans (flexible, locked, target)
│   │   ├── notification/ SMS, email, push, in-app
│   │   ├── admin/        Admin CRUD, KYC review, audit logs
│   │   ├── middleware/   Auth, rate limit, audit, CORS
│   │   ├── db/           PostgreSQL connection
│   │   ├── queue/        Asynq workers (async payment processing)
│   │   └── errors/       Typed error handling
│   ├── pkg/              Reusable utilities (crypto, config)
│   └── migrations/       SQL migration files
├── frontend/
│   ├── customer-app/     React + TypeScript + Vite + Tailwind
│   └── admin-app/        Admin panel (support, finance, super admin)
├── docs/api/             OpenAPI spec + Postman collection
├── scripts/              Seed data, utilities
└── docker-compose.yml    Local development stack
```

## Quick Start

### Option 1: Docker Compose (recommended)
```bash
docker-compose up -d
# API: http://localhost:8080 (customer), http://localhost:8081 (admin)
```

### Option 2: Manual Setup

**Prerequisites:** Go 1.22+, PostgreSQL 16+, Redis 7+, Node.js 18+

```bash
# 1. Start PostgreSQL and Redis locally

# 2. Run migrations
psql -U savingplus -d savingplus -f backend/migrations/000001_init.up.sql

# 3. Seed test data
psql -U savingplus -d savingplus -f scripts/seed.sql

# 4. Start backend
cd backend
cp .env.example .env
go run ./cmd/api/

# 5. Start customer frontend
cd frontend/customer-app
npm install && npm run dev

# 6. Start admin frontend
cd frontend/admin-app
npm install && npm run dev
```

## API Endpoints

### Customer API (port 8080)

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/v1/auth/register` | Register new user | No |
| POST | `/api/v1/auth/login` | Login | No |
| POST | `/api/v1/auth/refresh` | Refresh token | No |
| POST | `/api/v1/auth/verify-otp` | Verify OTP | No |
| GET | `/api/v1/profile` | Get user profile | JWT |
| PUT | `/api/v1/profile` | Update profile | JWT |
| GET | `/api/v1/wallet/balance` | Get balance | JWT |
| POST | `/api/v1/wallet/deposit` | Initiate deposit | JWT |
| POST | `/api/v1/wallet/withdraw` | Initiate withdrawal | JWT |
| GET | `/api/v1/transactions` | List transactions | JWT |
| POST | `/api/v1/savings/plan` | Create savings plan | JWT |
| GET | `/api/v1/savings/plans` | List savings plans | JWT |
| POST | `/api/v1/kyc/upload` | Upload KYC document | JWT |
| GET | `/api/v1/kyc/status` | Get KYC status | JWT |
| GET | `/api/v1/notifications` | List notifications | JWT |

### Admin API (port 8081)

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/v1/admin/login` | Admin login (with MFA) | No |
| GET | `/api/v1/admin/health` | System health | Admin JWT |
| GET | `/api/v1/admin/users/search` | Search users | Support |
| GET | `/api/v1/admin/users/:id` | User detail | Support |
| POST | `/api/v1/admin/users/:id/kyc/approve` | Approve KYC | Support |
| POST | `/api/v1/admin/users/:id/kyc/reject` | Reject KYC | Support |
| GET | `/api/v1/admin/transactions` | All transactions | Finance |
| POST | `/api/v1/admin/admins` | Create admin user | Super Admin |
| GET | `/api/v1/admin/audit-logs` | View audit logs | Super Admin |
| GET | `/api/v1/admin/feature-flags` | List feature flags | Super Admin |
| PUT | `/api/v1/admin/feature-flags/:id` | Toggle flag | Super Admin |

## Security Features

- **Argon2id** password and PIN hashing
- **JWT** with short-lived access tokens (15min) and rotated refresh tokens (7 days)
- **OTP** via SMS (stored in Redis with 5-min TTL)
- **Step-up authentication** for high-value withdrawals (>TZS 100,000)
- **Rate limiting** per user/IP (Redis-backed)
- **Idempotency keys** for all state-changing operations
- **AES-256-GCM** encryption for sensitive PII
- **HMAC-signed** audit log entries
- **MFA** (Google Authenticator) for admin users
- **Double-entry ledger** for all wallet operations
- **Append-only audit logs** with sanitized request bodies
- **Security headers** (HSTS, CSP, X-Frame-Options, etc.)
- Account lockout after 5 failed login attempts

## KYC Tiers

| Tier | Deposit/Day | Withdrawal/Day | Max Balance |
|------|-------------|----------------|-------------|
| 0 (Unverified) | TZS 50,000 | None | TZS 100,000 |
| 1 (Basic) | TZS 500,000 | TZS 200,000 | TZS 2,000,000 |
| 2 (Enhanced) | TZS 5,000,000 | TZS 2,000,000 | TZS 20,000,000 |
| 3 (Premium) | TZS 50,000,000 | TZS 20,000,000 | TZS 200,000,000 |

## Environment Variables

See [backend/.env.example](backend/.env.example) for all configuration options.

## Deployment

See [docs/deployment.md](docs/deployment.md) for production deployment instructions.

## License

Proprietary - SavingPlus Ltd.
