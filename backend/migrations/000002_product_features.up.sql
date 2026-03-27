-- SavingPlus Product Features Migration
-- Migration: 000002_product_features
-- Features: Multi-currency, Investments, Upatu Groups, Insurance, Loans, Content

-- ============================================================
-- MULTI-CURRENCY WALLETS (FlexDollar)
-- Users can have multiple wallets in different currencies
-- ============================================================
ALTER TABLE wallets DROP CONSTRAINT IF EXISTS wallets_user_id_key;
CREATE UNIQUE INDEX idx_wallets_user_currency ON wallets(user_id, currency);

-- Add exchange rates table
CREATE TABLE exchange_rates (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_currency   VARCHAR(3) NOT NULL,
    to_currency     VARCHAR(3) NOT NULL,
    rate            NUMERIC(20,8) NOT NULL CHECK (rate > 0),
    source          VARCHAR(50) NOT NULL DEFAULT 'manual',
    effective_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_exchange_rates_pair ON exchange_rates(from_currency, to_currency, effective_at DESC);

-- Seed USD/TZS rate
INSERT INTO exchange_rates (from_currency, to_currency, rate, source)
VALUES ('USD', 'TZS', 2500.00, 'manual'),
       ('TZS', 'USD', 0.0004, 'manual');

-- Update savings_plans to support currency
ALTER TABLE savings_plans ADD COLUMN IF NOT EXISTS currency VARCHAR(3) NOT NULL DEFAULT 'TZS';

-- ============================================================
-- INVESTMENT PRODUCTS (Investify TZ)
-- ============================================================
CREATE TABLE investment_products (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    type            VARCHAR(30) NOT NULL
                    CHECK (type IN ('fixed_income', 'money_market', 'treasury_bill', 'mutual_fund', 'real_estate')),
    currency        VARCHAR(3) NOT NULL DEFAULT 'TZS',
    min_amount      NUMERIC(20,2) NOT NULL DEFAULT 10000.00,
    max_amount      NUMERIC(20,2),
    expected_return NUMERIC(5,2) NOT NULL,
    duration_days   INT,
    risk_level      VARCHAR(10) NOT NULL CHECK (risk_level IN ('low', 'medium', 'high')),
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'paused', 'closed')),
    total_pool      NUMERIC(20,2) NOT NULL DEFAULT 0.00,
    available_pool  NUMERIC(20,2) NOT NULL DEFAULT 0.00,
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE investments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    product_id      UUID NOT NULL REFERENCES investment_products(id),
    wallet_id       UUID NOT NULL REFERENCES wallets(id),
    amount          NUMERIC(20,2) NOT NULL CHECK (amount > 0),
    currency        VARCHAR(3) NOT NULL DEFAULT 'TZS',
    expected_return NUMERIC(5,2) NOT NULL,
    actual_return   NUMERIC(20,2),
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'matured', 'withdrawn', 'cancelled')),
    maturity_date   TIMESTAMPTZ,
    matured_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_investments_user ON investments(user_id);
CREATE INDEX idx_investments_product ON investments(product_id);
CREATE INDEX idx_investments_status ON investments(status);

-- Seed investment products
INSERT INTO investment_products (name, description, type, min_amount, expected_return, duration_days, risk_level, currency, available_pool) VALUES
('Hatua Fixed Income', 'Government-backed fixed income fund with stable returns', 'fixed_income', 50000, 12.50, 90, 'low', 'TZS', 500000000),
('Jijenge Money Market', 'Short-term money market fund for daily liquidity', 'money_market', 10000, 8.00, NULL, 'low', 'TZS', 1000000000),
('T-Bill 91 Days', '91-day Tanzania Treasury Bill', 'treasury_bill', 100000, 10.50, 91, 'low', 'TZS', 200000000),
('T-Bill 364 Days', '364-day Tanzania Treasury Bill', 'treasury_bill', 100000, 13.00, 364, 'low', 'TZS', 200000000),
('Milele Real Estate Fund', 'Diversified real estate investment trust', 'real_estate', 500000, 18.00, 365, 'medium', 'TZS', 100000000),
('FlexDollar Fund', 'USD-denominated money market fund', 'money_market', 20, 7.00, NULL, 'low', 'USD', 5000000),
('Growth Equity Fund', 'High-growth equity portfolio with higher returns', 'mutual_fund', 100000, 25.00, 365, 'high', 'TZS', 50000000);

