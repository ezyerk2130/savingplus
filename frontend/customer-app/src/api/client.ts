import axios from 'axios'
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

// Response interceptor: auto-refresh on 401
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const original = error.config
    if (error.response?.status === 401 && !original._retry) {
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
