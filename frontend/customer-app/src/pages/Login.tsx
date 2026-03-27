import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import toast from 'react-hot-toast'
import { authApi } from '../api/auth'
import { useAuthStore } from '../store/authStore'
import { showError } from '../utils/error'

const schema = z.object({
  phone: z.string().min(10, 'Enter a valid phone number').max(15),
  password: z.string().min(8, 'Password must be at least 8 characters'),
})
type FormData = z.infer<typeof schema>

export default function Login() {
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()
  const setTokens = useAuthStore((s) => s.setTokens)

  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    resolver: zodResolver(schema),
  })

  const onSubmit = async (data: FormData) => {
    setLoading(true)
    try {
      const res = await authApi.login(data)
      setTokens(res.data.access_token, res.data.refresh_token)
      toast.success('Welcome back!')
      navigate('/dashboard')
    } catch (err: unknown) {
      showError(err, 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-white px-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-10">
          <h1 className="text-3xl font-bold text-navy-900">Saving<span className="text-primary-700">Plus</span></h1>
          <p className="text-navy-400 mt-2 text-sm">Smart savings for Tanzania</p>
        </div>

        <div className="space-y-6">
          <div>
            <h2 className="text-xl font-bold text-navy-900 mb-1">Log in</h2>
            <p className="text-navy-400 text-sm">Enter your phone and password</p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Phone number</label>
              <input
                {...register('phone')}
                type="tel"
                placeholder="+255 7XX XXX XXX"
                className="input-field"
              />
              {errors.phone && <p className="text-danger text-xs mt-1.5">{errors.phone.message}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Password</label>
              <input
                {...register('password')}
                type="password"
                placeholder="Enter your password"
                className="input-field"
              />
              {errors.password && <p className="text-danger text-xs mt-1.5">{errors.password.message}</p>}
            </div>

            <button type="submit" disabled={loading} className="btn-primary w-full mt-2">
              {loading ? 'Logging in...' : 'Log in'}
            </button>
          </form>

          <p className="text-center text-sm text-navy-400">
            New to SavingPlus?{' '}
            <Link to="/register" className="text-primary-700 font-semibold hover:underline">
              Create account
            </Link>
          </p>
        </div>
      </div>
    </div>
  )
}
