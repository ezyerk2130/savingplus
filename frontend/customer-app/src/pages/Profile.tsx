import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { KeyRound, Lock, ShieldCheck, User, Copy, CheckCircle } from 'lucide-react'
import { userApi } from '../api/services'
import { authApi } from '../api/auth'
import { showError, showLoadError } from '../utils/error'
import { useAuthStore } from '../store/authStore'
import type { User as UserType } from '../types'

export default function Profile() {
  const [profile, setProfile] = useState<UserType | null>(null)
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

  // 2FA state
  const [twoFAEnabled, setTwoFAEnabled] = useState(false)
  const [twoFALoading, setTwoFALoading] = useState(false)
  const [twoFASecret, setTwoFASecret] = useState<string | null>(null)
  const [twoFAVerifyCode, setTwoFAVerifyCode] = useState('')
  const [twoFAVerifying, setTwoFAVerifying] = useState(false)
  const [secretCopied, setSecretCopied] = useState(false)

  useEffect(() => {
    userApi.getProfile().then((res) => {
      setProfile(res.data)
      resetProfile({ full_name: res.data.full_name, email: res.data.email || '' })
    }).catch((err: unknown) => showLoadError(err, 'profile'))

    // Load 2FA status
    authApi.get2FAStatus().then((res) => {
      setTwoFAEnabled(res.data.enabled)
    }).catch(() => { /* silently fail - feature may not be available */ })
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

  const handleEnable2FA = async () => {
    setTwoFALoading(true)
    try {
      const res = await authApi.enable2FA()
      setTwoFASecret(res.data.secret)
      setTwoFAVerifyCode('')
    } catch (err: unknown) {
      showError(err, 'Failed to enable 2FA')
    } finally {
      setTwoFALoading(false)
    }
  }

  const handleVerify2FA = async () => {
    if (!twoFAVerifyCode || twoFAVerifyCode.length !== 6) {
      toast.error('Enter a 6-digit code')
      return
    }
    setTwoFAVerifying(true)
    try {
      await authApi.verify2FA(twoFAVerifyCode)
      toast.success('Two-factor authentication enabled')
      setTwoFAEnabled(true)
      setTwoFASecret(null)
      setTwoFAVerifyCode('')
    } catch (err: unknown) {
      showError(err, 'Invalid verification code')
    } finally {
      setTwoFAVerifying(false)
    }
  }

  const handleDisable2FA = async () => {
    setTwoFALoading(true)
    try {
      await authApi.disable2FA()
      toast.success('Two-factor authentication disabled')
      setTwoFAEnabled(false)
      setTwoFASecret(null)
    } catch (err: unknown) {
      showError(err, 'Failed to disable 2FA')
    } finally {
      setTwoFALoading(false)
    }
  }

  const copySecret = () => {
    if (twoFASecret) {
      navigator.clipboard.writeText(twoFASecret)
      setSecretCopied(true)
      setTimeout(() => setSecretCopied(false), 2000)
    }
  }

  return (
    <div className="max-w-lg mx-auto space-y-6">
      {/* Page header */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 bg-primary-50 rounded-xl flex items-center justify-center">
          <User className="w-5 h-5 text-primary-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-navy-900">Profile Settings</h1>
          <p className="text-navy-400 text-sm">Manage your account and security</p>
        </div>
      </div>

      {/* Profile info */}
      <div className="card">
        <div className="flex items-center gap-4 mb-6 pb-6 border-b border-gray-100">
          <div className="w-16 h-16 rounded-2xl bg-primary-50 flex items-center justify-center">
            <span className="text-2xl font-bold text-primary-600">
              {profile?.full_name?.charAt(0) || '?'}
            </span>
          </div>
          <div>
            <h2 className="text-lg font-semibold text-navy-900">{profile?.full_name}</h2>
            <p className="text-sm text-navy-400">{profile?.phone}</p>
            <div className="flex gap-2 mt-1.5">
              <span className={
                profile?.kyc_status === 'approved' ? 'badge-success' : 'badge-warning'
              }>
                KYC: {profile?.kyc_status}
              </span>
              <span className="badge-neutral">Tier {profile?.kyc_tier}</span>
            </div>
          </div>
        </div>

        <form onSubmit={submitProfile(onSaveProfile)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1.5">Full Name</label>
            <input {...regProfile('full_name')} className="input-field" />
          </div>

          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1.5">Email</label>
            <input {...regProfile('email')} type="email" className="input-field" placeholder="you@example.com" />
          </div>

          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1.5">Phone</label>
            <input value={profile?.phone || ''} disabled className="input-field bg-navy-50 text-navy-400" />
            <p className="text-2xs text-navy-300 mt-1">Phone number cannot be changed</p>
          </div>

          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1.5">Member Since</label>
            <input
              value={profile?.created_at ? new Date(profile.created_at).toLocaleDateString() : ''}
              disabled
              className="input-field bg-navy-50 text-navy-400"
            />
          </div>

          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? 'Saving...' : 'Save Changes'}
          </button>
        </form>
      </div>

      {/* Two-Factor Authentication */}
      <div className="card">
        <h2 className="text-base font-semibold text-navy-900 mb-1 flex items-center gap-2">
          <ShieldCheck className="w-5 h-5 text-primary-500" /> Two-Factor Authentication
        </h2>
        <p className="text-2xs text-navy-400 mb-5">Add an extra layer of security to your account</p>

        {twoFASecret ? (
          /* Setup flow: show secret and verify */
          <div className="space-y-4">
            <div className="bg-primary-50 rounded-2xl p-4">
              <p className="text-sm font-medium text-primary-900 mb-2">Setup Instructions</p>
              <ol className="text-2xs text-primary-700 space-y-1 list-decimal list-inside">
                <li>Open your authenticator app (Google Authenticator, Authy, etc.)</li>
                <li>Add a new account and enter the secret key below</li>
                <li>Enter the 6-digit code from your authenticator app</li>
              </ol>
            </div>

            <div>
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Secret Key</label>
              <div className="flex gap-2">
                <input
                  value={twoFASecret}
                  readOnly
                  className="input-field bg-navy-50 font-mono text-sm"
                />
                <button
                  onClick={copySecret}
                  className="btn-secondary px-3 flex-shrink-0"
                  title="Copy secret"
                >
                  {secretCopied ? <CheckCircle className="w-4 h-4 text-green-600" /> : <Copy className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Verification Code</label>
              <input
                type="text"
                value={twoFAVerifyCode}
                onChange={(e) => setTwoFAVerifyCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                className="input-field text-center text-lg tracking-widest font-mono"
                placeholder="000000"
                maxLength={6}
                autoFocus
              />
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => { setTwoFASecret(null); setTwoFAVerifyCode('') }}
                className="flex-1 btn-secondary"
              >
                Cancel
              </button>
              <button
                onClick={handleVerify2FA}
                disabled={twoFAVerifying || twoFAVerifyCode.length !== 6}
                className="flex-1 btn-primary"
              >
                {twoFAVerifying ? 'Verifying...' : 'Verify & Enable'}
              </button>
            </div>
          </div>
        ) : (
          /* Status display and toggle */
          <div className="flex items-center justify-between bg-navy-50 rounded-2xl p-4">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                twoFAEnabled ? 'bg-green-50' : 'bg-navy-100'
              }`}>
                <ShieldCheck className={`w-5 h-5 ${twoFAEnabled ? 'text-green-600' : 'text-navy-400'}`} />
              </div>
              <div>
                <p className="text-sm font-semibold text-navy-900">
                  {twoFAEnabled ? 'Enabled' : 'Disabled'}
                </p>
                <p className="text-2xs text-navy-400">
                  {twoFAEnabled ? 'Your account is protected with 2FA' : 'Enable for extra security'}
                </p>
              </div>
            </div>
            <button
              onClick={twoFAEnabled ? handleDisable2FA : handleEnable2FA}
              disabled={twoFALoading}
              className={twoFAEnabled ? 'btn-danger text-sm py-2 px-4' : 'btn-primary text-sm py-2 px-4'}
            >
              {twoFALoading ? '...' : twoFAEnabled ? 'Disable' : 'Enable'}
            </button>
          </div>
        )}
      </div>

      {/* Change Password */}
      <div className="card">
        <h2 className="text-base font-semibold text-navy-900 mb-4 flex items-center gap-2">
          <Lock className="w-5 h-5 text-navy-400" /> Change Password
        </h2>
        <form onSubmit={submitPw(onChangePassword)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1.5">Current Password</label>
            <input {...regPw('current_password', { required: 'Required' })} type="password" className="input-field" />
            {pwErrors.current_password && <p className="text-red-500 text-2xs mt-1">{pwErrors.current_password.message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1.5">New Password</label>
            <input {...regPw('new_password', { required: 'Required', minLength: { value: 8, message: 'Min 8 characters' } })} type="password" className="input-field" placeholder="Min 8 characters" />
            {pwErrors.new_password && <p className="text-red-500 text-2xs mt-1">{pwErrors.new_password.message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1.5">Confirm New Password</label>
            <input {...regPw('confirm_password', { required: 'Required' })} type="password" className="input-field" />
            {pwErrors.confirm_password && <p className="text-red-500 text-2xs mt-1">{pwErrors.confirm_password.message}</p>}
          </div>
          <button type="submit" disabled={pwLoading} className="btn-primary w-full">
            {pwLoading ? 'Changing...' : 'Change Password'}
          </button>
        </form>
      </div>

      {/* Change Transaction PIN */}
      <div className="card">
        <h2 className="text-base font-semibold text-navy-900 mb-4 flex items-center gap-2">
          <KeyRound className="w-5 h-5 text-navy-400" /> Change Transaction PIN
        </h2>
        <form onSubmit={submitPin(onChangePIN)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1.5">Current PIN</label>
            <input {...regPin('current_pin', { required: 'Required', pattern: { value: /^\d{4}$/, message: '4 digits required' } })} type="password" maxLength={4} className="input-field" placeholder="****" />
            {pinErrors.current_pin && <p className="text-red-500 text-2xs mt-1">{pinErrors.current_pin.message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-navy-700 mb-1.5">New PIN</label>
            <input {...regPin('new_pin', { required: 'Required', pattern: { value: /^\d{4}$/, message: '4 digits required' } })} type="password" maxLength={4} className="input-field" placeholder="****" />
            {pinErrors.new_pin && <p className="text-red-500 text-2xs mt-1">{pinErrors.new_pin.message}</p>}
          </div>
          <button type="submit" disabled={pinLoading} className="btn-primary w-full">
            {pinLoading ? 'Changing...' : 'Change PIN'}
          </button>
        </form>
      </div>
    </div>
  )
}
