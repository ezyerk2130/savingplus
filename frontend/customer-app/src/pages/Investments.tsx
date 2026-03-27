import { useEffect, useState } from 'react'
import { TrendingUp, BarChart3, Clock, DollarSign } from 'lucide-react'
import toast from 'react-hot-toast'
import { investmentApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { InvestmentProduct, Investment } from '../types'

const riskColor = (level: string) => {
  switch (level) {
    case 'low': return 'bg-green-100 text-green-700'
    case 'medium': return 'bg-amber-100 text-amber-700'
    case 'high': return 'bg-red-100 text-red-700'
    default: return 'bg-gray-100 text-gray-600'
  }
}

const riskBorder = (level: string) => {
  switch (level) {
    case 'low': return 'border-green-200'
    case 'medium': return 'border-amber-200'
    case 'high': return 'border-red-200'
    default: return 'border-gray-200'
  }
}

const statusBadge = (status: string) => {
  switch (status) {
    case 'active': return 'bg-green-100 text-green-700'
    case 'matured': return 'bg-blue-100 text-blue-700'
    case 'withdrawn': return 'bg-gray-100 text-gray-600'
    default: return 'bg-gray-100 text-gray-600'
  }
}

export default function Investments() {
  const [products, setProducts] = useState<InvestmentProduct[]>([])
  const [investments, setInvestments] = useState<Investment[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [tab, setTab] = useState<'products' | 'mine'>('products')

  // Modal state
  const [investModal, setInvestModal] = useState<InvestmentProduct | null>(null)
  const [amount, setAmount] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const formatAmount = (amt: string | number) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(typeof amt === 'string' ? parseFloat(amt) : amt)

  const loadData = () => {
    setLoading(true)
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
    }).finally(() => setLoading(false))
  }

  useEffect(() => { loadData() }, [])

  const handleInvest = async () => {
    if (!investModal || !amount || parseFloat(amount) <= 0) {
      toast.error('Enter a valid amount')
      return
    }
    if (parseFloat(amount) < parseFloat(investModal.min_amount)) {
      toast.error(`Minimum investment is TZS ${formatAmount(investModal.min_amount)}`)
      return
    }
    if (investModal.max_amount && parseFloat(amount) > parseFloat(investModal.max_amount)) {
      toast.error(`Maximum investment is TZS ${formatAmount(investModal.max_amount)}`)
      return
    }
    setSubmitting(true)
    try {
      await investmentApi.invest({ product_id: investModal.id, amount: parseFloat(amount) })
      toast.success(`Invested TZS ${formatAmount(amount)} in ${investModal.name}`)
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
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Investments</h1>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 rounded-lg p-1">
        <button
          onClick={() => setTab('products')}
          className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
            tab === 'products' ? 'bg-white text-primary-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          Products
        </button>
        <button
          onClick={() => setTab('mine')}
          className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
            tab === 'mine' ? 'bg-white text-primary-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          My Investments
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
        </div>
      ) : error ? (
        <div className="card text-center py-12">
          <p className="text-gray-600 mb-4">Failed to load investments</p>
          <button onClick={loadData} className="btn-primary">Retry</button>
        </div>
      ) : tab === 'products' ? (
        products.length === 0 ? (
          <div className="card text-center py-12">
            <TrendingUp className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500">No investment products available</p>
          </div>
        ) : (
          <div className="space-y-6">
            {sortedRisks.map((risk) => (
              <div key={risk}>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">
                  {risk} risk
                </h2>
                <div className="grid gap-4 sm:grid-cols-2">
                  {groupedProducts[risk].map((product) => (
                    <div key={product.id} className={`card border ${riskBorder(product.risk_level)}`}>
                      <div className="flex items-start justify-between mb-3">
                        <div>
                          <h3 className="font-semibold text-gray-900">{product.name}</h3>
                          <p className="text-xs text-gray-500 mt-0.5">{product.description}</p>
                        </div>
                        <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${riskColor(product.risk_level)}`}>
                          {product.risk_level}
                        </span>
                      </div>

                      <div className="space-y-2 text-sm">
                        <div className="flex items-center gap-2 text-gray-600">
                          <TrendingUp className="w-4 h-4" />
                          <span>Expected return: <strong className="text-gray-900">{product.expected_return}%</strong></span>
                        </div>
                        <div className="flex items-center gap-2 text-gray-600">
                          <DollarSign className="w-4 h-4" />
                          <span>Min: TZS {formatAmount(product.min_amount)}</span>
                          {product.max_amount && <span>/ Max: TZS {formatAmount(product.max_amount)}</span>}
                        </div>
                        {product.duration_days && (
                          <div className="flex items-center gap-2 text-gray-600">
                            <Clock className="w-4 h-4" />
                            <span>{product.duration_days} days</span>
                          </div>
                        )}
                        <div className="flex items-center gap-2 text-gray-600">
                          <BarChart3 className="w-4 h-4" />
                          <span className="capitalize">{product.type}</span>
                        </div>
                      </div>

                      <button
                        onClick={() => { setInvestModal(product); setAmount('') }}
                        className="w-full mt-4 btn-primary text-sm"
                      >
                        Invest
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )
      ) : (
        investments.length === 0 ? (
          <div className="card text-center py-12">
            <TrendingUp className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500 mb-4">No investments yet</p>
            <button onClick={() => setTab('products')} className="btn-primary">Browse Products</button>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2">
            {investments.map((inv) => (
              <div key={inv.id} className="card border border-gray-200">
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <h3 className="font-semibold text-gray-900">{inv.product_name}</h3>
                    <p className="text-xs text-gray-500 capitalize">{inv.product_type}</p>
                  </div>
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusBadge(inv.status)}`}>
                    {inv.status}
                  </span>
                </div>

                <div className="space-y-2">
                  <div>
                    <p className="text-xs text-gray-500">Invested</p>
                    <p className="text-lg font-bold">TZS {formatAmount(inv.amount)}</p>
                  </div>
                  <div className="flex justify-between text-xs text-gray-500">
                    <span>Expected: {inv.expected_return}%</span>
                    {inv.actual_return && <span>Actual: TZS {formatAmount(inv.actual_return)}</span>}
                  </div>
                  {inv.maturity_date && (
                    <p className="text-xs text-gray-500">
                      Matures: {new Date(inv.maturity_date).toLocaleDateString()}
                    </p>
                  )}
                  <p className="text-xs text-gray-400">
                    Created: {new Date(inv.created_at).toLocaleDateString()}
                  </p>

                  {inv.status === 'active' && (
                    <div className="pt-3 border-t border-gray-200 mt-3">
                      <button
                        onClick={() => handleWithdraw(inv.id)}
                        className="w-full flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-blue-100 text-blue-700 hover:bg-blue-200 transition-colors"
                      >
                        Withdraw
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )
      )}

      {/* Invest Modal */}
      {investModal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4" onClick={() => setInvestModal(null)}>
          <div className="bg-white rounded-xl shadow-xl w-full max-w-sm max-h-[90vh] overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-1">Invest in {investModal.name}</h2>
            <p className="text-sm text-gray-500 mb-4">
              Expected return: {investModal.expected_return}% | {investModal.duration_days ? `${investModal.duration_days} days` : 'Flexible'}
            </p>

            <div className="text-xs text-gray-500 mb-3 space-y-1">
              <p>Min: TZS {formatAmount(investModal.min_amount)}</p>
              {investModal.max_amount && <p>Max: TZS {formatAmount(investModal.max_amount)}</p>}
            </div>

            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-1">Amount (TZS)</label>
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="input-field"
                placeholder="Enter amount"
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
                className="flex-1 btn-primary disabled:opacity-50"
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
