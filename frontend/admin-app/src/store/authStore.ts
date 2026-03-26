import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface AdminAuthState {
  token: string | null
  role: string | null
  isAuthenticated: boolean
  setAuth: (token: string, role: string) => void
  logout: () => void
}

export const useAdminAuth = create<AdminAuthState>()(
  persist(
    (set) => ({
      token: null,
      role: null,
      isAuthenticated: false,
      setAuth: (token, role) => set({ token, role, isAuthenticated: true }),
      logout: () => set({ token: null, role: null, isAuthenticated: false }),
    }),
    { name: 'savingplus-admin-auth' }
  )
)
