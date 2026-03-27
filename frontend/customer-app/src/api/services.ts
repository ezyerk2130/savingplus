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
    name: string; type: string; initial_amount?: number; target_amount?: number;
    lock_duration_days?: number; auto_debit?: boolean; auto_debit_amount?: number;
    auto_debit_frequency?: string
  }) => api.post('/savings/plan', data),
  listPlans: (status?: string) =>
    api.get<{ plans: SavingsPlan[]; total: number }>('/savings/plans', { params: { status } }),
  getPlan: (id: string) => api.get<SavingsPlan>(`/savings/plans/${id}`),
  depositToPlan: (id: string, amount: number) =>
    api.post(`/savings/plans/${id}/deposit`, { amount }),
  withdrawFromPlan: (id: string, amount: number) =>
    api.post(`/savings/plans/${id}/withdraw`, { amount }),
  cancelPlan: (id: string) =>
    api.post(`/savings/plans/${id}/cancel`),
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

export const investmentApi = {
  listProducts: (type?: string) => api.get('/investments/products', { params: { type } }),
  getProduct: (id: string) => api.get(`/investments/products/${id}`),
  invest: (data: { product_id: string; amount: number }) => api.post('/investments', data),
  listInvestments: (params?: { page?: number; status?: string }) => api.get('/investments', { params }),
  withdrawInvestment: (id: string) => api.post(`/investments/${id}/withdraw`),
}

export const groupApi = {
  create: (data: { name: string; description?: string; type: string; contribution_amount: number; frequency: string; max_members: number }) => api.post('/groups', data),
  list: () => api.get('/groups'),
  get: (id: string) => api.get(`/groups/${id}`),
  join: (id: string) => api.post(`/groups/${id}/join`),
  leave: (id: string) => api.post(`/groups/${id}/leave`),
  contribute: (id: string) => api.post(`/groups/${id}/contribute`),
  start: (id: string) => api.post(`/groups/${id}/start`),
}

export const insuranceApi = {
  listProducts: (type?: string) => api.get('/insurance/products', { params: { type } }),
  getProduct: (id: string) => api.get(`/insurance/products/${id}`),
  subscribe: (data: { product_id: string; beneficiary_name?: string; beneficiary_phone?: string }) => api.post('/insurance/subscribe', data),
  listPolicies: () => api.get('/insurance/policies'),
  cancelPolicy: (id: string) => api.post(`/insurance/policies/${id}/cancel`),
}

export const loanApi = {
  checkEligibility: () => api.get('/loans/eligibility'),
  apply: (data: { amount: number; term_days: number }) => api.post('/loans', data),
  list: (params?: { page?: number; status?: string }) => api.get('/loans', { params }),
  get: (id: string) => api.get(`/loans/${id}`),
  repay: (id: string, amount: number) => api.post(`/loans/${id}/repay`, { amount }),
}

export const contentApi = {
  listArticles: (params?: { category?: string; language?: string }) => api.get('/content/articles', { params }),
  getArticle: (id: string, language?: string) => api.get(`/content/articles/${id}`, { params: { language } }),
}
