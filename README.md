# SavingPlus

Bank-grade savings & investment platform for Tanzania. Built with Go, React, Flutter, PostgreSQL, and Redis.

## Features

| Feature | Description |
|---------|-------------|
| **AutoSave** | Recurring daily/weekly/monthly deductions from mobile money |
| **SafeLock** | Fixed-term savings with up to 18% p.a. returns |
| **Goal Savings** | Target-based savings with progress tracking |
| **Flex Wallet** | Liquid savings with instant access |
| **FlexDollar** | USD savings to protect against TZS inflation |
| **Investify TZ** | Investment marketplace with 7 products (T-Bills, funds, real estate) |
| **Upatu Circles** | Rotating group savings (traditional Upatu digitized) |
| **Micro-Insurance** | Health, life, crop, device, travel coverage from 2K TZS/month |
| **Savings-Backed Credit** | Loans collateralized by savings balance |
| **Financial Literacy** | Bilingual articles (English + Swahili) |
| **M-Pesa Integration** | All 5 TZ mobile money operators (M-Pesa, Tigo, Airtel, Halo) |
| **KYC Verification** | Tiered limits with document upload |
| **Multi-Country Ready** | Architecture supports multiple currencies and countries |

## Architecture

```
savingplus/
├── backend/                 Go REST API (60+ endpoints)
│   ├── cmd/api/             Server entry point
│   ├── cmd/seedadmin/       Admin user seeder
│   ├── internal/            16 domain packages
│   │   ├── auth/            JWT, OTP, registration
│   │   ├── wallet/          Double-entry ledger
│   │   ├── savings/         Flexible, locked, target plans
│   │   ├── investment/      Investify marketplace
│   │   ├── group/           Upatu circles
│   │   ├── insurance/       Micro-insurance
│   │   ├── loan/            Savings-backed credit
│   │   ├── content/         Financial literacy (bilingual)
│   │   ├── admin/           25+ admin endpoints
│   │   └── ...
│   ├── migrations/          2 SQL migration files (30+ tables)
│   └── pkg/                 Shared utilities (crypto, config, logger, response)
│
├── frontend/
│   ├── customer-app/        React + TypeScript + Tailwind (15 pages)
│   └── admin-app/           React + TypeScript + Tailwind (16 pages)
│
├── savingplus/              Flutter mobile app (18 screens)
│   └── lib/
│       ├── core/            API client, models, auth provider
│       └── features/        Splash, onboarding, auth, all product screens
│
├── railway.toml             Deployment config
└── CLAUDE.md                Architecture & maintenance guide
```

## Quick Start

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Go | 1.23+ | Backend API |
| Node.js | 20+ | Web frontends |
| PostgreSQL | 15+ | Primary database |
| Redis | 7+ | Cache, rate limit, jobs |
| Flutter | 3.11+ | Mobile app (optional) |

### 1. Backend

```bash
cd backend
cp .env.example .env    # Edit with your DB/Redis credentials

# Start the server (auto-runs migrations)
go run ./cmd/api/main.go

# Seed admin users
go run ./cmd/seedadmin/main.go
```

The backend starts on **port 8080** (customer API) and **port 8081** (admin API).

### 2. Customer Web App

```bash
cd frontend/customer-app
npm install
npm run dev             # http://localhost:3000
```

### 3. Admin Web App

```bash
cd frontend/admin-app
npm install
npm run dev             # http://localhost:3001
```

**Default admin login:** `admin@savingplus.co.tz` / `Admin@123456` / any 6-digit MFA code (dev mode)

### 4. Flutter Mobile App

```bash
cd savingplus
flutter pub get

# For physical device: edit lib/core/api/api_client.dart line 10
# Change _lanIp to your PC's WiFi IP (run ipconfig to find it)

flutter run
```

## Environment Variables

Create `backend/.env` from `.env.example`:

```env
# Server
SERVER_PORT=8080
ADMIN_SERVER_PORT=8081
ENV=development
LOG_LEVEL=debug

# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=savingplus
DB_PASSWORD=savingplus_secret
DB_NAME=savingplus
DB_SSLMODE=disable

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# Security
JWT_SECRET=your-64-char-random-secret-here
ENCRYPTION_KEY=your-64-char-hex-key-here
PAYMENT_GATEWAY=mock
RATE_LIMIT_PER_SECOND=15
RATE_LIMIT_PER_MINUTE=200
```

## API Documentation

### Authentication
```
POST /api/v1/auth/register    {phone, full_name, password, pin}
POST /api/v1/auth/login       {phone, password}  →  {access_token, refresh_token}
POST /api/v1/auth/refresh     {refresh_token}
POST /api/v1/auth/send-otp    {phone}
POST /api/v1/auth/verify-otp  {phone, code}
POST /api/v1/auth/change-password  {current_password, new_password}
POST /api/v1/auth/change-pin      {current_pin, new_pin}
POST /api/v1/auth/logout          {refresh_token}
```

### Wallet
```
GET  /api/v1/wallet/balance
POST /api/v1/wallet/deposit   {amount, payment_method, phone_number, idempotency_key}
POST /api/v1/wallet/withdraw  {amount, pin, payment_method, phone_number, idempotency_key}
```

