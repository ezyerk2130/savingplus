import { useEffect, useState } from 'react'
import { Banknote, CheckCircle, AlertCircle, DollarSign } from 'lucide-react'
import toast from 'react-hot-toast'
import { loanApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { Loan } from '../types'

const statusBadge = (status: string) => {
  switch (status) {
    case 'disbursed': case 'repaying': return 'bg-amber-100 text-amber-700'
    case 'paid': return 'bg-green-100 text-green-700'
    case 'pending': return 'bg-blue-100 text-blue-700'
    case 'rejected': case 'defaulted': return 'bg-red-100 text-red-700'
    default: return 'bg-gray-100 text-gray-600'
  }
}

export default function Loans() {
  const [loans, setLoans] = useState<Loan[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)

  // Eligibility
  const [eligibility, setEligibility] = useState<{
    eligible: boolean; max_amount: number; interest_rate: number; savings_balance: number
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

  const formatAmount = (amt: string | number) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(typeof amt === 'string' ? parseFloat(amt) : amt)

  const loadData = () => {
    setLoading(true)
    setError(false)
    setEligLoading(true)
    Promise.all([
      loanApi.list(),
      loanApi.checkEligibility(),
    ]).then(([loansRes, eligRes]) => {
      setLoans(loansRes.data.loans || loansRes.data || [])
      setEligibility(eligRes.data)
    }).catch((err: unknown) => {
      showLoadError(err, 'loans')
      setError(true)
    }).finally(() => {
      setLoading(false)
      setEligLoading(false)
    })
  }

  useEffect(() => { loadData() }, [])

  // Calculate total due for application preview
  const previewTotalDue = () => {
    if (!applyAmount || !eligibility) return null
    const principal = parseFloat(applyAmount)
    const term = parseInt(applyTerm)
    if (isNaN(principal) || isNaN(term) || principal <= 0) return null
    const interest = principal * (eligibility.interest_rate / 100) * (term / 365)
    return principal + interest
  }

  const handleApply = async () => {
    if (!applyAmount || parseFloat(applyAmount) <= 0) {
      toast.error('Enter a valid amount')
      return
    }
    if (eligibility && parseFloat(applyAmount) > eligibility.max_amount) {
      toast.error(`Maximum loan amount is TZS ${formatAmount(eligibility.max_amount)}`)
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
      toast.success(`Repaid TZS ${formatAmount(repayAmount)}`)
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
      <h1 className="text-2xl font-bold">Loans</h1>

      {loading ? (
        <div className="flex items-center justify-center h-32">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
        </div>
      ) : error ? (
        <div className="card text-center py-12">
          <p className="text-gray-600 mb-4">Failed to load loans</p>
          <button onClick={loadData} className="btn-primary">Retry</button>
        </div>
      ) : (
        <>
          {/* Eligibility Section */}
          <div className="card border border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Loan Eligibility</h2>

            {eligLoading ? (
              <div className="flex items-center justify-center h-16">
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-primary-600" />
              </div>
            ) : eligibility ? (
              <div className="space-y-4">
                <div className="flex items-center gap-2 mb-3">
                  {eligibility.eligible ? (
                    <>
                      <CheckCircle className="w-5 h-5 text-green-600" />
                      <span className="text-sm font-medium text-green-700">You are eligible for a loan</span>
                    </>
                  ) : (
                    <>
                      <AlertCircle className="w-5 h-5 text-red-600" />
                      <span className="text-sm font-medium text-red-700">Not eligible at this time</span>
                    </>
                  )}
                </div>

                <div className="grid grid-cols-3 gap-3">
                  <div className="bg-gray-50 rounded-lg p-3 text-center">
                    <p className="text-xs text-gray-500">Max Loan</p>
                    <p className="text-sm font-bold text-gray-900">TZS {formatAmount(eligibility.max_amount)}</p>
                  </div>
                  <div className="bg-gray-50 rounded-lg p-3 text-center">
                    <p className="text-xs text-gray-500">Interest Rate</p>
                    <p className="text-sm font-bold text-gray-900">{eligibility.interest_rate}%</p>
                  </div>
                  <div className="bg-gray-50 rounded-lg p-3 text-center">
                    <p className="text-xs text-gray-500">Savings Balance</p>
                    <p className="text-sm font-bold text-gray-900">TZS {formatAmount(eligibility.savings_balance)}</p>
                  </div>
                </div>

                {eligibility.eligible && (
                  <div className="space-y-3 pt-4 border-t border-gray-200">
                    <h3 className="text-sm font-semibold text-gray-700">Apply for a Loan</h3>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Amount (TZS) - Max: TZS {formatAmount(eligibility.max_amount)}
                      </label>
                      <input
                        type="number"
                        value={applyAmount}
                        onChange={(e) => setApplyAmount(e.target.value)}
                        className="input-field"
                        placeholder="Enter loan amount"
                        min={1}
                        max={eligibility.max_amount}
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Term (days)</label>
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
                      <div className="bg-blue-50 rounded-lg p-3">
                        <div className="flex justify-between text-sm">
                          <span className="text-blue-700">Estimated Total Due</span>
                          <span className="font-bold text-blue-900">TZS {formatAmount(totalDue)}</span>
                        </div>
                      </div>
                    )}

                    <button
                      onClick={handleApply}
                      disabled={applySubmitting || !applyAmount || parseFloat(applyAmount) <= 0}
                      className="w-full btn-primary disabled:opacity-50"
                    >
                      {applySubmitting ? 'Submitting...' : 'Apply for Loan'}
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <p className="text-sm text-gray-500">Unable to check eligibility</p>
            )}
          </div>

          {/* My Loans */}
          <div>
            <h2 className="text-lg font-semibold text-gray-900 mb-3">My Loans</h2>
            {loans.length === 0 ? (
              <div className="card text-center py-12">
                <Banknote className="w-12 h-12 text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500">No loans yet</p>
              </div>
            ) : (
              <div className="grid gap-4 sm:grid-cols-2">
                {loans.map((loan) => {
                  const remaining = parseFloat(loan.total_due) - parseFloat(loan.amount_paid)
                  const progress = parseFloat(loan.total_due) > 0
                    ? (parseFloat(loan.amount_paid) / parseFloat(loan.total_due)) * 100
                    : 0

                  return (
                    <div key={loan.id} className="card border border-gray-200">
                      <div className="flex items-start justify-between mb-3">
                        <div>
                          <h3 className="font-semibold text-gray-900 capitalize">{loan.type} Loan</h3>
                          <p className="text-xs text-gray-500 font-mono">{loan.loan_number}</p>
                        </div>
                        <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusBadge(loan.status)}`}>
                          {loan.status}
                        </span>
                      </div>

                      <div className="space-y-2 text-sm">
                        <div className="flex justify-between text-gray-600">
                          <span>Principal</span>
                          <span className="font-semibold text-gray-900">TZS {formatAmount(loan.principal)}</span>
                        </div>
                        <div className="flex justify-between text-gray-600">
                          <span>Interest Rate</span>
                          <span>{loan.interest_rate}%</span>
                        </div>
                        <div className="flex justify-between text-gray-600">
                          <span>Total Due</span>
                          <span className="font-semibold text-gray-900">TZS {formatAmount(loan.total_due)}</span>
                        </div>
                        <div className="flex justify-between text-gray-600">
                          <span>Paid</span>
                          <span>TZS {formatAmount(loan.amount_paid)}</span>
                        </div>

                        {/* Repayment progress */}
                        {(loan.status === 'disbursed' || loan.status === 'repaying') && (
                          <div>
                            <div className="flex justify-between text-xs text-gray-500 mb-1">
                              <span>Remaining: TZS {formatAmount(remaining)}</span>
                              <span>{Math.round(progress)}%</span>
                            </div>
                            <div className="w-full bg-gray-200 rounded-full h-2">
                              <div
                                className="bg-green-500 rounded-full h-2 transition-all"
                                style={{ width: `${Math.min(100, progress)}%` }}
                              />
                            </div>
                          </div>
                        )}

                        <div className="flex justify-between text-xs text-gray-500 pt-1">
                          <span>Term: {loan.term_days} days</span>
                          <span>Due: {new Date(loan.due_date).toLocaleDateString()}</span>
                        </div>

                        {(loan.status === 'disbursed' || loan.status === 'repaying') && (
                          <div className="pt-3 border-t border-gray-200 mt-3">
                            <button
                              onClick={() => { setRepayModal(loan); setRepayAmount('') }}
                              className="w-full flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-emerald-100 text-emerald-700 hover:bg-emerald-200 transition-colors"
                            >
                              <DollarSign className="w-3.5 h-3.5" /> Repay
                            </button>
                          </div>
                        )}
                      </div>
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
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4" onClick={() => setRepayModal(null)}>
          <div className="bg-white rounded-xl shadow-xl w-full max-w-sm p-6" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-1">Repay Loan</h2>
            <p className="text-sm text-gray-500 mb-4">{repayModal.loan_number}</p>

            <div className="mb-2">
              <p className="text-xs text-gray-500">Remaining Balance</p>
              <p className="font-semibold">
                TZS {formatAmount(parseFloat(repayModal.total_due) - parseFloat(repayModal.amount_paid))}
              </p>
            </div>

            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-1">Amount (TZS)</label>
              <input
                type="number"
                value={repayAmount}
                onChange={(e) => setRepayAmount(e.target.value)}
                className="input-field"
                placeholder="Enter repayment amount"
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
                className="flex-1 btn-primary disabled:opacity-50"
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
