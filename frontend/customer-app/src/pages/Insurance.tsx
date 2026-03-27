import { useEffect, useState } from 'react'
import { ShieldCheck, XCircle } from 'lucide-react'
import toast from 'react-hot-toast'
import { insuranceApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { InsuranceProduct, InsurancePolicy } from '../types'

const typeBadge = (type: string) => {
  switch (type) {
    case 'health': return 'bg-green-100 text-green-700'
    case 'life': return 'bg-blue-100 text-blue-700'
    case 'crop': return 'bg-amber-100 text-amber-700'
    case 'device': return 'bg-purple-100 text-purple-700'
    default: return 'bg-gray-100 text-gray-600'
  }
}

const statusBadge = (status: string) => {
  switch (status) {
    case 'active': return 'bg-green-100 text-green-700'
    case 'expired': return 'bg-gray-100 text-gray-600'
    case 'cancelled': return 'bg-red-100 text-red-700'
    case 'claimed': return 'bg-blue-100 text-blue-700'
    default: return 'bg-gray-100 text-gray-600'
  }
}

export default function Insurance() {
  const [products, setProducts] = useState<InsuranceProduct[]>([])
  const [policies, setPolicies] = useState<InsurancePolicy[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [tab, setTab] = useState<'products' | 'policies'>('products')

  // Subscribe modal state
  const [subscribeModal, setSubscribeModal] = useState<InsuranceProduct | null>(null)
  const [beneficiaryName, setBeneficiaryName] = useState('')
  const [beneficiaryPhone, setBeneficiaryPhone] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const formatAmount = (amt: string | number) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(typeof amt === 'string' ? parseFloat(amt) : amt)

  const loadData = () => {
    setLoading(true)
    setError(false)
    Promise.all([
      insuranceApi.listProducts(),
      insuranceApi.listPolicies(),
    ]).then(([prodRes, polRes]) => {
      setProducts(prodRes.data.products || prodRes.data || [])
      setPolicies(polRes.data.policies || polRes.data || [])
    }).catch((err: unknown) => {
      showLoadError(err, 'insurance')
      setError(true)
    }).finally(() => setLoading(false))
  }

  useEffect(() => { loadData() }, [])

  const handleSubscribe = async () => {
    if (!subscribeModal) return
    setSubmitting(true)
    try {
      await insuranceApi.subscribe({
        product_id: subscribeModal.id,
        beneficiary_name: beneficiaryName || undefined,
        beneficiary_phone: beneficiaryPhone || undefined,
      })
      toast.success(`Subscribed to ${subscribeModal.name}`)
      setSubscribeModal(null)
      setBeneficiaryName('')
      setBeneficiaryPhone('')
      setTab('policies')
      loadData()
    } catch (err: unknown) {
      showError(err, 'Subscription failed')
    } finally {
      setSubmitting(false)
    }
  }

  const handleCancel = async (id: string) => {
    try {
      await insuranceApi.cancelPolicy(id)
      toast.success('Policy cancelled')
      loadData()
    } catch (err: unknown) {
      showError(err, 'Cancellation failed')
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Insurance</h1>
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
          onClick={() => setTab('policies')}
          className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
            tab === 'policies' ? 'bg-white text-primary-700 shadow-sm' : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          My Policies
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
        </div>
      ) : error ? (
        <div className="card text-center py-12">
          <p className="text-gray-600 mb-4">Failed to load insurance</p>
          <button onClick={loadData} className="btn-primary">Retry</button>
        </div>
      ) : tab === 'products' ? (
        products.length === 0 ? (
          <div className="card text-center py-12">
            <ShieldCheck className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500">No insurance products available</p>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2">
            {products.map((product) => (
              <div key={product.id} className="card border border-gray-200">
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <h3 className="font-semibold text-gray-900">{product.name}</h3>
                    <p className="text-xs text-gray-500 mt-0.5">{product.description}</p>
                  </div>
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${typeBadge(product.type)}`}>
                    {product.type}
                  </span>
                </div>

                <div className="space-y-2 text-sm">
                  <div className="flex justify-between text-gray-600">
                    <span>Provider</span>
                    <span className="font-medium text-gray-900">{product.provider}</span>
                  </div>
                  <div className="flex justify-between text-gray-600">
                    <span>Premium</span>
                    <span className="font-semibold text-gray-900">
                      TZS {formatAmount(product.premium_amount)}/{product.premium_frequency}
                    </span>
                  </div>
                  <div className="flex justify-between text-gray-600">
                    <span>Coverage</span>
                    <span className="font-semibold text-gray-900">TZS {formatAmount(product.coverage_amount)}</span>
                  </div>
                </div>

                <button
                  onClick={() => { setSubscribeModal(product); setBeneficiaryName(''); setBeneficiaryPhone('') }}
                  className="w-full mt-4 btn-primary text-sm"
                >
                  Subscribe
                </button>
              </div>
            ))}
          </div>
        )
      ) : (
        policies.length === 0 ? (
          <div className="card text-center py-12">
            <ShieldCheck className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500 mb-4">No active policies</p>
            <button onClick={() => setTab('products')} className="btn-primary">Browse Products</button>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2">
            {policies.map((policy) => (
              <div key={policy.id} className="card border border-gray-200">
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <h3 className="font-semibold text-gray-900">{policy.product_name}</h3>
                    <p className="text-xs text-gray-500 capitalize">{policy.product_type}</p>
                  </div>
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusBadge(policy.status)}`}>
                    {policy.status}
                  </span>
                </div>

                <div className="space-y-2 text-sm">
                  <div className="flex justify-between text-gray-600">
                    <span>Policy #</span>
                    <span className="font-mono text-xs">{policy.policy_number}</span>
                  </div>
                  <div className="flex justify-between text-gray-600">
                    <span>Premium Paid</span>
                    <span className="font-semibold text-gray-900">TZS {formatAmount(policy.premium_paid)}</span>
                  </div>
                  <div className="flex justify-between text-gray-600">
                    <span>Coverage</span>
                    <span className="text-xs">
                      {new Date(policy.coverage_start).toLocaleDateString()} - {new Date(policy.coverage_end).toLocaleDateString()}
                    </span>
                  </div>
                  <p className="text-xs text-gray-400">
                    Created: {new Date(policy.created_at).toLocaleDateString()}
                  </p>

                  {policy.status === 'active' && (
                    <div className="pt-3 border-t border-gray-200 mt-3">
                      <button
                        onClick={() => handleCancel(policy.id)}
                        className="w-full flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-red-100 text-red-700 hover:bg-red-200 transition-colors"
                      >
                        <XCircle className="w-3.5 h-3.5" /> Cancel Policy
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )
      )}

      {/* Subscribe Modal */}
      {subscribeModal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4" onClick={() => setSubscribeModal(null)}>
          <div className="bg-white rounded-xl shadow-xl w-full max-w-sm p-6" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-1">Subscribe to {subscribeModal.name}</h2>
            <p className="text-sm text-gray-500 mb-4">
              TZS {formatAmount(subscribeModal.premium_amount)}/{subscribeModal.premium_frequency} | Coverage: TZS {formatAmount(subscribeModal.coverage_amount)}
            </p>

            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Beneficiary Name</label>
                <input
                  type="text"
                  value={beneficiaryName}
                  onChange={(e) => setBeneficiaryName(e.target.value)}
                  className="input-field"
                  placeholder="Optional"
                  autoFocus
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Beneficiary Phone</label>
                <input
                  type="tel"
                  value={beneficiaryPhone}
                  onChange={(e) => setBeneficiaryPhone(e.target.value)}
                  className="input-field"
                  placeholder="Optional"
                />
              </div>
            </div>

            <div className="flex gap-3 mt-5">
              <button onClick={() => setSubscribeModal(null)} className="flex-1 btn-secondary">
                Cancel
              </button>
              <button
                onClick={handleSubscribe}
                disabled={submitting}
                className="flex-1 btn-primary disabled:opacity-50"
              >
                {submitting ? 'Subscribing...' : 'Subscribe'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
