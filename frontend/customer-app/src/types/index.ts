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
