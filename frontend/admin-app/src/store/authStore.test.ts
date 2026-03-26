import { describe, it, expect, beforeEach } from 'vitest'
import { useAdminAuth } from './authStore'

describe('useAdminAuth', () => {
  beforeEach(() => {
    // Reset store to initial state before each test
    useAdminAuth.setState({
      token: null,
      role: null,
      isAuthenticated: false,
    })
  })

  it('starts with unauthenticated state', () => {
    const state = useAdminAuth.getState()
    expect(state.token).toBeNull()
    expect(state.role).toBeNull()
    expect(state.isAuthenticated).toBe(false)
  })

  it('setAuth stores token and role and sets isAuthenticated to true', () => {
    useAdminAuth.getState().setAuth('admin-token-123', 'super_admin')
    const state = useAdminAuth.getState()
    expect(state.token).toBe('admin-token-123')
    expect(state.role).toBe('super_admin')
    expect(state.isAuthenticated).toBe(true)
  })

  it('setAuth works with different roles', () => {
    useAdminAuth.getState().setAuth('token-1', 'support')
    expect(useAdminAuth.getState().role).toBe('support')

    useAdminAuth.getState().setAuth('token-2', 'finance')
    expect(useAdminAuth.getState().role).toBe('finance')
  })

  it('logout clears all state', () => {
    // First set some state
    useAdminAuth.getState().setAuth('admin-token-123', 'super_admin')
    expect(useAdminAuth.getState().isAuthenticated).toBe(true)

    // Then logout
    useAdminAuth.getState().logout()
    const state = useAdminAuth.getState()
    expect(state.token).toBeNull()
    expect(state.role).toBeNull()
    expect(state.isAuthenticated).toBe(false)
  })

  it('isAuthenticated is true when authenticated, false when not', () => {
    expect(useAdminAuth.getState().isAuthenticated).toBe(false)

    useAdminAuth.getState().setAuth('token', 'support')
    expect(useAdminAuth.getState().isAuthenticated).toBe(true)

    useAdminAuth.getState().logout()
    expect(useAdminAuth.getState().isAuthenticated).toBe(false)
  })
})
