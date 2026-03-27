import { describe, it, expect } from 'vitest'
import { getErrorMessage, isRateLimited } from './error'

describe('getErrorMessage', () => {
  it('extracts detail from axios-like error response', () => {
    const err = {
      response: {
        data: {
          detail: 'Phone number already registered',
        },
      },
    }
    expect(getErrorMessage(err)).toBe('Phone number already registered')
  })

  it('falls back to response.data.error when detail is absent', () => {
    const err = {
      response: {
        data: {
          error: 'Invalid credentials',
        },
      },
    }
    expect(getErrorMessage(err)).toBe('Invalid credentials')
  })

  it('falls back to response.data.message when detail and error are absent', () => {
    const err = {
      response: {
        data: {
          message: 'Rate limit exceeded',
        },
      },
    }
    expect(getErrorMessage(err)).toBe('Rate limit exceeded')
  })

  it('returns message from Error instance', () => {
    const err = new Error('Network failure')
    expect(getErrorMessage(err)).toBe('Network failure')
  })

  it('returns default fallback for null', () => {
    expect(getErrorMessage(null)).toBe('Something went wrong')
  })

  it('returns default fallback for undefined', () => {
    expect(getErrorMessage(undefined)).toBe('Something went wrong')
  })

  it('returns custom fallback string', () => {
    expect(getErrorMessage(null, 'Custom error')).toBe('Custom error')
  })

  it('returns fallback when response exists but data is empty', () => {
    const err = { response: { data: {} } }
    expect(getErrorMessage(err)).toBe('Something went wrong')
  })
})

describe('isRateLimited', () => {
  it('returns true for 429 status', () => {
    const err = { response: { status: 429, data: { error: 'rate_limited' } } }
    expect(isRateLimited(err)).toBe(true)
  })

  it('returns false for other status codes', () => {
    expect(isRateLimited({ response: { status: 400 } })).toBe(false)
    expect(isRateLimited({ response: { status: 500 } })).toBe(false)
    expect(isRateLimited({ response: { status: 401 } })).toBe(false)
  })

  it('returns false for non-response errors', () => {
    expect(isRateLimited(new Error('network'))).toBe(false)
    expect(isRateLimited(null)).toBe(false)
    expect(isRateLimited(undefined)).toBe(false)
  })
})
