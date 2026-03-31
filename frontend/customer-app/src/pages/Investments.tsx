import { useEffect, useState } from 'react'
import { TrendingUp, BarChart3, Clock, DollarSign, RefreshCw, ArrowUpRight } from 'lucide-react'
import toast from 'react-hot-toast'
import { investmentApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { InvestmentProduct, Investment } from '../types'

const riskStyle: Record<string, { badge: string; border: string; bg: string; icon: string }> = {
  low: { badge: 'bg-green-50 text-green-700', border: 'border-green-200', bg: 'bg-green-50', icon: 'text-green-600' },
  medium: { badge: 'bg-amber-50 text-amber-700', border: 'border-amber-200', bg: 'bg-amber-50', icon: 'text-amber-600' },
  high: { badge: 'bg-red-50 text-red-700', border: 'border-red-200', bg: 'bg-red-50', icon: 'text-red-600' },
}

const statusClass: Record<string, string> = {
  active: 'badge-success',
  matured: 'badge-info',
  withdrawn: 'badge-neutral',
}

export default function Investments() {
  const [products, setProducts] = useState<InvestmentProduct[]>([])
  const [investments, setInvestments] = useState<Investment[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [tab, setTab] = useState<'products' | 'mine'>('products')
  const [refreshing, setRefreshing] = useState(false)

  // Modal state
  const [investModal, setInvestModal] = useState<InvestmentProduct | null>(null)
  const [amount, setAmount] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const fmt = (amt: string | number) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(typeof amt === 'string' ? parseFloat(amt) : amt)

  const loadData = (isRefresh = false) => {
    if (isRefresh) setRefreshing(true)
    else setLoading(true)
    setError(false)
    Promise.all([
      investmentApi.listProducts(),
      investmentApi.listInvestments(),
    ]).then(([prodRes, invRes]) => {
      setProducts(prodRes.data.products || [])
      setInvestments(invRes.data.investments || [])
    }).catch((err: unknown) => {
      showLoadError(err, 'investments')
      setError(true)
    }).finally(() => {
      setLoading(false)
      setRefreshing(false)
    })
  }

  useEffect(() => { loadData() }, [])

  const handleInvest = async () => {
    if (!investModal || !amount || parseFloat(amount) <= 0) {
      toast.error('Enter a valid amount')
      return
    }
    if (parseFloat(amount) < parseFloat(investModal.min_amount)) {
      toast.error(`Minimum investment is TZS ${fmt(investModal.min_amount)}`)
      return
    }
    if (investModal.max_amount && parseFloat(amount) > parseFloat(investModal.max_amount)) {
      toast.error(`Maximum investment is TZS ${fmt(investModal.max_amount)}`)
      return
    }
    setSubmitting(true)
    try {
      await investmentApi.invest({ product_id: investModal.id, amount: parseFloat(amount) })
      toast.success(`Invested TZS ${fmt(amount)} in ${investModal.name}`)
      setInvestModal(null)
      setAmount('')
      setTab('mine')
      loadData()
    } catch (err: unknown) {
      showError(err, 'Investment failed')
    } finally {
      setSubmitting(false)
    }
  }

  const handleWithdraw = async (id: string) => {
    try {
      await investmentApi.withdrawInvestment(id)
      toast.success('Withdrawal initiated')
      loadData()
    } catch (err: unknown) {
      showError(err, 'Withdrawal failed')
    }
  }

  // Group products by risk level
  const groupedProducts: Record<string, InvestmentProduct[]> = {}
  for (const p of products) {
    const key = p.risk_level || 'other'
    if (!groupedProducts[key]) groupedProducts[key] = []
    groupedProducts[key].push(p)
  }
  const riskOrder = ['low', 'medium', 'high']
  const sortedRisks = Object.keys(groupedProducts).sort(
    (a, b) => (riskOrder.indexOf(a) === -1 ? 99 : riskOrder.indexOf(a)) - (riskOrder.indexOf(b) === -1 ? 99 : riskOrder.indexOf(b))
  )

  return (
    <div className="space-y-6">
      {/* Page header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-green-50 rounded-xl flex items-center justify-center">
            <TrendingUp className="w-5 h-5 text-green-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-navy-900">Investments</h1>
            <p className="text-navy-400 text-sm">Grow your wealth over time</p>
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

      {/* Tab selector */}
      <div className="flex gap-1 bg-navy-50 rounded-2xl p-1">
        <button
          onClick={() => setTab('products')}
          className={`flex-1 py-2.5 px-4 rounded-xl text-sm font-semibold transition-all ${
            tab === 'products'
              ? 'bg-white text-navy-900 shadow-sm'
              : 'text-navy-400 hover:text-navy-600'
          }`}
        >
          Products
        </button>
        <button
          onClick={() => setTab('mine')}
          className={`flex-1 py-2.5 px-4 rounded-xl text-sm font-semibold transition-all ${
            tab === 'mine'
              ? 'bg-white text-navy-900 shadow-sm'
              : 'text-navy-400 hover:text-navy-600'
          }`}
        >
          My Investments {investments.length > 0 && <span className="ml-1 badge-info">{investments.length}</span>}
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-primary-500 border-t-transparent" />
        </div>
      ) : error ? (
        <div className="card text-center py-16">
          <p className="text-navy-500 mb-4">Failed to load investments</p>
          <button onClick={() => loadData()} className="btn-primary">Retry</button>
        </div>
      ) : tab === 'products' ? (
        products.length === 0 ? (
          <div className="card text-center py-16">
            <div className="w-16 h-16 bg-navy-50 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <TrendingUp className="w-8 h-8 text-navy-300" />
            </div>
            <p className="text-navy-500 font-medium">No investment products available</p>
            <p className="text-navy-400 text-sm mt-1">Check back soon for new opportunities</p>
          </div>
        ) : (
          <div className="space-y-8">
            {sortedRisks.map((risk) => {
              const rs = riskStyle[risk] || riskStyle.low
              return (
                <div key={risk}>
                  <div className="flex items-center gap-2 mb-3">
                    <span className={`badge ${rs.badge} capitalize`}>{risk} risk</span>
                    <div className="flex-1 h-px bg-navy-100" />
                  </div>
                  <div className="grid gap-4 sm:grid-cols-2">
                    {groupedProducts[risk].map((product) => (
                      <div key={product.id} className={`card border ${rs.border} hover:shadow-md transition-all`}>
                        <div className="flex items-start justify-between mb-3">
                          <div className="flex-1 min-w-0">
                            <h3 className="font-semibold text-navy-900">{product.name}</h3>
                            <p className="text-2xs text-navy-400 mt-0.5 line-clamp-2">{product.description}</p>
                          </div>
                          <span className={`badge ${rs.badge} capitalize ml-2 flex-shrink-0`}>{product.risk_level}</span>
                        </div>

                        {/* Return highlight */}
                        <div className={`${rs.bg} rounded-2xl p-3.5 mb-4`}>
                          <div className="flex items-center gap-2 mb-1">
                            <ArrowUpRight className={`w-4 h-4 ${rs.icon}`} />
                            <span className="text-2xs font-medium text-navy-500">Expected Return</span>
                          </div>
                          <p className="text-2xl font-bold text-navy-900">{product.expected_return}%</p>
                        </div>

                        <div className="space-y-2 text-sm mb-4">
                          <div className="flex items-center justify-between">
                            <span className="text-navy-400 flex items-center gap-1.5">
                              <DollarSign className="w-3.5 h-3.5" /> Min Investment
                            </span>
                            <span className="font-semibold text-navy-700">TZS {fmt(product.min_amount)}</span>
                          </div>
                          {product.max_amount && (
                            <div className="flex items-center justify-between">
                              <span className="text-navy-400 flex items-center gap-1.5">
                                <DollarSign className="w-3.5 h-3.5" /> Max Investment
                              </span>
                              <span className="font-semibold text-navy-700">TZS {fmt(product.max_amount)}</span>
                            </div>
                          )}
                          {product.duration_days && (
                            <div className="flex items-center justify-between">
                              <span className="text-navy-400 flex items-center gap-1.5">
                                <Clock className="w-3.5 h-3.5" /> Duration
                              </span>
                              <span className="font-semibold text-navy-700">{product.duration_days} days</span>
                            </div>
                          )}
                          <div className="flex items-center justify-between">
                            <span className="text-navy-400 flex items-center gap-1.5">
                              <BarChart3 className="w-3.5 h-3.5" /> Type
                            </span>
                            <span className="font-semibold text-navy-700 capitalize">{product.type}</span>
                          </div>
                        </div>

                        <button
                          onClick={() => { setInvestModal(product); setAmount('') }}
                          className="w-full btn-primary"
                        >
                          Invest Now
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )
            })}
          </div>
        )
      ) : (
        investments.length === 0 ? (
          <div className="card text-center py-16">
            <div className="w-16 h-16 bg-navy-50 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <TrendingUp className="w-8 h-8 text-navy-300" />
            </div>
            <p className="text-navy-500 font-medium mb-1">No investments yet</p>
            <p className="text-navy-400 text-sm mb-6">Start growing your wealth today</p>
            <button onClick={() => setTab('products')} className="btn-primary">Browse Products</button>
          </div>
        ) : (
          <div className="space-y-3">
            {investments.map((inv) => (
              <div key={inv.id} className="card">
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <h3 className="font-semibold text-navy-900">{inv.product_name}</h3>
                    <p className="text-2xs text-navy-400 capitalize">{inv.product_type}</p>
                  </div>
                  <span className={statusClass[inv.status] || 'badge-neutral'}>{inv.status}</span>
                </div>

                <div className="bg-navy-50 rounded-2xl p-3.5 mb-4">
                  <p className="text-2xs text-navy-400 font-medium">Amount Invested</p>
                  <p className="text-xl font-bold text-navy-900">TZS {fmt(inv.amount)}</p>
                </div>

                <div className="grid grid-cols-2 gap-3 text-sm mb-3">
                  <div>
                    <p className="text-2xs text-navy-400">Expected Return</p>
                    <p className="font-semibold text-navy-700">{inv.expected_return}%</p>
                  </div>
                  {inv.actual_return && (
                    <div>
                      <p className="text-2xs text-navy-400">Actual Return</p>
                      <p className="font-semibold text-green-600">TZS {fmt(inv.actual_return)}</p>
                    </div>
                  )}
                </div>

                <div className="flex items-center justify-between text-2xs text-navy-400 mb-3">
                  {inv.maturity_date && (
                    <span className="flex items-center gap-1">
                      <Clock className="w-3 h-3" /> Matures {new Date(inv.maturity_date).toLocaleDateString()}
                    </span>
                  )}
                  <span>Created {new Date(inv.created_at).toLocaleDateString()}</span>
                </div>

                {inv.status === 'active' && (
                  <button
                    onClick={() => handleWithdraw(inv.id)}
                    className="w-full flex items-center justify-center gap-1.5 py-2.5 text-sm font-semibold rounded-2xl bg-primary-50 text-primary-700 hover:bg-primary-100 transition-all active:scale-[0.98]"
                  >
                    Withdraw
                  </button>
                )}
              </div>
            ))}
          </div>
        )
      )}

      {/* Invest Modal */}
      {investModal && (
        <div className="fixed inset-0 bg-navy-950/50 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setInvestModal(null)}>
          <div className="bg-white rounded-3xl shadow-xl w-full max-w-md max-h-[90vh] overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-green-50 rounded-xl flex items-center justify-center">
                <TrendingUp className="w-5 h-5 text-green-600" />
              </div>
              <div>
                <h2 className="text-lg font-bold text-navy-900">Invest in {investModal.name}</h2>
                <p className="text-2xs text-navy-400">
                  {investModal.expected_return}% return | {investModal.duration_days ? `${investModal.duration_days} days` : 'Flexible'}
                </p>
              </div>
            </div>

            <div className="bg-navy-50 rounded-2xl p-3.5 my-4">
              <div className="flex justify-between text-sm">
                <div>
                  <p className="text-2xs text-navy-400">Min</p>
                  <p className="font-semibold text-navy-700">TZS {fmt(investModal.min_amount)}</p>
                </div>
                {investModal.max_amount && (
                  <div className="text-right">
                    <p className="text-2xs text-navy-400">Max</p>
                    <p className="font-semibold text-navy-700">TZS {fmt(investModal.max_amount)}</p>
                  </div>
                )}
              </div>
            </div>

            <div className="mb-4">
              <label className="block text-sm font-medium text-navy-700 mb-1.5">Amount (TZS)</label>
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="input-field"
                placeholder="Enter investment amount"
                min={parseFloat(investModal.min_amount)}
                max={investModal.max_amount ? parseFloat(investModal.max_amount) : undefined}
                autoFocus
              />
            </div>

            <div className="flex gap-3">
              <button onClick={() => setInvestModal(null)} className="flex-1 btn-secondary">
                Cancel
              </button>
              <button
                onClick={handleInvest}
                disabled={submitting || !amount || parseFloat(amount) <= 0}
                className="flex-1 btn-primary"
              >
                {submitting ? 'Processing...' : 'Invest'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
