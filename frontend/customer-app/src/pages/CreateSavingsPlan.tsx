import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import toast from 'react-hot-toast'
import { savingsApi } from '../api/services'

const schema = z.object({
  name: z.string().min(1, 'Plan name is required').max(100),
  type: z.enum(['flexible', 'locked', 'target']),
  target_amount: z.number({ coerce: true }).positive().optional().or(z.literal(0)),
  lock_duration_days: z.number({ coerce: true }).int().min(30).optional().or(z.literal(0)),
  auto_debit: z.boolean().optional(),
  auto_debit_amount: z.number({ coerce: true }).positive().optional().or(z.literal(0)),
  auto_debit_frequency: z.enum(['daily', 'weekly', 'monthly']).optional(),
})
type FormData = z.infer<typeof schema>

const planTypes = [
  { value: 'flexible', label: 'Flexible', desc: 'Withdraw anytime. 4% p.a.', color: 'border-blue-500' },
  { value: 'locked', label: 'Locked', desc: 'Higher returns, fixed term. 8% p.a.', color: 'border-purple-500' },
  { value: 'target', label: 'Target', desc: 'Save towards a goal. 6% p.a.', color: 'border-green-500' },
]

export default function CreateSavingsPlan() {
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const { register, handleSubmit, formState: { errors }, watch } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { type: 'flexible', auto_debit: false },
  })

  const planType = watch('type')
  const autoDebit = watch('auto_debit')

  const onSubmit = async (data: FormData) => {
    setLoading(true)
    try {
      const payload: any = { name: data.name, type: data.type }
      if (data.type === 'target' && data.target_amount) payload.target_amount = data.target_amount
      if (data.type === 'locked' && data.lock_duration_days) payload.lock_duration_days = data.lock_duration_days
      if (data.auto_debit) {
        payload.auto_debit = true
        payload.auto_debit_amount = data.auto_debit_amount
        payload.auto_debit_frequency = data.auto_debit_frequency
      }
      await savingsApi.createPlan(payload)
      toast.success('Savings plan created!')
      navigate('/savings')
    } catch (err: any) {
      toast.error(err.response?.data?.detail || err.response?.data?.error || 'Failed to create plan')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <h1 className="text-2xl font-bold">Create Savings Plan</h1>

      <div className="card">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Plan Name</label>
            <input {...register('name')} className="input-field" placeholder="e.g., Emergency Fund" />
            {errors.name && <p className="text-red-500 text-xs mt-1">{errors.name.message}</p>}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Plan Type</label>
            <div className="grid grid-cols-3 gap-3">
              {planTypes.map((pt) => (
                <label
                  key={pt.value}
                  className={`p-3 rounded-lg border-2 cursor-pointer text-center transition-all ${
                    planType === pt.value ? `${pt.color} bg-gray-50` : 'border-gray-200 hover:border-gray-300'
                  }`}
                >
                  <input {...register('type')} type="radio" value={pt.value} className="hidden" />
                  <p className="font-medium text-sm">{pt.label}</p>
                  <p className="text-xs text-gray-500 mt-1">{pt.desc}</p>
                </label>
              ))}
            </div>
          </div>

          {planType === 'target' && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Target Amount (TZS)</label>
              <input {...register('target_amount')} type="number" className="input-field" placeholder="500,000" />
            </div>
          )}

          {planType === 'locked' && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Lock Duration (days, min 30)</label>
              <input {...register('lock_duration_days')} type="number" min={30} className="input-field" placeholder="90" />
            </div>
          )}

          <div className="flex items-center gap-2">
            <input {...register('auto_debit')} type="checkbox" id="auto_debit" className="rounded border-gray-300" />
            <label htmlFor="auto_debit" className="text-sm font-medium text-gray-700">Enable auto-debit</label>
          </div>

          {autoDebit && (
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Amount (TZS)</label>
                <input {...register('auto_debit_amount')} type="number" className="input-field" placeholder="10,000" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Frequency</label>
                <select {...register('auto_debit_frequency')} className="input-field">
                  <option value="daily">Daily</option>
                  <option value="weekly">Weekly</option>
                  <option value="monthly">Monthly</option>
                </select>
              </div>
            </div>
          )}

          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? 'Creating...' : 'Create Plan'}
          </button>
        </form>
      </div>
    </div>
  )
}
