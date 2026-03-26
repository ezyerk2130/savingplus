import { describe, it, expect } from 'vitest'
import type {
  User,
  TokenPair,
  WalletBalance,
  Transaction,
  TransactionList,
  SavingsPlan,
  KYCDocument,
  KYCStatus,
  Notification,
  TierLimits,
} from './index'

describe('Type definitions', () => {
  it('User interface has correct structure', () => {
    const user: User = {
      id: 'uuid-1',
      phone: '+255700000000',
      full_name: 'Jane Doe',
      kyc_status: 'approved',
      kyc_tier: 2,
      status: 'active',
      created_at: '2024-01-01T00:00:00Z',
    }
    expect(user.id).toBe('uuid-1')
    expect(user.kyc_status).toBe('approved')
    expect(user.email).toBeUndefined()
  })

  it('User interface accepts optional email', () => {
    const user: User = {
      id: 'uuid-2',
      phone: '+255700000001',
      email: 'jane@example.com',
      full_name: 'Jane Doe',
      kyc_status: 'pending',
      kyc_tier: 0,
      status: 'active',
      created_at: '2024-01-01T00:00:00Z',
    }
    expect(user.email).toBe('jane@example.com')
  })

  it('TokenPair interface has correct structure', () => {
    const tokens: TokenPair = {
      access_token: 'eyJhbGciOiJIUzI1NiJ9...',
      refresh_token: 'refresh-token-value',
      expires_in: 900,
      token_type: 'Bearer',
    }
    expect(tokens.expires_in).toBe(900)
    expect(tokens.token_type).toBe('Bearer')
  })

  it('WalletBalance interface has correct structure', () => {
    const wallet: WalletBalance = {
      wallet_id: 'wallet-1',
      currency: 'TZS',
      available_balance: '50000.00',
      locked_balance: '10000.00',
      total_balance: '60000.00',
    }
    expect(wallet.currency).toBe('TZS')
    expect(wallet.available_balance).toBe('50000.00')
  })

  it('Transaction interface has correct structure', () => {
    const tx: Transaction = {
      id: 'tx-1',
      type: 'deposit',
      status: 'completed',
      amount: '25000.00',
      fee: '500.00',
      currency: 'TZS',
      reference: 'REF-001',
      created_at: '2024-06-01T12:00:00Z',
      completed_at: '2024-06-01T12:01:00Z',
    }
    expect(tx.type).toBe('deposit')
    expect(tx.status).toBe('completed')
    expect(tx.description).toBeUndefined()
  })

  it('TransactionList interface has pagination fields', () => {
    const list: TransactionList = {
      transactions: [],
      total: 0,
      page: 1,
      page_size: 20,
      total_pages: 0,
    }
    expect(list.transactions).toHaveLength(0)
    expect(list.page).toBe(1)
  })

  it('SavingsPlan interface has correct structure', () => {
    const plan: SavingsPlan = {
      id: 'plan-1',
      name: 'Emergency Fund',
      type: 'flexible',
      status: 'active',
      current_amount: '100000.00',
      interest_rate: '5.5',
      auto_debit: false,
      created_at: '2024-01-15T00:00:00Z',
    }
    expect(plan.type).toBe('flexible')
    expect(plan.target_amount).toBeUndefined()
    expect(plan.lock_duration_days).toBeUndefined()
  })

  it('KYCDocument and KYCStatus interfaces have correct structure', () => {
    const doc: KYCDocument = {
      id: 'doc-1',
      document_type: 'national_id',
      status: 'approved',
      created_at: '2024-03-01T00:00:00Z',
    }
    const kycStatus: KYCStatus = {
      kyc_status: 'approved',
      kyc_tier: 2,
      documents: [doc],
    }
    expect(kycStatus.documents).toHaveLength(1)
    expect(kycStatus.documents[0].document_type).toBe('national_id')
    expect(doc.rejection_reason).toBeUndefined()
  })

  it('Notification interface has correct structure', () => {
    const notification: Notification = {
      id: 'notif-1',
      type: 'transaction',
      title: 'Deposit Received',
      message: 'Your deposit of TZS 50,000 has been received.',
      read: false,
      created_at: '2024-06-15T10:00:00Z',
    }
    expect(notification.read).toBe(false)
    expect(notification.type).toBe('transaction')
  })

  it('TierLimits interface has correct structure', () => {
    const tierLimits: TierLimits = {
      kyc_tier: 1,
      limits: {
        daily_deposit_limit: '500000.00',
        daily_withdrawal_limit: '200000.00',
        max_balance: '1000000.00',
        description: 'Basic tier with phone verification',
      },
    }
    expect(tierLimits.kyc_tier).toBe(1)
    expect(tierLimits.limits.daily_deposit_limit).toBe('500000.00')
  })
})