### Savings Plans
```
POST /api/v1/savings/plan               {name, type, initial_amount?, target_amount?, ...}
GET  /api/v1/savings/plans
GET  /api/v1/savings/plans/:id
POST /api/v1/savings/plans/:id/deposit  {amount}
POST /api/v1/savings/plans/:id/withdraw {amount}
POST /api/v1/savings/plans/:id/cancel
```

### Investments (Investify TZ)
```
GET  /api/v1/investments/products       ?type=
GET  /api/v1/investments/products/:id
POST /api/v1/investments                {product_id, amount}
GET  /api/v1/investments                ?page=&status=
POST /api/v1/investments/:id/withdraw
```

### Groups (Upatu Circles)
```
POST /api/v1/groups                     {name, type, contribution_amount, frequency, max_members}
GET  /api/v1/groups
GET  /api/v1/groups/:id
POST /api/v1/groups/:id/join
POST /api/v1/groups/:id/leave
POST /api/v1/groups/:id/contribute
POST /api/v1/groups/:id/start
```

### Insurance
```
GET  /api/v1/insurance/products         ?type=
GET  /api/v1/insurance/products/:id
POST /api/v1/insurance/subscribe        {product_id, beneficiary_name, beneficiary_phone}
GET  /api/v1/insurance/policies
POST /api/v1/insurance/policies/:id/cancel
```

### Loans (Savings-Backed Credit)
```
GET  /api/v1/loans/eligibility
POST /api/v1/loans                      {amount, term_days}
GET  /api/v1/loans                      ?page=&status=
GET  /api/v1/loans/:id
POST /api/v1/loans/:id/repay            {amount}
```

### Other
```
GET  /api/v1/content/articles           ?category=&language=
GET  /api/v1/content/articles/:id
POST /api/v1/kyc/upload                 multipart: file, document_type
GET  /api/v1/kyc/status
GET  /api/v1/notifications
PUT  /api/v1/notifications/:id/read
PUT  /api/v1/notifications/read-all
GET  /api/v1/profile
PUT  /api/v1/profile                    {full_name?, email?}
GET  /api/v1/profile/limits
GET  /api/v1/transactions               ?page=&type=&status=
GET  /api/v1/transactions/:id
```

See [CLAUDE.md](CLAUDE.md) for admin endpoints and full architecture guide.

## Testing

```bash
# Backend (207 tests)
cd backend && go test ./...

# Customer web app (26 tests)
cd frontend/customer-app && npm test

# Admin web app (16 tests)
cd frontend/admin-app && npm test

# Total: 249 tests
```

## Deployment (Railway)

1. Push to GitHub
2. Create Railway project with **PostgreSQL** and **Redis** addons
3. Add 3 services from the same repo:

| Service | Root Directory | Notes |
|---------|---------------|-------|
| backend | `backend` | Set env vars (see CLAUDE.md) |
| customer-app | `frontend/customer-app` | Auto-builds with Dockerfile |
| admin-app | `frontend/admin-app` | Auto-builds with Dockerfile |

4. Set `SERVER_PORT=${{PORT}}` and `ADMIN_SERVER_PORT=${{PORT}}` for single-port mode
5. Run `railway run --service backend ./savingplus-seed` to create admin users
6. Generate public domains for customer-app and admin-app

## Tech Stack

### Backend
| Library | Purpose |
|---------|---------|
| gin-gonic/gin | HTTP framework |
| jackc/pgx/v5 | PostgreSQL driver |
| golang-jwt/jwt/v5 | JWT tokens |
| redis/go-redis/v9 | Redis client |
| hibiken/asynq | Async job queue |
| pquerna/otp | TOTP for admin MFA |
| sirupsen/logrus | Structured logging |
| golang.org/x/crypto | Argon2id password hashing |

### Frontend (Web)
| Library | Purpose |
|---------|---------|
| React 18 + TypeScript | UI framework |
| Tailwind CSS | Styling (Wise-inspired design) |
| Zustand | State management |
| React Hook Form + Zod | Forms & validation |
| Axios | HTTP client with auth interceptor |
| Lucide React | Icons |

### Mobile (Flutter)
| Library | Purpose |
|---------|---------|
| Dio | HTTP client with JWT refresh |
| Provider | State management |
| GoRouter | Declarative routing |
| flutter_secure_storage | Encrypted token/credential storage |
| local_auth | Biometric login (fingerprint/face) |
| Google Fonts | Plus Jakarta Sans + Inter typography |

## Security Highlights

- Passwords hashed with Argon2id
- JWT access tokens (15 min) + refresh tokens (7 days, rotated on use)
- Rate limiting: 15 req/sec, 200 req/min per IP
- Account lockout after 5 failed login attempts
- Admin MFA via TOTP (Google Authenticator)
- Double-entry ledger with `SELECT ... FOR UPDATE` row locking
- HMAC-signed audit logs
- Wallet queries enforce currency filter for multi-currency safety
- Biometric authentication on mobile (fingerprint/face)
- KYC document file hashing (SHA-256)

## License

Private — All rights reserved.
