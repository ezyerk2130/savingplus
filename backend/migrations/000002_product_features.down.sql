-- Rollback: 000002_product_features

DROP TABLE IF EXISTS loan_repayments CASCADE;
DROP TABLE IF EXISTS loans CASCADE;
DROP TABLE IF EXISTS insurance_policies CASCADE;
DROP TABLE IF EXISTS insurance_products CASCADE;
DROP TABLE IF EXISTS group_payouts CASCADE;
DROP TABLE IF EXISTS group_contributions CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS savings_groups CASCADE;
DROP TABLE IF EXISTS investments CASCADE;
DROP TABLE IF EXISTS investment_products CASCADE;
DROP TABLE IF EXISTS exchange_rates CASCADE;
DROP TABLE IF EXISTS content_articles CASCADE;

ALTER TABLE users DROP COLUMN IF EXISTS language;
ALTER TABLE users DROP COLUMN IF EXISTS country;
ALTER TABLE savings_plans DROP COLUMN IF EXISTS currency;

DELETE FROM feature_flags WHERE name IN ('flex_dollar', 'investify', 'upatu', 'micro_insurance', 'savings_credit', 'swahili_ui', 'financial_literacy', 'ussd_access');

-- Restore original transaction type constraint
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_type_check
    CHECK (type IN ('deposit', 'withdrawal', 'savings_lock', 'savings_unlock', 'fee', 'interest', 'adjustment'));

-- Restore unique wallet per user
DROP INDEX IF EXISTS idx_wallets_user_currency;
ALTER TABLE wallets ADD CONSTRAINT wallets_user_id_key UNIQUE (user_id);
