import { describe, it, expect, beforeEach } from 'vitest'
import { useAuthStore } from './authStore'

describe('useAuthStore', () => {
  beforeEach(() => {
    // Reset store to initial state before each test
    useAuthStore.setState({
      accessToken: null,
      refreshToken: null,
      user: null,
      isAuthenticated: false,
    })
  })

  it('starts with unauthenticated state', () => {
    const state = useAuthStore.getState()
    expect(state.accessToken).toBeNull()
    expect(state.refreshToken).toBeNull()
    expect(state.user).toBeNull()
    expect(state.isAuthenticated).toBe(false)
  })

  it('setTokens stores tokens and sets isAuthenticated to true', () => {
    useAuthStore.getState().setTokens('access-123', 'refresh-456')
    const state = useAuthStore.getState()
    expect(state.accessToken).toBe('access-123')
    expect(state.refreshToken).toBe('refresh-456')
    expect(state.isAuthenticated).toBe(true)
  })

  it('setUser stores user correctly', () => {
    const user = {
      id: 'user-1',
      phone: '+255700000000',
      full_name: 'John Doe',
      kyc_status: 'pending' as const,
      kyc_tier: 0,
      status: 'active',
      created_at: '2024-01-01T00:00:00Z',
    }
    useAuthStore.getState().setUser(user)
    const state = useAuthStore.getState()
    expect(state.user).toEqual(user)
    expect(state.user?.full_name).toBe('John Doe')
    expect(state.user?.phone).toBe('+255700000000')
  })

  it('logout clears all state', () => {
    // First set some state
    useAuthStore.getState().setTokens('access-123', 'refresh-456')
    useAuthStore.getState().setUser({
      id: 'user-1',
      phone: '+255700000000',
      full_name: 'John Doe',
      kyc_status: 'approved',
      kyc_tier: 2,
      status: 'active',
      created_at: '2024-01-01T00:00:00Z',
    })

    // Then logout
    useAuthStore.getState().logout()
    const state = useAuthStore.getState()
    expect(state.accessToken).toBeNull()
    expect(state.refreshToken).toBeNull()
    expect(state.user).toBeNull()
    expect(state.isAuthenticated).toBe(false)
  })

  it('isAuthenticated is true when tokens exist, false when not', () => {
    expect(useAuthStore.getState().isAuthenticated).toBe(false)

    useAuthStore.getState().setTokens('a', 'b')
    expect(useAuthStore.getState().isAuthenticated).toBe(true)

    useAuthStore.getState().logout()
    expect(useAuthStore.getState().isAuthenticated).toBe(false)
  })
})
