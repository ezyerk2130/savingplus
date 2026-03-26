import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import toast from 'react-hot-toast'
import { Shield } from 'lucide-react'
import api from '../api/client'
import { showError } from '../utils/error'
import { useAdminAuth } from '../store/authStore'

const schema = z.object({
  email: z.string().email('Valid email required'),
  password: z.string().min(1, 'Password required'),
  mfa_code: z.string().length(6, 'MFA code must be 6 digits'),
})
type FormData = z.infer<typeof schema>

export default function Login() {
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()
  const setAuth = useAdminAuth((s) => s.setAuth)

  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    resolver: zodResolver(schema),
  })

  const onSubmit = async (data: FormData) => {
    setLoading(true)
    try {
      const res = await api.post('/login', data)
      setAuth(res.data.access_token, res.data.role)
      toast.success('Welcome, admin!')
      navigate('/dashboard')
    } catch (err: unknown) {
      showError(err, 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-900 px-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <Shield className="w-12 h-12 text-emerald-400 mx-auto mb-3" />
          <h1 className="text-2xl font-bold text-white">SavingPlus Admin</h1>
          <p className="text-gray-400 text-sm mt-1">Secure admin access with MFA</p>
        </div>

        <div className="bg-gray-800 rounded-xl p-6 border border-gray-700">
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">Email</label>
              <input {...register('email')} type="email" className="input-field bg-gray-700 border-gray-600 text-white" placeholder="admin@savingplus.co.tz" />
              {errors.email && <p className="text-red-400 text-xs mt-1">{errors.email.message}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">Password</label>
              <input {...register('password')} type="password" className="input-field bg-gray-700 border-gray-600 text-white" />
              {errors.password && <p className="text-red-400 text-xs mt-1">{errors.password.message}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">MFA Code (Google Authenticator)</label>
              <input {...register('mfa_code')} className="input-field bg-gray-700 border-gray-600 text-white text-center tracking-widest text-lg" maxLength={6} placeholder="000000" />
              {errors.mfa_code && <p className="text-red-400 text-xs mt-1">{errors.mfa_code.message}</p>}
            </div>

            <button type="submit" disabled={loading} className="btn-primary w-full">
              {loading ? 'Authenticating...' : 'Sign In'}
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
