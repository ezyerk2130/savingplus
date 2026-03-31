import { useEffect, useState } from 'react'
import { ShieldCheck, XCircle, RefreshCw, Heart, Sprout, Smartphone, User } from 'lucide-react'
import toast from 'react-hot-toast'
import { insuranceApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { InsuranceProduct, InsurancePolicy } from '../types'

const typeIcon: Record<string, { icon: typeof Heart; bg: string; color: string }> = {
  health: { icon: Heart, bg: 'bg-green-50', color: 'text-green-600' },
  life: { icon: User, bg: 'bg-blue-50', color: 'text-blue-600' },
  crop: { icon: Sprout, bg: 'bg-amber-50', color: 'text-amber-600' },
  device: { icon: Smartphone, bg: 'bg-purple-50', color: 'text-purple-600' },
}

const statusClass: Record<string, string> = {
  active: 'badge-success',
  expired: 'badge-neutral',
  cancelled: 'badge-danger',
  claimed: 'badge-info',
}

export default function Insurance() {
  const [products, setProducts] = useState<InsuranceProduct[]>([])
  const [policies, setPolicies] = useState<InsurancePolicy[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [tab, setTab] = useState<'products' | 'policies'>('products')
  const [refreshing, setRefreshing] = useState(false)

  // Subscribe modal state
  const [subscribeModal, setSubscribeModal] = useState<InsuranceProduct | null>(null)
  const [beneficiaryName, setBeneficiaryName] = useState('')
  const [beneficiaryPhone, setBeneficiaryPhone] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const fmt = (amt: string | number) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(typeof amt === 'string' ? parseFloat(amt) : amt)

  const loadData = (isRefresh = false) => {
    if (isRefresh) setRefreshing(true)
    else setLoading(true)
    setError(false)
    Promise.all([
      insuranceApi.listProducts(),
      insuranceApi.listPolicies(),
    ]).then(([prodRes, polRes]) => {
      setProducts(prodRes.data.products || [])
      setPolicies(polRes.data.policies || [])
    }).catch((err: unknown) => {
      showLoadError(err, 'insurance')
      setError(true)
    }).finally(() => {
      setLoading(false)
      setRefreshing(false)
    })
  }

  useEffect(() => { loadData() }, [])

  const handleSubscribe = async () => {
    if (!subscribeModal) return
    if (!beneficiaryName.trim()) { toast.error('Beneficiary name is required'); return }
    if (!beneficiaryPhone.trim()) { toast.error('Beneficiary phone is required'); return }
    setSubmitting(true)
    try {
      await insuranceApi.subscribe({
        product_id: subscribeModal.id,
        beneficiary_name: beneficiaryName,
        beneficiary_phone: beneficiaryPhone,
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
      {/* Page header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center">
            <ShieldCheck className="w-5 h-5 text-blue-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-navy-900">Insurance</h1>
            <p className="text-navy-400 text-sm">Protect what matters most</p>
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
          onClick={() => setTab('policies')}
          className={`flex-1 py-2.5 px-4 rounded-xl text-sm font-semibold transition-all ${
            tab === 'policies'
              ? 'bg-white text-navy-900 shadow-sm'
              : 'text-navy-400 hover:text-navy-600'
          }`}
        >
          My Policies {policies.length > 0 && <span className="ml-1 badge-info">{policies.length}</span>}
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-primary-500 border-t-transparent" />
        </div>
      ) : error ? (
        <div className="card text-center py-16">
          <p className="text-navy-500 mb-4">Failed to load insurance</p>
          <button onClick={() => loadData()} className="btn-primary">Retry</button>
        </div>
      ) : tab === 'products' ? (
        products.length === 0 ? (
          <div className="card text-center py-16">
            <div className="w-16 h-16 bg-navy-50 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <ShieldCheck className="w-8 h-8 text-navy-300" />
            </div>
            <p className="text-navy-500 font-medium">No insurance products available</p>
            <p className="text-navy-400 text-sm mt-1">Check back soon for new offerings</p>
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2">
            {products.map((product) => {
              const ti = typeIcon[product.type] || { icon: ShieldCheck, bg: 'bg-navy-50', color: 'text-navy-600' }
              const Icon = ti.icon
              return (
                <div key={product.id} className="card hover:border-primary-200 transition-colors">
                  <div className="flex items-start gap-3 mb-4">
                    <div className={`w-10 h-10 ${ti.bg} rounded-xl flex items-center justify-center flex-shrink-0`}>
                      <Icon className={`w-5 h-5 ${ti.color}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2">
                        <h3 className="font-semibold text-navy-900">{product.name}</h3>
                        <span className={`badge ${ti.bg} ${ti.color} capitalize flex-shrink-0`}>{product.type}</span>
                      </div>
                      <p className="text-2xs text-navy-400 mt-0.5 line-clamp-2">{product.description}</p>
                    </div>
                  </div>

                  <div className="bg-navy-50/50 rounded-2xl p-3.5 mb-4">
                    <div className="flex justify-between items-baseline">
                      <div>
                        <p className="text-2xs text-navy-400 font-medium">Premium</p>
                        <p className="text-lg font-bold text-navy-900">
                          TZS {fmt(product.premium_amount)}
                          <span className="text-sm font-normal text-navy-400">/{product.premium_frequency}</span>
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-2xs text-navy-400 font-medium">Coverage</p>
                        <p className="text-sm font-bold text-navy-900">TZS {fmt(product.coverage_amount)}</p>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center justify-between text-sm mb-4">
                    <span className="text-navy-400">Provider</span>
                    <span className="font-medium text-navy-700">{product.provider}</span>
                  </div>

                  <button
                    onClick={() => { setSubscribeModal(product); setBeneficiaryName(''); setBeneficiaryPhone('') }}
                    className="w-full btn-primary"
                  >
                    Subscribe
                  </button>
                </div>
              )
            })}
          </div>
        )
      ) : (
        policies.length === 0 ? (
          <div className="card text-center py-16">
            <div className="w-16 h-16 bg-navy-50 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <ShieldCheck className="w-8 h-8 text-navy-300" />
            </div>
            <p className="text-navy-500 font-medium mb-1">No active policies</p>
            <p className="text-navy-400 text-sm mb-6">Browse products to get covered</p>
            <button onClick={() => setTab('products')} className="btn-primary">Browse Products</button>
          </div>
        ) : (
          <div className="space-y-3">
            {policies.map((policy) => (
              <div key={policy.id} className="card">
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <h3 className="font-semibold text-navy-900">{policy.product_name}</h3>
                    <p className="text-2xs text-navy-400 capitalize">{policy.product_type}</p>
                  </div>
                  <span className={statusClass[policy.status] || 'badge-neutral'}>{policy.status}</span>
                </div>

                <div className="space-y-2.5 text-sm">
                  <div className="flex justify-between">
                    <span className="text-navy-400">Policy #</span>
                    <span className="font-mono text-2xs text-navy-600">{policy.policy_number}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-navy-400">Premium Paid</span>
                    <span className="font-semibold text-navy-900">TZS {fmt(policy.premium_paid)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-navy-400">Coverage Period</span>
                    <span className="text-2xs text-navy-600">
                      {new Date(policy.coverage_start).toLocaleDateString()} - {new Date(policy.coverage_end).toLocaleDateString()}
                    </span>
                  </div>
                  <p className="text-2xs text-navy-300">
                    Created {new Date(policy.created_at).toLocaleDateString()}
                  </p>
                </div>

                {policy.status === 'active' && (
                  <div className="pt-3 border-t border-gray-100 mt-3">
                    <button
                      onClick={() => handleCancel(policy.id)}
                      className="w-full flex items-center justify-center gap-1.5 py-2.5 text-sm font-semibold rounded-2xl bg-red-50 text-red-700 hover:bg-red-100 transition-all active:scale-[0.98]"
                    >
                      <XCircle className="w-4 h-4" /> Cancel Policy
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )
      )}

      {/* Subscribe Modal */}
      {subscribeModal && (
        <div className="fixed inset-0 bg-navy-950/50 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setSubscribeModal(null)}>
          <div className="bg-white rounded-3xl shadow-xl w-full max-w-md max-h-[90vh] overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center">
                <ShieldCheck className="w-5 h-5 text-blue-600" />
              </div>
              <h2 className="text-lg font-bold text-navy-900">Subscribe to {subscribeModal.name}</h2>
            </div>

            <div className="bg-navy-50 rounded-2xl p-3.5 mb-6 mt-4">
              <div className="flex justify-between text-sm">
                <div>
                  <p className="text-2xs text-navy-400">Premium</p>
                  <p className="font-bold text-navy-900">TZS {fmt(subscribeModal.premium_amount)}/{subscribeModal.premium_frequency}</p>
                </div>
                <div className="text-right">
                  <p className="text-2xs text-navy-400">Coverage</p>
                  <p className="font-bold text-navy-900">TZS {fmt(subscribeModal.coverage_amount)}</p>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-navy-700 mb-1.5">Beneficiary Name *</label>
                <input
                  type="text"
                  value={beneficiaryName}
                  onChange={(e) => setBeneficiaryName(e.target.value)}
                  className="input-field"
                  placeholder="Full name of beneficiary"
                  autoFocus
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-navy-700 mb-1.5">Beneficiary Phone *</label>
                <input
                  type="tel"
                  value={beneficiaryPhone}
                  onChange={(e) => setBeneficiaryPhone(e.target.value)}
                  className="input-field"
                  placeholder="e.g. +255 7XX XXX XXX"
                />
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button onClick={() => setSubscribeModal(null)} className="flex-1 btn-secondary">
                Cancel
              </button>
              <button
                onClick={handleSubscribe}
                disabled={submitting}
                className="flex-1 btn-primary"
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
