import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { userApi } from '../api/services'
import { useAuthStore } from '../store/authStore'
import type { User } from '../types'

export default function Profile() {
  const [profile, setProfile] = useState<User | null>(null)
  const [loading, setLoading] = useState(false)
  const setUser = useAuthStore((s) => s.setUser)

  const { register, handleSubmit, reset } = useForm<{ full_name: string; email: string }>()

  useEffect(() => {
    userApi.getProfile().then((res) => {
      setProfile(res.data)
      reset({ full_name: res.data.full_name, email: res.data.email || '' })
    })
  }, [reset])

  const onSubmit = async (data: { full_name: string; email: string }) => {
    setLoading(true)
    try {
      await userApi.updateProfile(data)
      toast.success('Profile updated')
      const res = await userApi.getProfile()
      setProfile(res.data)
      setUser(res.data)
    } catch (err: any) {
      toast.error(err.response?.data?.error || 'Update failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <h1 className="text-2xl font-bold">Profile Settings</h1>

      <div className="card">
        <div className="flex items-center gap-4 mb-6 pb-6 border-b border-gray-100">
          <div className="w-16 h-16 rounded-full bg-primary-100 flex items-center justify-center">
            <span className="text-2xl font-bold text-primary-600">
              {profile?.full_name?.charAt(0) || '?'}
            </span>
          </div>
          <div>
            <h2 className="text-lg font-semibold">{profile?.full_name}</h2>
            <p className="text-sm text-gray-500">{profile?.phone}</p>
            <div className="flex gap-2 mt-1">
              <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                profile?.kyc_status === 'approved' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700'
              }`}>
                KYC: {profile?.kyc_status}
              </span>
              <span className="text-xs px-2 py-0.5 rounded-full bg-gray-100 text-gray-700 font-medium">
                Tier {profile?.kyc_tier}
              </span>
            </div>
          </div>
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
            <input {...register('full_name')} className="input-field" />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input {...register('email')} type="email" className="input-field" placeholder="you@example.com" />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
            <input value={profile?.phone || ''} disabled className="input-field bg-gray-50 text-gray-500" />
            <p className="text-xs text-gray-400 mt-1">Phone number cannot be changed</p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Member Since</label>
            <input
              value={profile?.created_at ? new Date(profile.created_at).toLocaleDateString() : ''}
              disabled
              className="input-field bg-gray-50 text-gray-500"
            />
          </div>

          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? 'Saving...' : 'Save Changes'}
          </button>
        </form>
      </div>
    </div>
  )
}
