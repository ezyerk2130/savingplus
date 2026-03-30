-- Migration: 000003 - Group invite codes + User 2FA

-- Add invite code to groups for shareable joining
ALTER TABLE savings_groups ADD COLUMN IF NOT EXISTS invite_code VARCHAR(6) UNIQUE;

-- Generate 6-digit codes for existing groups
UPDATE savings_groups SET invite_code = LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0')
WHERE invite_code IS NULL;

ALTER TABLE savings_groups ALTER COLUMN invite_code SET NOT NULL;
ALTER TABLE savings_groups ALTER COLUMN invite_code SET DEFAULT LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');

CREATE INDEX IF NOT EXISTS idx_groups_invite_code ON savings_groups(invite_code);

-- Add 2FA fields to users table for customer-level TOTP
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_secret TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE;
