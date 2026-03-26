import api from './client'
import type {
  User, WalletBalance, TransactionList, SavingsPlan, KYCStatus, Notification, TierLimits,
} from '../types'

export const userApi = {
  getProfile: () => api.get<User>('/profile'),
  updateProfile: (data: { full_name?: string; email?: string }) =>
    api.put('/profile', data),
  getTierLimits: () => api.get<TierLimits>('/profile/limits'),
}

export const walletApi = {
  getBalance: () => api.get<WalletBalance>('/wallet/balance'),
  deposit: (data: {
    amount: number; payment_method: string; phone_number: string; idempotency_key: string
  }) => api.post('/wallet/deposit', data),
  withdraw: (data: {
    amount: number; pin: string; payment_method: string; phone_number: string;
    idempotency_key: string; otp_code?: string
  }) => api.post('/wallet/withdraw', data),
}

export const transactionApi = {
  list: (params?: { page?: number; page_size?: number; type?: string; status?: string }) =>
    api.get<TransactionList>('/transactions', { params }),
  getById: (id: string) => api.get<TransactionList['transactions'][0]>(`/transactions/${id}`),
}

export const savingsApi = {
  createPlan: (data: {
    name: string; type: string; target_amount?: number; lock_duration_days?: number;
    auto_debit?: boolean; auto_debit_amount?: number; auto_debit_frequency?: string
  }) => api.post('/savings/plan', data),
  listPlans: (status?: string) =>
    api.get<{ plans: SavingsPlan[]; total: number }>('/savings/plans', { params: { status } }),
  getPlan: (id: string) => api.get<SavingsPlan>(`/savings/plans/${id}`),
}

export const kycApi = {
  upload: (formData: FormData) =>
    api.post('/kyc/upload', formData, { headers: { 'Content-Type': 'multipart/form-data' } }),
  getStatus: () => api.get<KYCStatus>('/kyc/status'),
}

export const notificationApi = {
  list: () => api.get<{ notifications: Notification[]; unread_count: number }>('/notifications'),
  markRead: (id: string) => api.put(`/notifications/${id}/read`),
  markAllRead: () => api.put('/notifications/read-all'),
}
