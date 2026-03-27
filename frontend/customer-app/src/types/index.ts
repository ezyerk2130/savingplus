export interface User {
  id: string
  phone: string
  email?: string
  full_name: string
  kyc_status: 'pending' | 'submitted' | 'under_review' | 'approved' | 'rejected'
  kyc_tier: number
  status: string
  created_at: string
}

export interface TokenPair {
  access_token: string
  refresh_token: string
  expires_in: number
  token_type: string
}

export interface WalletBalance {
  wallet_id: string
  currency: string
  available_balance: string
  locked_balance: string
  total_balance: string
}

export interface Transaction {
  id: string
  type: 'deposit' | 'withdrawal' | 'savings_lock' | 'savings_unlock' | 'fee' | 'interest'
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'reversed'
  amount: string
  fee: string
  currency: string
  reference: string
  description?: string
  created_at: string
  completed_at?: string
}

export interface TransactionList {
  transactions: Transaction[]
  total: number
  page: number
  page_size: number
  total_pages: number
}

export interface SavingsPlan {
  id: string
  name: string
  type: 'flexible' | 'locked' | 'target'
  status: 'active' | 'matured' | 'withdrawn' | 'cancelled'
  target_amount?: string
  current_amount: string
  interest_rate: string
  lock_duration_days?: number
  maturity_date?: string
  auto_debit: boolean
  auto_debit_amount?: string
  auto_debit_frequency?: string
  created_at: string
}

export interface KYCDocument {
  id: string
  document_type: string
  status: 'pending' | 'approved' | 'rejected'
  rejection_reason?: string
  created_at: string
}

export interface KYCStatus {
  kyc_status: string
  kyc_tier: number
  documents: KYCDocument[]
}

export interface Notification {
  id: string
  type: string
  title: string
  message: string
  read: boolean
  created_at: string
}

export interface TierLimits {
  kyc_tier: number
  limits: {
    daily_deposit_limit: string
    daily_withdrawal_limit: string
    max_balance: string
    description: string
  }
}

export interface InvestmentProduct {
  id: string; name: string; description: string; type: string; currency: string;
  min_amount: string; max_amount?: string; expected_return: string;
  available_pool?: string; duration_days?: number; risk_level: string; status: string
}

export interface Investment {
  id: string; product_id: string; product_name: string; product_type: string; amount: string;
  currency: string; expected_return: number; actual_return?: string;
  status: string; maturity_date?: string; created_at: string
}

export interface SavingsGroup {
  id: string; name: string; description?: string; type: string;
  contribution_amount: string; frequency: string; max_members: number;
  currency?: string; total_rounds?: number; start_date?: string;
  next_payout_date?: string; current_round: number; status: string; created_at: string
}

export interface InsuranceProduct {
  id: string; name: string; description: string; type: string; provider: string;
  premium_amount: string; premium_frequency: string; coverage_amount: string;
  coverage_details: string; min_age?: number; max_age?: number; status: string
}

export interface InsurancePolicy {
  id: string; product_id: string; product_name: string; product_type: string; policy_number: string;
  status: string; coverage_start: string; coverage_end: string;
  premium_paid: string; auto_renew?: boolean; beneficiary?: string; created_at: string
}

export interface Loan {
  id: string; loan_number: string; type: string; principal: string;
  interest_rate: number; total_due: string; amount_paid: string;
  currency?: string; collateral_type?: string; collateral_amount?: string;
  disbursed_at?: string; status: string; term_days: number; due_date: string; created_at: string
}

export interface ContentArticle {
  id: string; title: string; body: string; category: string;
  image_url?: string; read_time_min: number; created_at: string
}
