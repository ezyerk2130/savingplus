-- Seed data for local development
-- Run after migrations: psql -U savingplus -d savingplus -f seed.sql

-- Create a test admin user (password: Admin@123456, MFA must be set up separately)
-- Password hash is for "Admin@123456" using argon2id
INSERT INTO admin_users (id, email, full_name, password_hash, role, mfa_enabled, status) VALUES
('a0000000-0000-0000-0000-000000000001', 'admin@savingplus.co.tz', 'Super Admin',
 -- Note: In production, use properly hashed passwords. This is a placeholder.
 'placeholder_hash_replace_at_runtime', 'super_admin', FALSE, 'active')
ON CONFLICT (email) DO NOTHING;

INSERT INTO admin_users (id, email, full_name, password_hash, role, mfa_enabled, status) VALUES
('a0000000-0000-0000-0000-000000000002', 'support@savingplus.co.tz', 'Support Agent',
 'placeholder_hash_replace_at_runtime', 'support', FALSE, 'active')
ON CONFLICT (email) DO NOTHING;

INSERT INTO admin_users (id, email, full_name, password_hash, role, mfa_enabled, status) VALUES
('a0000000-0000-0000-0000-000000000003', 'finance@savingplus.co.tz', 'Finance Officer',
 'placeholder_hash_replace_at_runtime', 'finance', FALSE, 'active')
ON CONFLICT (email) DO NOTHING;

-- Feature flags
INSERT INTO feature_flags (name, description, enabled) VALUES
('mobile_money_deposits', 'Enable mobile money deposit feature', TRUE),
('mobile_money_withdrawals', 'Enable mobile money withdrawal feature', TRUE),
('savings_locked_plans', 'Enable locked savings plans', TRUE),
('savings_target_plans', 'Enable target savings plans', TRUE),
('kyc_auto_verify', 'Enable automatic KYC verification via NIDA API', FALSE),
('push_notifications', 'Enable push notifications via FCM', FALSE),
('interest_accrual', 'Enable daily interest accrual job', FALSE),
('maintenance_mode', 'Put platform in maintenance mode', FALSE)
ON CONFLICT (name) DO NOTHING;
