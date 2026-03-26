import { useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import api from '../api/client'
import { showError, showLoadError } from '../utils/error'

interface TierLimit {
  kyc_tier: number; daily_deposit_limit: number; daily_withdrawal_limit: number;
  max_balance: number; description: string
}

export default function TierLimits() {
  const [limits, setLimits] = useState<TierLimit[]>([])
  const [editing, setEditing] = useState<number | null>(null)
  const [form, setForm] = useState({ daily_deposit_limit: 0, daily_withdrawal_limit: 0, max_balance: 0 })
  const [loading, setLoading] = useState(true)

  const load = () => {
    setLoading(true)
    api.get('/tier-limits').then((res) => setLimits(res.data.tier_limits)).catch((err: unknown) => showLoadError(err, 'tier limits')).finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  const startEdit = (t: TierLimit) => {
    setEditing(t.kyc_tier)
    setForm({ daily_deposit_limit: t.daily_deposit_limit, daily_withdrawal_limit: t.daily_withdrawal_limit, max_balance: t.max_balance })
  }

  const save = async (tier: number) => {
    try {
      await api.put(`/tier-limits/${tier}`, form)
      toast.success(`Tier ${tier} limits updated`)
      setEditing(null)
      load()
    } catch (err: unknown) { showError(err, 'Failed to update tier limits') }
  }

  const fmt = (n: number) => new Intl.NumberFormat('en-TZ').format(n)
  const tierNames = ['Unverified', 'Basic', 'Enhanced', 'Premium']

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Tier Limits Configuration</h1>

      {loading ? (
        <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
      ) : (
        <div className="grid gap-4">
          {limits.map((t) => (
            <div key={t.kyc_tier} className="card">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h2 className="text-lg font-semibold">Tier {t.kyc_tier} - {tierNames[t.kyc_tier]}</h2>
                  <p className="text-sm text-gray-500">{t.description}</p>
                </div>
                {editing === t.kyc_tier ? (
                  <div className="flex gap-2">
                    <button onClick={() => save(t.kyc_tier)} className="btn-primary text-sm">Save</button>
                    <button onClick={() => setEditing(null)} className="btn-secondary text-sm">Cancel</button>
                  </div>
                ) : (
                  <button onClick={() => startEdit(t)} className="btn-secondary text-sm">Edit Limits</button>
                )}
              </div>

              {editing === t.kyc_tier ? (
                <div className="grid grid-cols-3 gap-4">
                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Daily Deposit Limit (TZS)</label>
                    <input type="number" value={form.daily_deposit_limit} onChange={(e) => setForm({ ...form, daily_deposit_limit: Number(e.target.value) })} className="input-field" />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Daily Withdrawal Limit (TZS)</label>
                    <input type="number" value={form.daily_withdrawal_limit} onChange={(e) => setForm({ ...form, daily_withdrawal_limit: Number(e.target.value) })} className="input-field" />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Max Balance (TZS)</label>
                    <input type="number" value={form.max_balance} onChange={(e) => setForm({ ...form, max_balance: Number(e.target.value) })} className="input-field" />
                  </div>
                </div>
              ) : (
                <div className="grid grid-cols-3 gap-4 text-sm">
                  <div>
                    <p className="text-gray-500">Daily Deposit</p>
                    <p className="font-semibold">TZS {fmt(t.daily_deposit_limit)}</p>
                  </div>
                  <div>
                    <p className="text-gray-500">Daily Withdrawal</p>
                    <p className="font-semibold">TZS {fmt(t.daily_withdrawal_limit)}</p>
                  </div>
                  <div>
                    <p className="text-gray-500">Max Balance</p>
                    <p className="font-semibold">TZS {fmt(t.max_balance)}</p>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
