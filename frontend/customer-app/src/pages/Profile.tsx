import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { KeyRound, Lock } from 'lucide-react'
import { userApi } from '../api/services'
import { authApi } from '../api/auth'
import { showError, showLoadError } from '../utils/error'
import { useAuthStore } from '../store/authStore'
import type { User } from '../types'

export default function Profile() {
  const [profile, setProfile] = useState<User | null>(null)
  const [loading, setLoading] = useState(false)
  const setUser = useAuthStore((s) => s.setUser)

  // Profile form
  const { register: regProfile, handleSubmit: submitProfile, reset: resetProfile } = useForm<{ full_name: string; email: string }>()

  // Password form
  const [pwLoading, setPwLoading] = useState(false)
  const { register: regPw, handleSubmit: submitPw, reset: resetPw, formState: { errors: pwErrors } } = useForm<{
    current_password: string; new_password: string; confirm_password: string
  }>()

  // PIN form
  const [pinLoading, setPinLoading] = useState(false)
  const { register: regPin, handleSubmit: submitPin, reset: resetPin, formState: { errors: pinErrors } } = useForm<{
    current_pin: string; new_pin: string
  }>()

  useEffect(() => {
    userApi.getProfile().then((res) => {
      setProfile(res.data)
      resetProfile({ full_name: res.data.full_name, email: res.data.email || '' })
    }).catch((err: unknown) => showLoadError(err, 'profile'))
  }, [resetProfile])

  const onSaveProfile = async (data: { full_name: string; email: string }) => {
    setLoading(true)
    try {
      await userApi.updateProfile(data)
      toast.success('Profile updated')
      const res = await userApi.getProfile()
      setProfile(res.data)
      setUser(res.data)
    } catch (err: unknown) {
      showError(err, 'Update failed')
    } finally {
      setLoading(false)
    }
  }

  const onChangePassword = async (data: { current_password: string; new_password: string; confirm_password: string }) => {
    if (data.new_password !== data.confirm_password) {
      toast.error('New passwords do not match')
      return
    }
    if (data.new_password.length < 8) {
      toast.error('Password must be at least 8 characters')
      return
    }
    setPwLoading(true)
    try {
      await authApi.changePassword({ current_password: data.current_password, new_password: data.new_password })
      toast.success('Password changed successfully')
      resetPw()
    } catch (err: unknown) {
      showError(err, 'Failed to change password')
    } finally {
      setPwLoading(false)
    }
  }

  const onChangePIN = async (data: { current_pin: string; new_pin: string }) => {
    if (data.new_pin.length !== 4 || !/^\d{4}$/.test(data.new_pin)) {
      toast.error('PIN must be exactly 4 digits')
      return
    }
    setPinLoading(true)
    try {
      await authApi.changePIN({ current_pin: data.current_pin, new_pin: data.new_pin })
      toast.success('Transaction PIN changed')
      resetPin()
    } catch (err: unknown) {
      showError(err, 'Failed to change PIN')
    } finally {
      setPinLoading(false)
    }
  }

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <h1 className="text-2xl font-bold">Profile Settings</h1>

      {/* Profile info */}
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

        <form onSubmit={submitProfile(onSaveProfile)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
            <input {...regProfile('full_name')} className="input-field" />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input {...regProfile('email')} type="email" className="input-field" placeholder="you@example.com" />
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

      {/* Change Password */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
          <Lock className="w-5 h-5 text-gray-500" /> Change Password
        </h2>
        <form onSubmit={submitPw(onChangePassword)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Current Password</label>
            <input {...regPw('current_password', { required: 'Required' })} type="password" className="input-field" />
            {pwErrors.current_password && <p className="text-red-500 text-xs mt-1">{pwErrors.current_password.message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">New Password</label>
            <input {...regPw('new_password', { required: 'Required', minLength: { value: 8, message: 'Min 8 characters' } })} type="password" className="input-field" placeholder="Min 8 characters" />
            {pwErrors.new_password && <p className="text-red-500 text-xs mt-1">{pwErrors.new_password.message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Confirm New Password</label>
            <input {...regPw('confirm_password', { required: 'Required' })} type="password" className="input-field" />
            {pwErrors.confirm_password && <p className="text-red-500 text-xs mt-1">{pwErrors.confirm_password.message}</p>}
          </div>
          <button type="submit" disabled={pwLoading} className="btn-primary w-full">
            {pwLoading ? 'Changing...' : 'Change Password'}
          </button>
        </form>
      </div>

      {/* Change Transaction PIN */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
          <KeyRound className="w-5 h-5 text-gray-500" /> Change Transaction PIN
        </h2>
        <form onSubmit={submitPin(onChangePIN)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Current PIN</label>
            <input {...regPin('current_pin', { required: 'Required', pattern: { value: /^\d{4}$/, message: '4 digits required' } })} type="password" maxLength={4} className="input-field" placeholder="****" />
            {pinErrors.current_pin && <p className="text-red-500 text-xs mt-1">{pinErrors.current_pin.message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">New PIN</label>
            <input {...regPin('new_pin', { required: 'Required', pattern: { value: /^\d{4}$/, message: '4 digits required' } })} type="password" maxLength={4} className="input-field" placeholder="****" />
            {pinErrors.new_pin && <p className="text-red-500 text-xs mt-1">{pinErrors.new_pin.message}</p>}
          </div>
          <button type="submit" disabled={pinLoading} className="btn-primary w-full">
            {pinLoading ? 'Changing...' : 'Change PIN'}
          </button>
        </form>
      </div>
    </div>
  )
}
