import axios from 'axios'
import toast from 'react-hot-toast'
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
    const status = err.response?.status

    // Rate limited
    if (status === 429) {
      toast('Loading... please wait a moment', {
        id: 'rate-limit',
        icon: '⏳',
        duration: 2000,
      })
      return Promise.reject(err)
    }

    // Unauthorized
    if (status === 401) {
      useAdminAuth.getState().logout()
      window.location.href = '/login'
    }

    return Promise.reject(err)
  }
)

export default api
