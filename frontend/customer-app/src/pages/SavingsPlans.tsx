import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { PiggyBank, Plus, Target, Lock, Wallet, ArrowDownCircle, ArrowUpCircle, XCircle } from 'lucide-react'
import toast from 'react-hot-toast'
import { savingsApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { SavingsPlan } from '../types'

const typeIcon = (type: string) => {
  switch (type) {
    case 'flexible': return <Wallet className="w-5 h-5 text-blue-600" />
    case 'locked': return <Lock className="w-5 h-5 text-purple-600" />
    case 'target': return <Target className="w-5 h-5 text-green-600" />
    default: return <PiggyBank className="w-5 h-5" />
  }
}

const typeColor = (type: string) => {
  switch (type) {
    case 'flexible': return 'bg-blue-50 border-blue-200'
    case 'locked': return 'bg-purple-50 border-purple-200'
    case 'target': return 'bg-green-50 border-green-200'
    default: return 'bg-gray-50'
  }
}

export default function SavingsPlans() {
  const [plans, setPlans] = useState<SavingsPlan[]>([])
  const [loading, setLoading] = useState(true)

  const [error, setError] = useState(false)

  // Modal state
  const [activeModal, setActiveModal] = useState<{ type: 'deposit' | 'withdraw' | 'cancel'; plan: SavingsPlan } | null>(null)
  const [amount, setAmount] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const loadPlans = () => {
    setLoading(true)
    setError(false)
    savingsApi.listPlans().then((res) => {
      setPlans(res.data.plans)
    }).catch((err: unknown) => {
      showLoadError(err, 'savings plans')
      setError(true)
    }).finally(() => setLoading(false))
  }

  useEffect(() => { loadPlans() }, [])

  const formatAmount = (amt: string) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(parseFloat(amt))

  const handleDeposit = async () => {
    if (!activeModal || !amount || parseFloat(amount) <= 0) {
      toast.error('Enter a valid amount')
      return
    }
    setSubmitting(true)
    try {
      const res = await savingsApi.depositToPlan(activeModal.plan.id, parseFloat(amount))
      toast.success(`Deposited TZS ${formatAmount(amount)} to ${activeModal.plan.name}`)
      setActiveModal(null)
      setAmount('')
      loadPlans()
    } catch (err: unknown) {
      showError(err, 'Deposit failed')
    } finally {
      setSubmitting(false)
    }
  }

  const handleWithdraw = async () => {
    if (!activeModal || !amount || parseFloat(amount) <= 0) {
      toast.error('Enter a valid amount')
      return
    }
    setSubmitting(true)
    try {
      await savingsApi.withdrawFromPlan(activeModal.plan.id, parseFloat(amount))
      toast.success(`Withdrew TZS ${formatAmount(amount)} from ${activeModal.plan.name}`)
      setActiveModal(null)
      setAmount('')
      loadPlans()
    } catch (err: unknown) {
      showError(err, 'Withdrawal failed')
    } finally {
      setSubmitting(false)
    }
  }

  const handleCancel = async () => {
    if (!activeModal) return
    setSubmitting(true)
    try {
      const res = await savingsApi.cancelPlan(activeModal.plan.id)
      toast.success(res.data.message || 'Plan cancelled')
      setActiveModal(null)
      loadPlans()
    } catch (err: unknown) {
      showError(err, 'Cancellation failed')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Savings Plans</h1>
        <Link to="/savings/new" className="btn-primary flex items-center gap-2">
          <Plus className="w-4 h-4" /> New Plan
        </Link>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
        </div>
      ) : error ? (
        <div className="card text-center py-12">
          <p className="text-gray-600 mb-4">Failed to load savings plans</p>
          <button onClick={loadPlans} className="btn-primary">Retry</button>
        </div>
      ) : plans.length === 0 ? (
        <div className="card text-center py-12">
          <PiggyBank className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-500 mb-4">No savings plans yet</p>
          <Link to="/savings/new" className="btn-primary">Create Your First Plan</Link>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {plans.map((plan) => (
            <div key={plan.id} className={`card border ${typeColor(plan.type)}`}>
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-2">
                  {typeIcon(plan.type)}
                  <div>
                    <h3 className="font-semibold text-gray-900">{plan.name}</h3>
                    <p className="text-xs text-gray-500 capitalize">{plan.type} savings</p>
                  </div>
                </div>
                <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                  plan.status === 'active' ? 'bg-green-100 text-green-700' :
                  plan.status === 'matured' ? 'bg-blue-100 text-blue-700' :
                  plan.status === 'cancelled' ? 'bg-red-100 text-red-700' :
                  'bg-gray-100 text-gray-600'
                }`}>
                  {plan.status}
                </span>
              </div>

              <div className="space-y-2">
                <div>
                  <p className="text-xs text-gray-500">Saved</p>
                  <p className="text-lg font-bold">TZS {formatAmount(plan.current_amount)}</p>
                </div>

                {plan.target_amount && (
                  <div>
                    <div className="flex justify-between text-xs text-gray-500 mb-1">
                      <span>Target: TZS {formatAmount(plan.target_amount)}</span>
                      <span>{Math.round((parseFloat(plan.current_amount) / parseFloat(plan.target_amount)) * 100)}%</span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-2">
                      <div
                        className="bg-green-500 rounded-full h-2 transition-all"
                        style={{ width: `${Math.min(100, (parseFloat(plan.current_amount) / parseFloat(plan.target_amount)) * 100)}%` }}
                      />
                    </div>
                  </div>
                )}

                <div className="flex justify-between text-xs text-gray-500 pt-2">
                  <span>Rate: {plan.interest_rate}</span>
                  {plan.maturity_date && (
                    <span>Matures: {new Date(plan.maturity_date).toLocaleDateString()}</span>
                  )}
                </div>

                {/* Action buttons */}
                {(plan.status === 'active' || plan.status === 'matured') && (
                  <div className="flex gap-2 pt-3 border-t border-gray-200 mt-3">
                    {plan.status === 'active' && (
                      <button
                        onClick={() => { setActiveModal({ type: 'deposit', plan }); setAmount('') }}
                        className="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-emerald-100 text-emerald-700 hover:bg-emerald-200 transition-colors"
                      >
                        <ArrowDownCircle className="w-3.5 h-3.5" /> Deposit
                      </button>
                    )}
                    <button
                      onClick={() => { setActiveModal({ type: 'withdraw', plan }); setAmount('') }}
                      className="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-blue-100 text-blue-700 hover:bg-blue-200 transition-colors"
                    >
                      <ArrowUpCircle className="w-3.5 h-3.5" /> Withdraw
                    </button>
                    {plan.status === 'active' && (
                      <button
                        onClick={() => setActiveModal({ type: 'cancel', plan })}
                        className="flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-red-100 text-red-700 hover:bg-red-200 transition-colors"
                      >
                        <XCircle className="w-3.5 h-3.5" /> Cancel
                      </button>
                    )}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal overlay */}
      {activeModal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4" onClick={() => setActiveModal(null)}>
          <div className="bg-white rounded-xl shadow-xl w-full max-w-sm p-6" onClick={(e) => e.stopPropagation()}>
            {activeModal.type === 'cancel' ? (
              <>
                <h2 className="text-lg font-bold text-gray-900 mb-2">Cancel Plan</h2>
                <p className="text-sm text-gray-600 mb-1">
                  Are you sure you want to cancel <strong>{activeModal.plan.name}</strong>?
                </p>
                {parseFloat(activeModal.plan.current_amount) > 0 && (
                  <p className="text-sm text-gray-600 mb-4">
                    TZS {formatAmount(activeModal.plan.current_amount)} will be returned to your wallet.
                  </p>
                )}
                {activeModal.plan.type === 'locked' && (
                  <p className="text-xs text-amber-600 bg-amber-50 p-2 rounded mb-4">
                    Locked plans can only be cancelled after the maturity date.
                  </p>
                )}
                <div className="flex gap-3">
                  <button onClick={() => setActiveModal(null)} className="flex-1 btn-secondary">
                    Keep Plan
                  </button>
                  <button onClick={handleCancel} disabled={submitting} className="flex-1 bg-red-600 text-white py-2.5 px-4 rounded-lg font-medium hover:bg-red-700 disabled:opacity-50">
                    {submitting ? 'Cancelling...' : 'Yes, Cancel'}
                  </button>
                </div>
              </>
            ) : (
              <>
                <h2 className="text-lg font-bold text-gray-900 mb-1">
                  {activeModal.type === 'deposit' ? 'Deposit to' : 'Withdraw from'} Plan
                </h2>
                <p className="text-sm text-gray-500 mb-4">{activeModal.plan.name}</p>

                <div className="mb-2">
                  <p className="text-xs text-gray-500">Plan Balance</p>
                  <p className="font-semibold">TZS {formatAmount(activeModal.plan.current_amount)}</p>
                </div>

                {activeModal.type === 'withdraw' && activeModal.plan.type === 'locked' && activeModal.plan.status === 'active' && (
                  <p className="text-xs text-amber-600 bg-amber-50 p-2 rounded mb-3">
                    Locked plans can only be withdrawn after the maturity date.
                  </p>
                )}

                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Amount (TZS)</label>
                  <input
                    type="number"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    className="input-field"
                    placeholder="Enter amount"
                    min={1}
                    autoFocus
                  />
                </div>

                <div className="flex gap-3">
                  <button onClick={() => setActiveModal(null)} className="flex-1 btn-secondary">
                    Cancel
                  </button>
                  <button
                    onClick={activeModal.type === 'deposit' ? handleDeposit : handleWithdraw}
                    disabled={submitting || !amount || parseFloat(amount) <= 0}
                    className="flex-1 btn-primary disabled:opacity-50"
                  >
                    {submitting ? 'Processing...' : activeModal.type === 'deposit' ? 'Deposit' : 'Withdraw'}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