-- ============================================================
-- SAVINGS GROUPS / UPATU (Rotating Savings)
-- ============================================================
CREATE TABLE savings_groups (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    type            VARCHAR(20) NOT NULL
                    CHECK (type IN ('upatu', 'goal', 'challenge')),
    created_by      UUID NOT NULL REFERENCES users(id),
    currency        VARCHAR(3) NOT NULL DEFAULT 'TZS',
    contribution_amount NUMERIC(20,2) NOT NULL CHECK (contribution_amount > 0),
    frequency       VARCHAR(20) NOT NULL
                    CHECK (frequency IN ('daily', 'weekly', 'biweekly', 'monthly')),
    max_members     INT NOT NULL DEFAULT 12 CHECK (max_members BETWEEN 2 AND 50),
    current_round   INT NOT NULL DEFAULT 0,
    total_rounds    INT,
    target_amount   NUMERIC(20,2),
    status          VARCHAR(20) NOT NULL DEFAULT 'forming'
                    CHECK (status IN ('forming', 'active', 'completed', 'dissolved')),
    start_date      DATE,
    next_payout_date DATE,
    rules           JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE group_members (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id        UUID NOT NULL REFERENCES savings_groups(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    role            VARCHAR(20) NOT NULL DEFAULT 'member'
                    CHECK (role IN ('admin', 'member')),
    payout_position INT,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'removed', 'left')),
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(group_id, user_id)
);

CREATE TABLE group_contributions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id        UUID NOT NULL REFERENCES savings_groups(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    round_number    INT NOT NULL,
    amount          NUMERIC(20,2) NOT NULL CHECK (amount > 0),
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'paid', 'missed', 'late')),
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE group_payouts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id        UUID NOT NULL REFERENCES savings_groups(id),
    recipient_id    UUID NOT NULL REFERENCES users(id),
    round_number    INT NOT NULL,
    amount          NUMERIC(20,2) NOT NULL CHECK (amount > 0),
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'paid', 'failed')),
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_groups_created_by ON savings_groups(created_by);
CREATE INDEX idx_groups_status ON savings_groups(status);
CREATE INDEX idx_group_members_user ON group_members(user_id);
CREATE INDEX idx_group_members_group ON group_members(group_id);
CREATE INDEX idx_group_contributions_group ON group_contributions(group_id, round_number);
CREATE INDEX idx_group_payouts_group ON group_payouts(group_id, round_number);

-- ============================================================
-- MICRO-INSURANCE
-- ============================================================
CREATE TABLE insurance_products (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    type            VARCHAR(30) NOT NULL
                    CHECK (type IN ('health', 'life', 'crop', 'device', 'travel')),
    provider        VARCHAR(100) NOT NULL,
    premium_amount  NUMERIC(20,2) NOT NULL,
    premium_frequency VARCHAR(20) NOT NULL
                    CHECK (premium_frequency IN ('daily', 'weekly', 'monthly', 'annually')),
    coverage_amount NUMERIC(20,2) NOT NULL,
    coverage_details JSONB NOT NULL DEFAULT '{}',
    min_age         INT DEFAULT 18,
    max_age         INT DEFAULT 65,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'paused', 'discontinued')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE insurance_policies (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    product_id      UUID NOT NULL REFERENCES insurance_products(id),
    policy_number   VARCHAR(50) UNIQUE NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'lapsed', 'claimed', 'cancelled', 'expired')),
    coverage_start  DATE NOT NULL,
    coverage_end    DATE NOT NULL,
    premium_paid    NUMERIC(20,2) NOT NULL DEFAULT 0.00,
    auto_renew      BOOLEAN NOT NULL DEFAULT TRUE,
    beneficiary     JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_policies_user ON insurance_policies(user_id);
CREATE INDEX idx_policies_status ON insurance_policies(status);

-- Seed insurance products
INSERT INTO insurance_products (name, description, type, provider, premium_amount, premium_frequency, coverage_amount, coverage_details) VALUES
('Afya Bima Basic', 'Basic health coverage for outpatient care', 'health', 'Jubilee Insurance TZ', 5000, 'monthly', 500000, '{"outpatient": true, "inpatient": false, "dental": false}'),
('Afya Bima Plus', 'Comprehensive health coverage including inpatient', 'health', 'Jubilee Insurance TZ', 15000, 'monthly', 2000000, '{"outpatient": true, "inpatient": true, "dental": true, "maternity": true}'),
('Maisha Cover', 'Life insurance with savings component', 'life', 'Sanlam Life TZ', 10000, 'monthly', 5000000, '{"death_benefit": true, "disability": true, "savings_component": true}'),
('Kilimo Bima', 'Crop insurance for smallholder farmers', 'crop', 'NFRA Insurance', 3000, 'monthly', 1000000, '{"crops": ["maize", "rice", "beans"], "weather_index": true}'),
('Simu Guard', 'Mobile device protection plan', 'device', 'MicroEnsure TZ', 2000, 'monthly', 300000, '{"theft": true, "damage": true, "screen_crack": true}');

