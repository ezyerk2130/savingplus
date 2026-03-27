# SavingPlus API Documentation

Base URLs:
- **Customer API**: `http://localhost:8080/api/v1`
- **Admin API**: `http://localhost:8081/api/v1/admin` (dev) or same port in production

## Authentication

All protected endpoints require:
```
Authorization: Bearer <access_token>
```

**Token Flow:**
1. Register or login to receive `access_token` + `refresh_token`
2. Access token expires in ~15 minutes
3. Use `/auth/refresh` with refresh token to get a new pair
4. Refresh tokens are single-use (rotated on each refresh)

**Rate Limiting:**
- 5 requests/second, 100 requests/minute per IP
- Returns `429 Too Many Requests` with `Retry-After` header

---

## Customer API Endpoints

### Auth (Public)

#### POST /auth/register
Create a new user account with wallet.

**Request:**
```json
{
  "phone": "+255712345678",       // required, 10-15 chars
  "full_name": "John Doe",        // required, 2-255 chars
  "password": "securepass123",     // required, 8-128 chars
  "pin": "1234"                    // required, exactly 4 digits
}
```

**Response:** `201 Created`
```json
{
  "message": "Registration successful. Please verify your phone with the OTP sent.",
  "user_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Errors:** `400` validation | `409` phone already registered

---

#### POST /auth/login
Authenticate and receive token pair. Account locks after 5 failed attempts (30 min).

**Request:**
```json
{
  "phone": "+255712345678",    // required
  "password": "securepass123"  // required
}
```

**Response:** `200 OK`
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "a1b2c3d4-e5f6-...",
  "expires_in": 900,
  "token_type": "Bearer"
}
```

**Errors:** `401` invalid credentials | `403` account locked/suspended/closed

---

#### POST /auth/refresh
Exchange a refresh token for a new token pair. Old refresh token is revoked.

**Request:**
```json
{
  "refresh_token": "a1b2c3d4-e5f6-..."  // required
}
```

**Response:** `200 OK` (same shape as login response)

**Errors:** `401` invalid or expired refresh token

---

#### POST /auth/verify-otp
Verify a 6-digit OTP code.

**Request:**
```json
{
  "phone": "+255712345678",  // required
  "code": "123456"           // required, exactly 6 digits
}
```

**Response:** `200 OK`
```json
{
  "message": "OTP verified successfully",
  "verified": true
}
```

**Errors:** `400` invalid OTP

---

#### POST /auth/send-otp
Send OTP to a phone number (stored in Redis, 5-minute TTL).

**Request:**
```json
{
  "phone": "+255712345678"  // required
}
```

**Response:** `200 OK`
```json
{ "message": "OTP sent successfully" }
```

---

### Auth (Protected)

#### POST /auth/change-password
Change the current user's password. Revokes all refresh tokens (forces re-login on all devices).

**Request:**
```json
{
  "current_password": "oldpass123",    // required
  "new_password": "newsecurepass456"   // required, min 8 chars
}
```

**Response:** `200 OK`
```json
{ "message": "Password changed successfully. Please log in again on other devices." }
```

**Errors:** `401` wrong current password

---

#### POST /auth/change-pin
Change the 4-digit transaction PIN.

**Request:**
```json
{
  "current_pin": "1234",  // required, 4 digits
  "new_pin": "5678"       // required, 4 digits
}
```

**Response:** `200 OK`
```json
{ "message": "Transaction PIN changed successfully" }
```

**Errors:** `401` wrong current PIN

---

#### POST /auth/logout
Revoke a specific refresh token.

**Request:**
```json
{
  "refresh_token": "a1b2c3d4-e5f6-..."  // required
}
```

**Response:** `200 OK`
```json
{ "message": "Logged out successfully" }
```

---

### Profile

#### GET /profile
Get the authenticated user's profile.

**Response:** `200 OK`
```json
{
  "id": "uuid",
  "phone": "+255712345678",
  "email": "john@example.com",       // null if not set
  "full_name": "John Doe",
  "kyc_status": "pending",           // pending | submitted | approved | rejected
  "kyc_tier": 0,                     // 0-3
  "status": "active",                // active | locked | suspended | closed
  "created_at": "2024-01-15T10:30:00Z"
}
```

---

#### PUT /profile
Update profile fields. Only provided fields are updated.

**Request:**
```json
{
  "full_name": "John M. Doe",     // optional, 2-255 chars
  "email": "john@example.com"     // optional, valid email
}
```

**Response:** `200 OK`
```json
{ "message": "Profile updated successfully" }
```

