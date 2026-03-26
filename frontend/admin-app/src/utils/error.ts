import toast from 'react-hot-toast'

// Extract error message from API error response, with consistent fallback chain
export function getErrorMessage(err: unknown, fallback = 'Something went wrong'): string {
  if (err && typeof err === 'object' && 'response' in err) {
    const resp = (err as any).response
    return resp?.data?.detail || resp?.data?.error || resp?.data?.message || fallback
  }
  if (err instanceof Error) return err.message
  return fallback
}

// Show error toast from API error
export function showError(err: unknown, fallback = 'Something went wrong') {
  toast.error(getErrorMessage(err, fallback))
}

// Show error toast for data loading failures
export function showLoadError(err: unknown, context = 'data') {
  toast.error(getErrorMessage(err, `Failed to load ${context}`))
}
