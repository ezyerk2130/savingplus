import axios from 'axios'
import { useAdminAuth } from '../store/authStore'

const api = axios.create({
  baseURL: (import.meta as any).env?.VITE_API_URL || '/api/v1/admin',
  headers: { 'Content-Type': 'application/json' },
})

api.interceptors.request.use((config) => {
  const token = useAdminAuth.getState().token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      useAdminAuth.getState().logout()
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

export default api