---

#### GET /profile/limits
Get the user's current KYC tier limits.

**Response:** `200 OK`
```json
{
  "kyc_tier": 1,
  "limits": {
    "daily_deposit_limit": "500000.00",
    "daily_withdrawal_limit": "200000.00",
    "max_balance": "2000000.00",
    "description": "Basic verified user"
  }
}
```

---

### KYC

#### POST /kyc/upload
Upload a KYC verification document. Uses `multipart/form-data`.

**Form Fields:**
| Field | Type | Required | Values |
|-------|------|----------|--------|
| `document_type` | string | yes | `national_id`, `passport`, `driving_license`, `voter_id`, `selfie`, `proof_of_address` |
| `file` | file | yes | Max 10MB, JPG/PNG/PDF |

**Response:** `201 Created`
```json
{
  "document_id": "uuid",
  "status": "pending",
  "message": "Document uploaded successfully and pending review"
}
```

---

#### GET /kyc/status
Get KYC verification status and all uploaded documents.

**Response:** `200 OK`
```json
{
  "kyc_status": "submitted",
  "kyc_tier": 0,
  "documents": [
    {
      "id": "uuid",
      "document_type": "national_id",
      "status": "pending",              // pending | approved | rejected
      "rejection_reason": null,          // string if rejected
      "created_at": "2024-01-15T10:30:00Z"
    }
  ]
}
```

---

### Wallet

#### GET /wallet/balance
Get wallet balance.

**Response:** `200 OK`
```json
{
  "wallet_id": "uuid",
  "currency": "TZS",
  "available_balance": "150000.00",
  "locked_balance": "50000.00",
  "total_balance": "200000.00"
}
```

---

#### POST /wallet/deposit
Initiate a mobile money deposit. Processed asynchronously.

**Request:**
```json
{
  "amount": 50000,                                   // required, > 0
  "payment_method": "mpesa",                         // required: mpesa | tigopesa | airtel | halopesa
  "phone_number": "+255712345678",                   // required
  "idempotency_key": "unique-key-min-16-chars-here"  // required, 16-64 chars
}
```

**Response:** `202 Accepted`
```json
{
  "transaction_id": "uuid",
  "reference": "DEP-a1b2c3d4-1705312200000",
  "status": "pending",
  "message": "Deposit initiated. You will receive a mobile money prompt shortly."
}
```

**Errors:** `400` exceeds daily limit

**Idempotency:** Same `idempotency_key` returns the cached response for 24 hours.

---

#### POST /wallet/withdraw
Initiate a mobile money withdrawal. Requires PIN. High-value withdrawals require OTP.

**Request:**
```json
{
  "amount": 30000,                                   // required, > 0
  "pin": "1234",                                     // required, 4 digits
  "payment_method": "mpesa",                         // required
  "phone_number": "+255712345678",                   // required
  "idempotency_key": "unique-key-min-16-chars-here", // required, 16-64 chars
  "otp_code": "654321"                               // required if amount >= step-up threshold
}
```

**Response:** `202 Accepted`
```json
{
  "transaction_id": "uuid",
  "reference": "WDR-a1b2c3d4-1705312200000",
  "status": "pending",
  "message": "Withdrawal initiated. You will receive the money shortly."
}
```

**Errors:**
- `400` insufficient balance, exceeds daily limit
- `401` invalid PIN
- `403` OTP required (returns `{"error": "stepup_required", "require": "otp"}`)
- `403` KYC tier < 1

---

### Transactions

#### GET /transactions
List user transactions with pagination and filters.

**Query Parameters:**
| Param | Type | Default | Values |
|-------|------|---------|--------|
| `page` | int | 1 | |
| `page_size` | int | 20 | 1-100 |
| `type` | string | all | `deposit`, `withdrawal`, `savings_lock`, `savings_unlock`, `fee`, `interest` |
| `status` | string | all | `pending`, `processing`, `completed`, `failed`, `reversed` |

**Response:** `200 OK`
```json
{
  "transactions": [
    {
      "id": "uuid",
      "type": "deposit",
      "status": "completed",
      "amount": "50000.00",
      "fee": "0.00",
      "currency": "TZS",
      "reference": "DEP-a1b2c3d4-1705312200000",
      "description": null,
      "created_at": "2024-01-15T10:30:00Z",
      "completed_at": "2024-01-15T10:31:00Z"
    }
  ],
  "total": 42,
  "page": 1,
  "page_size": 20,
  "total_pages": 3
}
```

---

