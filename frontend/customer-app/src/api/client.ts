import axios from 'axios'
import toast from 'react-hot-toast'
import { useAuthStore } from '../store/authStore'

const api = axios.create({
  baseURL: (import.meta as any).env?.VITE_API_URL || '/api/v1',
  headers: { 'Content-Type': 'application/json' },
})

// Request interceptor: attach JWT
api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().accessToken
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// Response interceptor: handle 401 refresh and 429 rate limit
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const status = error.response?.status

    // Rate limited - show user-friendly message, don't retry
    if (status === 429) {
      const retryAfter = error.response?.data?.retry_after || '1s'
      toast.error(`Too many requests. Please wait ${retryAfter} and try again.`, {
        id: 'rate-limit', // prevent duplicate toasts
        duration: 4000,
      })
      return Promise.reject(error)
    }

    // Token expired - try refresh
    const original = error.config
    if (status === 401 && !original._retry) {
      original._retry = true
      const store = useAuthStore.getState()
      const refreshToken = store.refreshToken
      if (refreshToken) {
        try {
          const baseURL = (import.meta as any).env?.VITE_API_URL || '/api/v1'
          const res = await axios.post(`${baseURL}/auth/refresh`, {
            refresh_token: refreshToken,
          })
          store.setTokens(res.data.access_token, res.data.refresh_token)
          original.headers.Authorization = `Bearer ${res.data.access_token}`
          return api(original)
        } catch {
          store.logout()
          window.location.href = '/login'
        }
      }
    }

    return Promise.reject(error)
  }
)

export default api
