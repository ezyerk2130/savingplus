import { useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { UserPlus, Shield } from 'lucide-react'
import api from '../api/client'
import { showError, showLoadError } from '../utils/error'

interface AdminRow {
  id: string; email: string; full_name: string; role: string;
  status: string; mfa_enabled: boolean; last_login_at?: string; created_at: string
}

const createSchema = z.object({
  email: z.string().email(),
  full_name: z.string().min(2),
  password: z.string().min(12, 'Minimum 12 characters'),
  role: z.enum(['support', 'finance', 'super_admin']),
})
type CreateForm = z.infer<typeof createSchema>

export default function AdminUsers() {
  const [admins, setAdmins] = useState<AdminRow[]>([])
  const [loading, setLoading] = useState(true)
  const [showCreate, setShowCreate] = useState(false)
  const [mfaResult, setMfaResult] = useState<{ mfa_secret: string; mfa_url: string } | null>(null)

  const { register, handleSubmit, formState: { errors }, reset } = useForm<CreateForm>({
    resolver: zodResolver(createSchema),
    defaultValues: { role: 'support' },
  })

  const loadAdmins = () => {
    setLoading(true)
    api.get('/admins').then((res) => setAdmins(res.data.admins)).catch((err: unknown) => showLoadError(err, 'admin users')).finally(() => setLoading(false))
  }

  useEffect(() => { loadAdmins() }, [])

  const onCreate = async (data: CreateForm) => {
    try {
      const res = await api.post('/admins', data)
      toast.success('Admin created')
      setMfaResult({ mfa_secret: res.data.mfa_secret, mfa_url: res.data.mfa_url })
      reset()
      loadAdmins()
    } catch (err: unknown) { showError(err, 'Failed to create admin') }
  }

  const deactivate = async (id: string) => {
    try {
      await api.post(`/admins/${id}/deactivate`)
      toast.success('Admin deactivated')
      loadAdmins()
    } catch (err: unknown) { showError(err, 'Failed to deactivate admin') }
  }

  const reactivate = async (id: string) => {
    try {
      await api.post(`/admins/${id}/reactivate`)
      toast.success('Admin reactivated')
      loadAdmins()
    } catch (err: unknown) { showError(err, 'Failed to reactivate admin') }
  }

  const roleColor = (role: string) => {
    switch (role) {
      case 'super_admin': return 'bg-purple-100 text-purple-700'
      case 'finance': return 'bg-blue-100 text-blue-700'
      default: return 'bg-green-100 text-green-700'
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Admin Users</h1>
        <button onClick={() => { setShowCreate(!showCreate); setMfaResult(null) }} className="btn-primary flex items-center gap-2">
          <UserPlus className="w-4 h-4" /> New Admin
        </button>
      </div>

      {/* Create Admin Form */}
      {showCreate && (
        <div className="card mb-6">
          <h2 className="text-lg font-semibold mb-4">Create Admin User</h2>
          <form onSubmit={handleSubmit(onCreate)} className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input {...register('email')} className="input-field" placeholder="admin@savingplus.co.tz" />
              {errors.email && <p className="text-red-500 text-xs mt-1">{errors.email.message}</p>}
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
              <input {...register('full_name')} className="input-field" />
              {errors.full_name && <p className="text-red-500 text-xs mt-1">{errors.full_name.message}</p>}
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Password (min 12 chars)</label>
              <input {...register('password')} type="password" className="input-field" />
              {errors.password && <p className="text-red-500 text-xs mt-1">{errors.password.message}</p>}
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
              <select {...register('role')} className="input-field">
                <option value="support">Support</option>
                <option value="finance">Finance</option>
                <option value="super_admin">Super Admin</option>
              </select>
            </div>
            <div className="col-span-2">
              <button type="submit" className="btn-primary">Create Admin</button>
            </div>
          </form>

          {mfaResult && (
            <div className="mt-4 p-4 bg-amber-50 border border-amber-200 rounded-lg">
              <p className="font-semibold text-amber-800 flex items-center gap-2">
                <Shield className="w-4 h-4" /> MFA Setup Required
              </p>
              <p className="text-sm text-amber-700 mt-2">Share this secret with the admin to set up Google Authenticator:</p>
              <code className="block bg-white p-2 rounded mt-1 text-sm font-mono break-all">{mfaResult.mfa_secret}</code>
              <p className="text-xs text-amber-600 mt-2">This secret will not be shown again.</p>
            </div>
          )}
        </div>
      )}

      {/* Admin List */}
      <div className="card p-0 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Name</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Email</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Role</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">MFA</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Last Login</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {admins.map((a) => (
                <tr key={a.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium">{a.full_name}</td>
                  <td className="px-4 py-3">{a.email}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${roleColor(a.role)}`}>
                      {a.role.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                      a.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
                    }`}>{a.status}</span>
                  </td>
                  <td className="px-4 py-3">{a.mfa_enabled ? 'Yes' : 'No'}</td>
                  <td className="px-4 py-3">{a.last_login_at ? new Date(a.last_login_at).toLocaleString() : 'Never'}</td>
                  <td className="px-4 py-3">
                    {a.status === 'active' ? (
                      <button onClick={() => deactivate(a.id)} className="text-red-600 text-xs font-medium hover:underline">Deactivate</button>
                    ) : (
                      <button onClick={() => reactivate(a.id)} className="text-emerald-600 text-xs font-medium hover:underline">Reactivate</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
