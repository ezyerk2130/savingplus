-- SavingPlus Database Schema
-- Migration: 000001_init

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone           VARCHAR(20) UNIQUE NOT NULL,
    email           VARCHAR(255) UNIQUE,
    full_name       VARCHAR(255) NOT NULL,
    password_hash   TEXT NOT NULL,
    pin_hash        TEXT NOT NULL,
    kyc_status      VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (kyc_status IN ('pending', 'submitted', 'under_review', 'approved', 'rejected')),
    kyc_tier        SMALLINT NOT NULL DEFAULT 0 CHECK (kyc_tier BETWEEN 0 AND 3),
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'suspended', 'locked', 'closed')),
    failed_login_attempts INT NOT NULL DEFAULT 0,
    locked_until    TIMESTAMPTZ,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL;
CREATE INDEX idx_users_status ON users(status);

-- ============================================================
-- WALLETS (one per user, TZS)
-- ============================================================
CREATE TABLE wallets (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL UNIQUE REFERENCES users(id),
    currency        VARCHAR(3) NOT NULL DEFAULT 'TZS',
    available_balance NUMERIC(20,2) NOT NULL DEFAULT 0.00 CHECK (available_balance >= 0),
    locked_balance  NUMERIC(20,2) NOT NULL DEFAULT 0.00 CHECK (locked_balance >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wallets_user_id ON wallets(user_id);

-- ============================================================
-- LEDGER ENTRIES (immutable double-entry)
-- ============================================================
CREATE TABLE ledger_entries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id  UUID NOT NULL,
    wallet_id       UUID NOT NULL REFERENCES wallets(id),
    entry_type      VARCHAR(10) NOT NULL CHECK (entry_type IN ('debit', 'credit')),
    amount          NUMERIC(20,2) NOT NULL CHECK (amount > 0),
    balance_after   NUMERIC(20,2) NOT NULL,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ledger_transaction ON ledger_entries(transaction_id);
CREATE INDEX idx_ledger_wallet ON ledger_entries(wallet_id);
CREATE INDEX idx_ledger_created ON ledger_entries(created_at);

-- ============================================================
-- TRANSACTIONS
-- ============================================================
CREATE TABLE transactions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    wallet_id       UUID NOT NULL REFERENCES wallets(id),
    type            VARCHAR(30) NOT NULL
                    CHECK (type IN ('deposit', 'withdrawal', 'savings_lock', 'savings_unlock', 'fee', 'interest', 'adjustment')),
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'reversed')),
    amount          NUMERIC(20,2) NOT NULL CHECK (amount > 0),
    fee             NUMERIC(20,2) NOT NULL DEFAULT 0.00,
    currency        VARCHAR(3) NOT NULL DEFAULT 'TZS',
    reference       VARCHAR(100) UNIQUE NOT NULL,
    idempotency_key VARCHAR(64) UNIQUE,
    gateway_ref     VARCHAR(255),
    description     TEXT,
    metadata        JSONB DEFAULT '{}',
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transactions_user ON transactions(user_id);
CREATE INDEX idx_transactions_wallet ON transactions(wallet_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_reference ON transactions(reference);
CREATE INDEX idx_transactions_idempotency ON transactions(idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX idx_transactions_created ON transactions(created_at);

-- ============================================================
-- SAVINGS PLANS
-- ============================================================
CREATE TABLE savings_plans (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    wallet_id       UUID NOT NULL REFERENCES wallets(id),
    name            VARCHAR(100) NOT NULL,
    type            VARCHAR(20) NOT NULL
                    CHECK (type IN ('flexible', 'locked', 'target')),
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'matured', 'withdrawn', 'cancelled')),
    target_amount   NUMERIC(20,2),
    current_amount  NUMERIC(20,2) NOT NULL DEFAULT 0.00,
    interest_rate   NUMERIC(5,4) NOT NULL DEFAULT 0.0000,
    lock_duration_days INT,
    maturity_date   TIMESTAMPTZ,
    auto_debit      BOOLEAN NOT NULL DEFAULT FALSE,
    auto_debit_amount NUMERIC(20,2),
    auto_debit_frequency VARCHAR(20) CHECK (auto_debit_frequency IN ('daily', 'weekly', 'monthly')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_savings_user ON savings_plans(user_id);
CREATE INDEX idx_savings_status ON savings_plans(status);

-- ============================================================
-- KYC DOCUMENTS
-- ============================================================
CREATE TABLE kyc_documents (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    document_type   VARCHAR(30) NOT NULL
                    CHECK (document_type IN ('national_id', 'passport', 'driving_license', 'voter_id', 'selfie', 'proof_of_address')),
    file_path       TEXT NOT NULL,
    file_hash       VARCHAR(64) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'rejected')),
    rejection_reason TEXT,
    reviewed_by     UUID,
    reviewed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_kyc_user ON kyc_documents(user_id);
CREATE INDEX idx_kyc_status ON kyc_documents(status);

-- ============================================================
-- AUDIT LOGS (append-only)
-- ============================================================
CREATE TABLE audit_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_type      VARCHAR(10) NOT NULL CHECK (actor_type IN ('user', 'admin', 'system')),
    actor_id        UUID,
    action          VARCHAR(100) NOT NULL,
    resource_type   VARCHAR(50),
    resource_id     UUID,
    ip_address      INET,
    user_agent      TEXT,
    request_body    JSONB,
    response_status INT,
    metadata        JSONB DEFAULT '{}',
    hmac_signature  VARCHAR(128),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_actor ON audit_logs(actor_type, actor_id);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at);

