import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import toast from 'react-hot-toast'
import { authApi } from '../api/auth'
import { showError } from '../utils/error'

const schema = z.object({
  full_name: z.string().min(2, 'Name must be at least 2 characters'),
  phone: z.string().min(10, 'Enter a valid phone number').max(15),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  confirm_password: z.string(),
  pin: z.string().length(4, 'PIN must be exactly 4 digits').regex(/^\d+$/, 'PIN must be digits only'),
}).refine((d) => d.password === d.confirm_password, {
  message: 'Passwords do not match',
  path: ['confirm_password'],
})
type FormData = z.infer<typeof schema>

export default function Register() {
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    resolver: zodResolver(schema),
  })

  const onSubmit = async (data: FormData) => {
    setLoading(true)
    try {
      await authApi.register({
        full_name: data.full_name,
        phone: data.phone,
        password: data.password,
        pin: data.pin,
      })
      toast.success('Account created! Please log in.')
      navigate('/login')
    } catch (err: unknown) {
      showError(err, 'Registration failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-white px-4 py-8">
      <div className="w-full max-w-sm">
        <div className="text-center mb-10">
          <h1 className="text-3xl font-bold text-navy-900">Saving<span className="text-primary-700">Plus</span></h1>
          <p className="text-navy-400 mt-2 text-sm">Start saving smarter today</p>
        </div>

        <div className="space-y-6">
          <div>
            <h2 className="text-xl font-bold text-navy-900 mb-1">Create account</h2>
            <p className="text-navy-400 text-sm">It takes less than a minute</p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Full name</label>
              <input {...register('full_name')} className="input-field" placeholder="John Doe" />
              {errors.full_name && <p className="text-danger text-xs mt-1.5">{errors.full_name.message}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Phone number</label>
              <input {...register('phone')} type="tel" className="input-field" placeholder="+255 7XX XXX XXX" />
              {errors.phone && <p className="text-danger text-xs mt-1.5">{errors.phone.message}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Password</label>
              <input {...register('password')} type="password" className="input-field" placeholder="Min 8 characters" />
              {errors.password && <p className="text-danger text-xs mt-1.5">{errors.password.message}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Confirm password</label>
              <input {...register('confirm_password')} type="password" className="input-field" />
              {errors.confirm_password && <p className="text-danger text-xs mt-1.5">{errors.confirm_password.message}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Transaction PIN</label>
              <input {...register('pin')} type="password" maxLength={4} className="input-field" placeholder="4-digit PIN" />
              {errors.pin && <p className="text-danger text-xs mt-1.5">{errors.pin.message}</p>}
              <p className="text-navy-400 text-2xs mt-1">Used to authorize withdrawals and transfers</p>
            </div>

            <button type="submit" disabled={loading} className="btn-primary w-full mt-2">
              {loading ? 'Creating account...' : 'Create account'}
            </button>
          </form>

          <p className="text-center text-sm text-navy-400">
            Already have an account?{' '}
            <Link to="/login" className="text-primary-700 font-semibold hover:underline">Log in</Link>
          </p>
        </div>
      </div>
    </div>
  )
}