#### GET /transactions/:id
Get a single transaction by ID (must belong to the authenticated user).

**Response:** `200 OK` (single transaction object, same shape as list item)

**Errors:** `404` not found

---

### Savings Plans

#### POST /savings/plan
Create a new savings plan with optional initial deposit.

**Request:**
```json
{
  "name": "Emergency Fund",                // required, 1-100 chars
  "type": "flexible",                      // required: flexible | locked | target
  "initial_amount": 10000,                 // optional, debited from wallet
  "target_amount": 500000,                 // required if type=target
  "lock_duration_days": 90,                // required if type=locked, min 30
  "auto_debit": true,                      // optional
  "auto_debit_amount": 5000,               // required if auto_debit=true
  "auto_debit_frequency": "weekly"         // required if auto_debit=true: daily | weekly | monthly
}
```

**Interest Rates:**
| Type | Rate |
|------|------|
| Flexible | 4% p.a. |
| Target | 6% p.a. |
| Locked | 8% p.a. |

**Response:** `201 Created`
```json
{
  "plan_id": "uuid",
  "name": "Emergency Fund",
  "type": "flexible",
  "interest_rate": "4.00%",
  "message": "Savings plan created successfully",
  "initial_deposit": "10000.00"            // only if initial_amount provided
}
```

**Errors:** `400` insufficient balance, initial > target amount

---

#### GET /savings/plans
List all savings plans for the user.

**Query Parameters:**
| Param | Type | Values |
|-------|------|--------|
| `status` | string | `active`, `matured`, `withdrawn`, `cancelled` |

**Response:** `200 OK`
```json
{
  "plans": [
    {
      "id": "uuid",
      "name": "Emergency Fund",
      "type": "flexible",
      "status": "active",
      "target_amount": "500000.00",        // null for non-target plans
      "current_amount": "10000.00",
      "interest_rate": "4.00%",
      "lock_duration_days": null,
      "maturity_date": null,
      "auto_debit": false,
      "auto_debit_amount": null,
      "auto_debit_frequency": null,
      "created_at": "2024-01-15T10:30:00Z"
    }
  ],
  "total": 3
}
```

---

#### GET /savings/plans/:id
Get a single savings plan.

**Response:** `200 OK` (single plan object)

**Errors:** `404` not found

---

#### POST /savings/plans/:id/deposit
Move funds from wallet into a savings plan.

**Request:**
```json
{ "amount": 25000 }   // required, > 0
```

**Response:** `200 OK`
```json
{
  "message": "Deposit to savings plan successful",
  "transaction_id": "uuid",
  "plan_balance": "35000.00",
  "wallet_balance": "125000.00"
}
```

**Errors:** `400` insufficient balance, exceeds target, plan not active

---

#### POST /savings/plans/:id/withdraw
Move funds from savings plan back to wallet.

**Request:**
```json
{ "amount": 10000 }   // required, > 0
```

**Response:** `200 OK`
```json
{
  "message": "Withdrawal from savings plan successful",
  "transaction_id": "uuid",
  "plan_balance": "25000.00",
  "wallet_balance": "135000.00"
}
```

**Errors:** `400` insufficient plan balance | `403` locked plan not matured

---

#### POST /savings/plans/:id/cancel
Cancel a savings plan and refund all funds to wallet.

**Request:** empty body

**Response:** `200 OK`
```json
{
  "message": "Savings plan cancelled",
  "refunded_amount": "35000.00"
}
```

**Errors:** `400` plan not active | `403` locked plan not matured

---

### Notifications

#### GET /notifications
List notifications (last 50).

**Response:** `200 OK`
```json
{
  "notifications": [
    {
      "id": "uuid",
      "type": "in_app",
      "title": "Deposit Received",
      "message": "TZS 50,000 has been deposited to your wallet",
      "read": false,
      "created_at": "2024-01-15T10:30:00Z"
    }
  ],
  "unread_count": 3
}
```

---

#### PUT /notifications/:id/read
Mark a single notification as read.

**Response:** `200 OK`
```json
{ "message": "Notification marked as read" }
```

---

#### PUT /notifications/read-all
Mark all notifications as read.

**Response:** `200 OK`
```json
{ "message": "All notifications marked as read" }
```

---

### Webhooks (Public)

#### POST /webhooks/payment
Callback endpoint for payment gateway. Updates transaction status and wallet balance.

**Request:** Gateway-specific payload
```json
{
  "transaction_id": "uuid",
  "gateway_ref": "GW-REF-123",
  "status": "completed",           // completed | failed
  "amount": 50000,
  "reference": "DEP-a1b2c3d4-...",
  "message": "Payment successful"
}
```