-- ============================================================
-- PAYMENT GATEWAY LOGS
-- ============================================================
CREATE TABLE payment_gateway_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id  UUID REFERENCES transactions(id),
    gateway         VARCHAR(50) NOT NULL,
    direction       VARCHAR(10) NOT NULL CHECK (direction IN ('outbound', 'inbound')),
    endpoint        VARCHAR(500),
    request_body    JSONB,
    response_body   JSONB,
    http_status     INT,
    duration_ms     INT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_gateway_log_txn ON payment_gateway_logs(transaction_id);
CREATE INDEX idx_gateway_log_created ON payment_gateway_logs(created_at);

-- ============================================================
-- ADMIN USERS
-- ============================================================
CREATE TABLE admin_users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    full_name       VARCHAR(255) NOT NULL,
    password_hash   TEXT NOT NULL,
    role            VARCHAR(20) NOT NULL
                    CHECK (role IN ('support', 'finance', 'super_admin')),
    mfa_secret      TEXT,
    mfa_enabled     BOOLEAN NOT NULL DEFAULT FALSE,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'suspended', 'deactivated')),
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_admin_email ON admin_users(email);
CREATE INDEX idx_admin_role ON admin_users(role);

-- ============================================================
-- FEATURE FLAGS
-- ============================================================
CREATE TABLE feature_flags (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(100) UNIQUE NOT NULL,
    description     TEXT,
    enabled         BOOLEAN NOT NULL DEFAULT FALSE,
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- REFRESH TOKENS
-- ============================================================
CREATE TABLE refresh_tokens (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash      VARCHAR(128) NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_token_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_token_hash ON refresh_tokens(token_hash);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    type            VARCHAR(20) NOT NULL CHECK (type IN ('sms', 'email', 'push', 'in_app')),
    title           VARCHAR(255),
    message         TEXT NOT NULL,
    read            BOOLEAN NOT NULL DEFAULT FALSE,
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(user_id, read) WHERE read = FALSE;

-- ============================================================
-- TIER LIMITS
-- ============================================================
CREATE TABLE tier_limits (
    kyc_tier        SMALLINT PRIMARY KEY,
    daily_deposit_limit     NUMERIC(20,2) NOT NULL,
    daily_withdrawal_limit  NUMERIC(20,2) NOT NULL,
    max_balance             NUMERIC(20,2) NOT NULL,
    description             TEXT
);

INSERT INTO tier_limits (kyc_tier, daily_deposit_limit, daily_withdrawal_limit, max_balance, description) VALUES
(0, 50000.00, 0.00, 100000.00, 'Unverified - deposit only, no withdrawal'),
(1, 500000.00, 200000.00, 2000000.00, 'Basic KYC - national ID verified'),
(2, 5000000.00, 2000000.00, 20000000.00, 'Enhanced KYC - full document verification'),
(3, 50000000.00, 20000000.00, 200000000.00, 'Premium - business/high net worth');

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_wallets_updated_at BEFORE UPDATE ON wallets FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_transactions_updated_at BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_savings_updated_at BEFORE UPDATE ON savings_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_kyc_updated_at BEFORE UPDATE ON kyc_documents FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_admin_updated_at BEFORE UPDATE ON admin_users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_flags_updated_at BEFORE UPDATE ON feature_flags FOR EACH ROW EXECUTE FUNCTION update_updated_at();