-- ============================================================
-- SAVINGS-BACKED CREDIT (Loans)
-- ============================================================
CREATE TABLE loans (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    wallet_id       UUID NOT NULL REFERENCES wallets(id),
    loan_number     VARCHAR(50) UNIQUE NOT NULL,
    type            VARCHAR(20) NOT NULL DEFAULT 'savings_backed'
                    CHECK (type IN ('savings_backed', 'emergency', 'business')),
    principal       NUMERIC(20,2) NOT NULL CHECK (principal > 0),
    interest_rate   NUMERIC(5,2) NOT NULL,
    total_due       NUMERIC(20,2) NOT NULL,
    amount_paid     NUMERIC(20,2) NOT NULL DEFAULT 0.00,
    currency        VARCHAR(3) NOT NULL DEFAULT 'TZS',
    term_days       INT NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'disbursed', 'repaying', 'paid', 'defaulted', 'rejected')),
    collateral_type VARCHAR(30) DEFAULT 'savings_balance',
    collateral_amount NUMERIC(20,2),
    disbursed_at    TIMESTAMPTZ,
    due_date        DATE NOT NULL,
    approved_by     UUID REFERENCES admin_users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE loan_repayments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id         UUID NOT NULL REFERENCES loans(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    amount          NUMERIC(20,2) NOT NULL CHECK (amount > 0),
    principal_portion NUMERIC(20,2) NOT NULL DEFAULT 0.00,
    interest_portion NUMERIC(20,2) NOT NULL DEFAULT 0.00,
    payment_method  VARCHAR(20),
    status          VARCHAR(20) NOT NULL DEFAULT 'completed'
                    CHECK (status IN ('completed', 'failed', 'reversed')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_loans_user ON loans(user_id);
CREATE INDEX idx_loans_status ON loans(status);
CREATE INDEX idx_repayments_loan ON loan_repayments(loan_id);

-- ============================================================
-- FINANCIAL LITERACY CONTENT
-- ============================================================
CREATE TABLE content_articles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           VARCHAR(255) NOT NULL,
    title_sw        VARCHAR(255),
    body            TEXT NOT NULL,
    body_sw         TEXT,
    category        VARCHAR(30) NOT NULL
                    CHECK (category IN ('saving', 'investing', 'budgeting', 'insurance', 'credit', 'general')),
    image_url       TEXT,
    read_time_min   INT NOT NULL DEFAULT 3,
    published       BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order      INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_content_category ON content_articles(category);
CREATE INDEX idx_content_published ON content_articles(published) WHERE published = TRUE;

-- Seed financial literacy content
INSERT INTO content_articles (title, title_sw, body, body_sw, category, read_time_min, published, sort_order) VALUES
('Why Saving Matters', 'Kwa Nini Kuweka Akiba ni Muhimu', 'Saving money is the foundation of financial security. Even small amounts saved regularly can grow into significant funds over time through compound interest. Start with just 1,000 TZS per day and watch your savings grow.', 'Kuweka akiba ndio msingi wa usalama wa kifedha. Hata kiasi kidogo kinachowekwa mara kwa mara kinaweza kukua na kuwa fedha kubwa kwa muda kupitia riba ya papo kwa papo. Anza na TZS 1,000 kwa siku na uangalie akiba yako ikikua.', 'saving', 3, TRUE, 1),
('Understanding Interest Rates', 'Kuelewa Viwango vya Riba', 'Interest rates determine how fast your money grows. A flexible savings account at 4% p.a. means for every 100,000 TZS saved, you earn 4,000 TZS per year. Locked savings offer higher rates because your money is committed for longer.', 'Viwango vya riba vinaamua jinsi pesa zako zinavyokua haraka. Akaunti ya akiba inayonyumbulika kwa 4% kwa mwaka inamaanisha kwa kila TZS 100,000 zilizohifadhiwa, unapata TZS 4,000 kwa mwaka.', 'saving', 4, TRUE, 2),
('Introduction to Investing', 'Utangulizi wa Uwekezaji', 'Investing allows your money to work harder than regular savings. With investments, you can earn returns of 10-25% annually. However, higher returns come with higher risk. Always diversify your investments across different products.', 'Uwekezaji unaruhusu pesa zako kufanya kazi zaidi kuliko akiba ya kawaida. Kwa uwekezaji, unaweza kupata faida ya 10-25% kwa mwaka. Hata hivyo, faida kubwa inakuja na hatari kubwa zaidi.', 'investing', 5, TRUE, 3),
('What is Upatu?', 'Upatu ni Nini?', 'Upatu is a traditional rotating savings system where a group of people contribute a fixed amount regularly. Each round, one member receives the full pool. It combines social accountability with forced savings discipline.', 'Upatu ni mfumo wa jadi wa akiba ya mzunguko ambapo kundi la watu wanachangia kiasi fulani mara kwa mara. Kila raundi, mwanachama mmoja anapokea mkusanyiko wote.', 'saving', 3, TRUE, 4),
('Managing Your Budget', 'Kusimamia Bajeti Yako', 'The 50/30/20 rule is simple: spend 50% of income on needs, 30% on wants, and save 20%. Track your spending for one month to understand where your money goes. Small leaks can sink a big ship.', 'Kanuni ya 50/30/20 ni rahisi: tumia 50% ya mapato kwa mahitaji, 30% kwa matakwa, na weka akiba 20%. Fuatilia matumizi yako kwa mwezi mmoja kuelewa pesa zako zinaenda wapi.', 'budgeting', 4, TRUE, 5),
('Insurance for Everyone', 'Bima kwa Kila Mtu', 'Micro-insurance protects you from unexpected costs. For as little as 2,000 TZS per month, you can protect your phone. Health insurance at 5,000 TZS/month covers outpatient care up to 500,000 TZS.', 'Bima ndogo inakuhifadhi kutokana na gharama zisizotarajiwa. Kwa TZS 2,000 tu kwa mwezi, unaweza kulinda simu yako. Bima ya afya kwa TZS 5,000/mwezi inashughulikia huduma za nje hadi TZS 500,000.', 'insurance', 3, TRUE, 6),
('Building Good Credit', 'Kujenga Rekodi Nzuri ya Mikopo', 'Your savings history builds your credit score. The more consistently you save, the higher your borrowing limit. Start small, repay on time, and your credit limit will grow automatically.', 'Historia yako ya akiba inajenga alama yako ya mkopo. Kadri unavyoweka akiba kwa uthabiti zaidi, ndivyo kikomo chako cha kukopa kinavyoongezeka. Anza kidogo, lipa kwa wakati, na kikomo chako cha mkopo kitaongezeka.', 'credit', 3, TRUE, 7);

-- ============================================================
-- USER PREFERENCES (language, country)
-- ============================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS language VARCHAR(5) NOT NULL DEFAULT 'sw';
ALTER TABLE users ADD COLUMN IF NOT EXISTS country VARCHAR(2) NOT NULL DEFAULT 'TZ';

-- Update transaction types to include new types
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_type_check
    CHECK (type IN ('deposit', 'withdrawal', 'savings_lock', 'savings_unlock', 'fee', 'interest',
                    'adjustment', 'investment', 'investment_return', 'loan_disbursement', 'loan_repayment',
                    'insurance_premium', 'insurance_claim', 'group_contribution', 'group_payout', 'currency_exchange'));

-- Triggers for new tables
CREATE TRIGGER trg_investment_products_updated_at BEFORE UPDATE ON investment_products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_investments_updated_at BEFORE UPDATE ON investments FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_groups_updated_at BEFORE UPDATE ON savings_groups FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_insurance_products_updated_at BEFORE UPDATE ON insurance_products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_policies_updated_at BEFORE UPDATE ON insurance_policies FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_loans_updated_at BEFORE UPDATE ON loans FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_content_updated_at BEFORE UPDATE ON content_articles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Feature flags for new features
INSERT INTO feature_flags (name, description, enabled) VALUES
('flex_dollar', 'USD/FlexDollar savings accounts', TRUE),
('investify', 'Investment marketplace (Investify TZ)', TRUE),
('upatu', 'Group savings / Upatu rotating savings', TRUE),
('micro_insurance', 'Embedded micro-insurance products', TRUE),
('savings_credit', 'Savings-backed credit / loans', FALSE),
('swahili_ui', 'Swahili language interface', TRUE),
('financial_literacy', 'Financial literacy content module', TRUE),
('ussd_access', 'USSD access for feature phones', FALSE)
ON CONFLICT (name) DO NOTHING;
