import { useEffect, useState } from 'react'
import { Banknote, CheckCircle, AlertCircle, DollarSign, RefreshCw, Calendar, Percent } from 'lucide-react'
import toast from 'react-hot-toast'
import { loanApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { Loan } from '../types'

const statusClass: Record<string, string> = {
  disbursed: 'badge-warning',
  repaying: 'badge-warning',
  paid: 'badge-success',
  pending: 'badge-info',
  rejected: 'badge-danger',
  defaulted: 'badge-danger',
}

export default function Loans() {
  const [loans, setLoans] = useState<Loan[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [refreshing, setRefreshing] = useState(false)

  // Eligibility
  const [eligibility, setEligibility] = useState<{
    eligible: boolean; max_amount: string; interest_rate: number; savings_balance: string
  } | null>(null)
  const [eligLoading, setEligLoading] = useState(true)

  // Apply form
  const [applyAmount, setApplyAmount] = useState('')
  const [applyTerm, setApplyTerm] = useState('30')
  const [applySubmitting, setApplySubmitting] = useState(false)

  // Repay modal
  const [repayModal, setRepayModal] = useState<Loan | null>(null)
  const [repayAmount, setRepayAmount] = useState('')
  const [repaySubmitting, setRepaySubmitting] = useState(false)

  const fmt = (amt: string | number) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(typeof amt === 'string' ? parseFloat(amt) : amt)

  const loadData = (isRefresh = false) => {
    if (isRefresh) setRefreshing(true)
    else setLoading(true)
    setError(false)
    setEligLoading(true)
    Promise.all([
      loanApi.list(),
      loanApi.checkEligibility(),
    ]).then(([loansRes, eligRes]) => {
      setLoans(loansRes.data.loans || [])
      setEligibility(eligRes.data)
    }).catch((err: unknown) => {
      showLoadError(err, 'loans')
      setError(true)
    }).finally(() => {
      setLoading(false)
      setRefreshing(false)
      setEligLoading(false)
    })
  }

  useEffect(() => { loadData() }, [])

  const previewTotalDue = () => {
    if (!applyAmount || !eligibility) return null
    const principal = parseFloat(applyAmount)
    const term = parseInt(applyTerm)
    if (isNaN(principal) || isNaN(term) || principal <= 0) return null
    const rate = typeof eligibility.interest_rate === 'string' ? parseFloat(eligibility.interest_rate) : eligibility.interest_rate
    const interest = principal * (rate / 100) * (term / 365)
    return principal + interest
  }

  const handleApply = async () => {
    if (!applyAmount || parseFloat(applyAmount) <= 0) {
      toast.error('Enter a valid amount')
      return
    }
    if (eligibility && parseFloat(applyAmount) > parseFloat(eligibility.max_amount)) {
      toast.error(`Maximum loan amount is TZS ${fmt(eligibility.max_amount)}`)
      return
    }
    setApplySubmitting(true)
    try {
      await loanApi.apply({ amount: parseFloat(applyAmount), term_days: parseInt(applyTerm) })
      toast.success('Loan application submitted')
      setApplyAmount('')
      setApplyTerm('30')
      loadData()
    } catch (err: unknown) {
      showError(err, 'Loan application failed')
    } finally {
      setApplySubmitting(false)
    }
  }

  const handleRepay = async () => {
    if (!repayModal || !repayAmount || parseFloat(repayAmount) <= 0) {
      toast.error('Enter a valid amount')
      return
    }
    setRepaySubmitting(true)
    try {
      await loanApi.repay(repayModal.id, parseFloat(repayAmount))
      toast.success(`Repaid TZS ${fmt(repayAmount)}`)
      setRepayModal(null)
      setRepayAmount('')
      loadData()
    } catch (err: unknown) {
      showError(err, 'Repayment failed')
    } finally {
      setRepaySubmitting(false)
    }
  }

  const totalDue = previewTotalDue()

  return (
    <div className="space-y-6">
      {/* Page header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-green-50 rounded-xl flex items-center justify-center">
            <Banknote className="w-5 h-5 text-green-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-navy-900">Loans</h1>
            <p className="text-navy-400 text-sm">Quick access to affordable credit</p>
          </div>
        </div>
        <button
          onClick={() => loadData(true)}
          disabled={refreshing}
          className="p-2.5 text-navy-400 hover:text-navy-600 hover:bg-navy-50 rounded-xl transition-all"
        >
          <RefreshCw className={`w-5 h-5 ${refreshing ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-primary-500 border-t-transparent" />
        </div>
      ) : error ? (
        <div className="card text-center py-16">
          <p className="text-navy-500 mb-4">Failed to load loans</p>
          <button onClick={() => loadData()} className="btn-primary">Retry</button>
        </div>
      ) : (
        <>
          {/* Eligibility Card - gradient hero */}
          <div className="card bg-gradient-to-br from-navy-900 to-navy-800 border-navy-700 text-white relative overflow-hidden">
            <div className="absolute top-0 right-0 w-48 h-48 bg-primary-400/10 rounded-full -translate-y-16 translate-x-16" />
            <div className="absolute bottom-0 left-0 w-32 h-32 bg-green-400/10 rounded-full translate-y-12 -translate-x-8" />
            <div className="relative">
              <p className="text-navy-300 text-sm font-medium mb-4">Loan Eligibility</p>

              {eligLoading ? (
                <div className="flex items-center justify-center h-16">
                  <div className="animate-spin rounded-full h-6 w-6 border-2 border-white/30 border-t-white" />
                </div>
              ) : eligibility ? (
                <>
                  <div className="flex items-center gap-2 mb-5">
                    {eligibility.eligible ? (
                      <>
                        <CheckCircle className="w-5 h-5 text-green-400" />
                        <span className="text-sm font-semibold text-green-300">You are eligible for a loan</span>
                      </>
                    ) : (
                      <>
                        <AlertCircle className="w-5 h-5 text-red-400" />
                        <span className="text-sm font-semibold text-red-300">Not eligible at this time</span>
                      </>
                    )}
                  </div>

                  <div className="grid grid-cols-3 gap-3">
                    <div className="bg-white/10 backdrop-blur-sm rounded-2xl p-3.5 text-center">
                      <DollarSign className="w-4 h-4 text-navy-300 mx-auto mb-1" />
                      <p className="text-2xs text-navy-300">Max Loan</p>
                      <p className="text-sm font-bold text-white mt-0.5">TZS {fmt(eligibility.max_amount)}</p>
                    </div>
                    <div className="bg-white/10 backdrop-blur-sm rounded-2xl p-3.5 text-center">
                      <Percent className="w-4 h-4 text-navy-300 mx-auto mb-1" />
                      <p className="text-2xs text-navy-300">Interest</p>
                      <p className="text-sm font-bold text-white mt-0.5">{eligibility.interest_rate}%</p>
                    </div>
                    <div className="bg-white/10 backdrop-blur-sm rounded-2xl p-3.5 text-center">
                      <Banknote className="w-4 h-4 text-navy-300 mx-auto mb-1" />
                      <p className="text-2xs text-navy-300">Savings</p>
                      <p className="text-sm font-bold text-white mt-0.5">TZS {fmt(eligibility.savings_balance)}</p>
                    </div>
                  </div>
                </>
              ) : (
                <p className="text-sm text-navy-400">Unable to check eligibility</p>
              )}
            </div>
          </div>

          {/* Apply Form */}
          {eligibility?.eligible && (
            <div className="card">
              <h2 className="text-base font-semibold text-navy-900 mb-4">Apply for a Loan</h2>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-navy-700 mb-1.5">
                    Amount (TZS)
                  </label>
                  <input
                    type="number"
                    value={applyAmount}
                    onChange={(e) => setApplyAmount(e.target.value)}
                    className="input-field"
                    placeholder={`Up to TZS ${fmt(eligibility.max_amount)}`}
                    min={1}
                    max={parseFloat(eligibility.max_amount)}
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-navy-700 mb-1.5">Repayment Term</label>
                  <select
                    value={applyTerm}
                    onChange={(e) => setApplyTerm(e.target.value)}
                    className="input-field"
                  >
                    <option value="7">7 days</option>
                    <option value="14">14 days</option>
                    <option value="30">30 days</option>
                    <option value="60">60 days</option>
                    <option value="90">90 days</option>
                  </select>
                </div>

                {totalDue && (
                  <div className="bg-primary-50 rounded-2xl p-4">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-primary-700 font-medium">Estimated Total Due</span>
                      <span className="text-lg font-bold text-primary-900">TZS {fmt(totalDue)}</span>
                    </div>
                  </div>
                )}

                <button
                  onClick={handleApply}
                  disabled={applySubmitting || !applyAmount || parseFloat(applyAmount) <= 0}
                  className="w-full btn-primary"
                >
                  {applySubmitting ? 'Submitting...' : 'Apply for Loan'}
                </button>
              </div>
            </div>
          )}

          {/* My Loans */}
          <div>
            <h2 className="text-base font-semibold text-navy-900 mb-3">My Loans</h2>
            {loans.length === 0 ? (
              <div className="card text-center py-16">
                <div className="w-16 h-16 bg-navy-50 rounded-2xl flex items-center justify-center mx-auto mb-4">
                  <Banknote className="w-8 h-8 text-navy-300" />
                </div>
                <p className="text-navy-500 font-medium">No loans yet</p>
                <p className="text-navy-400 text-sm mt-1">Apply above when you need quick funds</p>
              </div>
            ) : (
              <div className="space-y-3">
                {loans.map((loan) => {
                  const remaining = parseFloat(loan.total_due) - parseFloat(loan.amount_paid)
                  const progress = parseFloat(loan.total_due) > 0
                    ? (parseFloat(loan.amount_paid) / parseFloat(loan.total_due)) * 100
                    : 0

                  return (
                    <div key={loan.id} className="card">
                      <div className="flex items-start justify-between mb-4">
                        <div>
                          <h3 className="font-semibold text-navy-900 capitalize">{loan.type} Loan</h3>
                          <p className="text-2xs text-navy-400 font-mono">{loan.loan_number}</p>
                        </div>
                        <span className={statusClass[loan.status] || 'badge-neutral'}>{loan.status}</span>
                      </div>

                      {/* Amount cards */}
                      <div className="grid grid-cols-2 gap-3 mb-4">
                        <div className="bg-navy-50 rounded-2xl p-3">
                          <p className="text-2xs text-navy-400">Principal</p>
                          <p className="text-sm font-bold text-navy-900">TZS {fmt(loan.principal)}</p>
                        </div>
                        <div className="bg-navy-50 rounded-2xl p-3">
                          <p className="text-2xs text-navy-400">Total Due</p>
                          <p className="text-sm font-bold text-navy-900">TZS {fmt(loan.total_due)}</p>
                        </div>
                      </div>

                      {/* Repayment progress bar */}
                      {(loan.status === 'disbursed' || loan.status === 'repaying') && (
                        <div className="mb-4">
                          <div className="flex justify-between text-2xs mb-1.5">
                            <span className="text-navy-400">Paid: TZS {fmt(loan.amount_paid)}</span>
                            <span className="font-semibold text-navy-600">{Math.round(progress)}%</span>
                          </div>
                          <div className="w-full bg-navy-100 rounded-full h-2.5">
                            <div
                              className="bg-gradient-to-r from-primary-500 to-green-500 rounded-full h-2.5 transition-all duration-500"
                              style={{ width: `${Math.min(100, progress)}%` }}
                            />
                          </div>
                          <p className="text-2xs text-navy-400 mt-1">Remaining: TZS {fmt(remaining)}</p>
                        </div>
                      )}

                      <div className="flex items-center justify-between text-2xs text-navy-400 mb-3">
                        <span className="flex items-center gap-1">
                          <Calendar className="w-3 h-3" /> {loan.term_days} days
                        </span>
                        <span className="flex items-center gap-1">
                          <Percent className="w-3 h-3" /> {loan.interest_rate}%
                        </span>
                        <span>Due: {new Date(loan.due_date).toLocaleDateString()}</span>
                      </div>

                      {(loan.status === 'disbursed' || loan.status === 'repaying') && (
                        <button
                          onClick={() => { setRepayModal(loan); setRepayAmount('') }}
                          className="w-full flex items-center justify-center gap-1.5 py-2.5 text-sm font-semibold rounded-2xl bg-green-50 text-green-700 hover:bg-green-100 transition-all active:scale-[0.98]"
                        >
                          <DollarSign className="w-4 h-4" /> Make Repayment
                        </button>
                      )}
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        </>
      )}

      {/* Repay Modal */}
      {repayModal && (
        <div className="fixed inset-0 bg-navy-950/50 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setRepayModal(null)}>
          <div className="bg-white rounded-3xl shadow-xl w-full max-w-md p-6" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-green-50 rounded-xl flex items-center justify-center">
                <DollarSign className="w-5 h-5 text-green-600" />
              </div>
              <div>
                <h2 className="text-lg font-bold text-navy-900">Repay Loan</h2>
                <p className="text-2xs text-navy-400 font-mono">{repayModal.loan_number}</p>
              </div>
            </div>

            <div className="bg-navy-50 rounded-2xl p-3.5 my-4">
              <p className="text-2xs text-navy-400">Remaining Balance</p>
              <p className="text-lg font-bold text-navy-900">
                TZS {fmt(parseFloat(repayModal.total_due) - parseFloat(repayModal.amount_paid))}
              </p>
            </div>

            <div className="mb-4">
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Repayment Amount (TZS)</label>
              <input
                type="number"
                value={repayAmount}
                onChange={(e) => setRepayAmount(e.target.value)}
                className="input-field"
                placeholder="Enter amount"
                min={1}
                autoFocus
              />
            </div>

            <div className="flex gap-3">
              <button onClick={() => setRepayModal(null)} className="flex-1 btn-secondary">
                Cancel
              </button>
              <button
                onClick={handleRepay}
                disabled={repaySubmitting || !repayAmount || parseFloat(repayAmount) <= 0}
                className="flex-1 btn-primary"
              >
                {repaySubmitting ? 'Processing...' : 'Repay'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
