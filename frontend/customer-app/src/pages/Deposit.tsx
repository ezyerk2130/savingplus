import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import toast from 'react-hot-toast'
import { walletApi } from '../api/services'
import { showError } from '../utils/error'

const schema = z.object({
  amount: z.number({ coerce: true }).positive('Amount must be greater than 0').min(1000, 'Minimum deposit is TZS 1,000'),
  payment_method: z.enum(['mpesa', 'tigopesa', 'airtel', 'halopesa']),
  phone_number: z.string().min(10, 'Enter a valid phone number'),
})
type FormData = z.infer<typeof schema>

const paymentMethods = [
  { value: 'mpesa', label: 'M-Pesa (Vodacom)', color: 'bg-red-100 text-red-700' },
  { value: 'tigopesa', label: 'Tigo Pesa', color: 'bg-blue-100 text-blue-700' },
  { value: 'airtel', label: 'Airtel Money', color: 'bg-red-100 text-red-600' },
  { value: 'halopesa', label: 'Halotel Halopesa', color: 'bg-orange-100 text-orange-700' },
]

export default function Deposit() {
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const { register, handleSubmit, formState: { errors }, watch } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { payment_method: 'mpesa' },
  })

  const onSubmit = async (data: FormData) => {
    setLoading(true)
    try {
      const idempotencyKey = crypto.randomUUID()
      await walletApi.deposit({
        ...data,
        idempotency_key: idempotencyKey,
      })
      toast.success('Deposit initiated! Check your phone for the mobile money prompt.')
      navigate('/transactions')
    } catch (err: unknown) {
      showError(err, 'Deposit failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <h1 className="text-2xl font-bold">Deposit Money</h1>

      <div className="card">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Amount (TZS)</label>
            <input
              {...register('amount')}
              type="number"
              className="input-field text-lg"
              placeholder="10,000"
            />
            {errors.amount && <p className="text-red-500 text-xs mt-1">{errors.amount.message}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Payment Method</label>
            <div className="grid grid-cols-2 gap-3">
              {paymentMethods.map((m) => (
                <label
                  key={m.value}
                  className={`flex items-center gap-2 p-3 rounded-lg border-2 cursor-pointer transition-all ${
                    watch('payment_method') === m.value
                      ? 'border-primary-500 bg-primary-50'
                      : 'border-gray-200 hover:border-gray-300'
                  }`}
                >
                  <input {...register('payment_method')} type="radio" value={m.value} className="hidden" />
                  <span className={`text-xs font-medium px-2 py-0.5 rounded ${m.color}`}>
                    {m.label}
                  </span>
                </label>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mobile Money Number</label>
            <input
              {...register('phone_number')}
              type="tel"
              className="input-field"
              placeholder="+255 7XX XXX XXX"
            />
            {errors.phone_number && <p className="text-red-500 text-xs mt-1">{errors.phone_number.message}</p>}
          </div>

          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? 'Processing...' : 'Deposit'}
          </button>
        </form>
      </div>
    </div>
  )
}
