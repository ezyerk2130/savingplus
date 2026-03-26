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

  changePassword: (data: { current_password: string; new_password: string }) =>
    api.post('/auth/change-password', data),

  changePIN: (data: { current_pin: string; new_pin: string }) =>
    api.post('/auth/change-pin', data),

  logout: (refresh_token: string) =>
    api.post('/auth/logout', { refresh_token }),
}