**Response:** `200 OK`
```json
{ "message": "Webhook processed successfully" }
```

---

## Admin API Endpoints

All admin endpoints require `Authorization: Bearer <admin_access_token>`.
Role-based access: **support**, **finance**, **super_admin**.

### Auth

#### POST /admin/login
Admin login with email, password, and TOTP MFA code.

**Request:**
```json
{
  "email": "admin@savingplus.co.tz",  // required
  "password": "AdminPass123!",         // required
  "mfa_code": "123456"                 // required, 6 digits from Google Authenticator
}
```

**Response:** `200 OK`
```json
{
  "access_token": "eyJhbGciOi...",
  "expires_in": 900,
  "role": "super_admin"
}
```

---

### System (All Roles)

#### GET /admin/health
System health dashboard metrics.

**Response:** `200 OK`
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "total_users": 1500,
  "total_transactions": 8500,
  "pending_transactions": 12,
  "pending_kyc": 8,
  "failed_txns_24h": 3,
  "locked_accounts": 2,
  "total_deposits": 75000000.00,
  "total_withdrawals": 52000000.00
}
```

---

### Support Panel (support, super_admin)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/users/search?q=john&page=1` | Search users by name/phone/email |
| GET | `/admin/users/:id` | Get user detail with balances |
| GET | `/admin/users/:id/transactions?page=1` | User's transaction history |
| GET | `/admin/users/:id/kyc` | User's KYC documents |
| POST | `/admin/users/:id/kyc/approve` | Approve KYC (`{document_id, new_tier}`) |
| POST | `/admin/users/:id/kyc/reject` | Reject KYC (`{document_id, reason}`) |
| POST | `/admin/users/:id/unlock` | Unlock locked/suspended account |
| POST | `/admin/users/:id/suspend` | Suspend account (`{reason}`) |
| POST | `/admin/users/:id/reset-pin` | Reset user PIN (`{new_pin}`) |
| GET | `/admin/kyc/pending?page=1` | Pending KYC queue |

### Finance Panel (finance, super_admin)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/transactions?page=1&status=pending` | All transactions with filters |
| GET | `/admin/transactions/unreconciled?page=1` | Unreconciled completed transactions |
| POST | `/admin/transactions/:id/reconcile` | Mark reconciled (`{settlement_ref, notes}`) |
| GET | `/admin/reconciliation/summary` | Reconciliation summary stats |

### Super Admin Only

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/admin/admins` | Create admin (`{email, full_name, password, role}`) |
| GET | `/admin/admins` | List all admins |
| POST | `/admin/admins/:id/deactivate` | Deactivate admin |
| POST | `/admin/admins/:id/reactivate` | Reactivate admin |
| GET | `/admin/audit-logs?page=1` | Audit log entries |
| GET | `/admin/feature-flags` | List feature flags |
| PUT | `/admin/feature-flags/:id` | Toggle flag (`{enabled}`) |
| GET | `/admin/tier-limits` | KYC tier limit config |
| PUT | `/admin/tier-limits/:tier` | Update limits (`{daily_deposit_limit, ...}`) |
| GET | `/admin/security-alerts?page=1` | Security alerts (locked accounts, high-value txns, failures) |

---

## Error Response Format

All errors follow this shape:
```json
{
  "error": "error_code",        // machine-readable
  "detail": "Human explanation"  // optional, present on validation errors
}
```

### Standard Error Codes
| Code | HTTP Status | Meaning |
|------|-------------|---------|
| `bad_request` | 400 | Invalid request data |
| `unauthorized` | 401 | Missing/invalid authentication |
| `forbidden` | 403 | Insufficient permissions |
| `not_found` | 404 | Resource not found |
| `conflict` | 409 | Duplicate resource |
| `rate_limited` | 429 | Too many requests |
| `internal_error` | 500 | Server error |
| `otp_invalid` | 400 | Wrong OTP code |
| `otp_expired` | 400 | OTP expired |
| `kyc_required` | 403 | KYC verification needed |
| `insufficient_balance` | 400 | Not enough funds |
| `stepup_required` | 403 | OTP needed for high-value transaction |
| `account_locked` | 403 | Account is locked |

---

## Pagination

Paginated endpoints return:
```json
{
  "data_key": [...],
  "total": 100,
  "page": 1,
  "page_size": 20,
  "total_pages": 5
}
```

Query params: `?page=1&page_size=20` (page_size max 100)
