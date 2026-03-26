import api from './client'
import type { TokenPair } from '../types'

export const authApi = {
  register: (data: { phone: string; full_name: string; password: string; pin: string }) =>
    api.post<{ message: string; user_id: string }>('/auth/register', data),

  login: (data: { phone: string; password: string }) =>
    api.post<TokenPair>('/auth/login', data),

  refresh: (refresh_token: string) =>
    api.post<TokenPair>('/auth/refresh', { refresh_token }),

  verifyOtp: (data: { phone: string; code: string }) =>
    api.post<{ message: string; verified: boolean }>('/auth/verify-otp', data),

  sendOtp: (phone: string) =>
    api.post('/auth/send-otp', { phone }),
}
