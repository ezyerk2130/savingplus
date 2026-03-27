import toast from 'react-hot-toast'

/**
 * Check if an error is a rate limit (429) response.
 * The API client interceptor already shows a toast for these,
 * so callers should skip showing duplicate errors.
 */
export function isRateLimited(err: unknown): boolean {
  if (err && typeof err === 'object' && 'response' in err) {
    return (err as any).response?.status === 429
  }
  return false
}

/**
 * Extract a human-readable error message from an API error response.
 */
export function getErrorMessage(err: unknown, fallback = 'Something went wrong'): string {
  if (err && typeof err === 'object' && 'response' in err) {
    const data = (err as any).response?.data
    return data?.detail || data?.error || data?.message || fallback
  }
  if (err instanceof Error) return err.message
  return fallback
}

/**
 * Show an error toast from an API error.
 * Skips 429 errors (already handled by the API client interceptor).
 */
export function showError(err: unknown, fallback = 'Something went wrong') {
  if (isRateLimited(err)) return
  toast.error(getErrorMessage(err, fallback))
}

/**
 * Show an error toast for data-loading failures.
 * Skips 429 errors (already handled by the API client interceptor).
 */
export function showLoadError(err: unknown, context = 'data') {
  if (isRateLimited(err)) return
  toast.error(getErrorMessage(err, `Failed to load ${context}`))
}
