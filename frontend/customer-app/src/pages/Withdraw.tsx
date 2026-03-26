import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import toast from 'react-hot-toast'
import { walletApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { WalletBalance } from '../types'

const schema = z.object({
  amount: z.number({ coerce: true }).positive().min(1000, 'Minimum withdrawal is TZS 1,000'),
  pin: z.string().length(4, 'PIN must be 4 digits'),
  payment_method: z.enum(['mpesa', 'tigopesa', 'airtel', 'halopesa']),
  phone_number: z.string().min(10, 'Enter a valid phone number'),
  otp_code: z.string().optional(),
})
type FormData = z.infer<typeof schema>

export default function Withdraw() {
  const [loading, setLoading] = useState(false)
  const [balance, setBalance] = useState<WalletBalance | null>(null)
  const [needsOtp, setNeedsOtp] = useState(false)
  const navigate = useNavigate()

  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { payment_method: 'mpesa' },
  })

  useEffect(() => {
    walletApi.getBalance().then((res) => setBalance(res.data)).catch((err: unknown) => showLoadError(err, 'balance'))
  }, [])

  const onSubmit = async (data: FormData) => {
    if (needsOtp && (!data.otp_code || data.otp_code.length !== 6)) {
      toast.error('Please enter the 6-digit OTP code')
      return
    }
    setLoading(true)
    try {
      const idempotencyKey = crypto.randomUUID()
      await walletApi.withdraw({ ...data, idempotency_key: idempotencyKey })
      toast.success('Withdrawal initiated! You will receive the money shortly.')
      navigate('/transactions')
    } catch (err: unknown) {
      if (err && typeof err === 'object' && 'response' in err) {
        const error = (err as any).response?.data
        if (error?.error === 'stepup_required') {
          setNeedsOtp(true)
          toast('Please enter OTP sent to your phone for this high-value withdrawal')
          return
        }
      }
      showError(err, 'Withdrawal failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <h1 className="text-2xl font-bold">Withdraw Money</h1>

      {balance && (
        <div className="card bg-gray-50">
          <p className="text-sm text-gray-600">Available Balance</p>
          <p className="text-2xl font-bold text-gray-900">
            TZS {new Intl.NumberFormat('en-TZ').format(parseFloat(balance.available_balance))}
          </p>
        </div>
      )}

      <div className="card">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Amount (TZS)</label>
            <input {...register('amount')} type="number" className="input-field text-lg" placeholder="10,000" />
            {errors.amount && <p className="text-red-500 text-xs mt-1">{errors.amount.message}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Transaction PIN</label>
            <input {...register('pin')} type="password" maxLength={4} className="input-field" placeholder="****" />
            {errors.pin && <p className="text-red-500 text-xs mt-1">{errors.pin.message}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Payment Method</label>
            <select {...register('payment_method')} className="input-field">
              <option value="mpesa">M-Pesa (Vodacom)</option>
              <option value="tigopesa">Tigo Pesa</option>
              <option value="airtel">Airtel Money</option>
              <option value="halopesa">Halopesa</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Receive to Number</label>
            <input {...register('phone_number')} type="tel" className="input-field" placeholder="+255 7XX XXX XXX" />
            {errors.phone_number && <p className="text-red-500 text-xs mt-1">{errors.phone_number.message}</p>}
          </div>

          {needsOtp && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">OTP Code</label>
              <input {...register('otp_code')} className="input-field" placeholder="6-digit OTP" maxLength={6} />
            </div>
          )}

          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? 'Processing...' : 'Withdraw'}
          </button>
        </form>
      </div>
    </div>
  )
}
