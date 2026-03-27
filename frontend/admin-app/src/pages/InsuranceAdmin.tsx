import { useEffect, useState } from 'react'
import api from '../api/client'
import { showLoadError } from '../utils/error'

interface PolicyRow {
  id: string
  policy_number: string
  user_id: string
  phone: string
  product_name: string
  status: string
  coverage_start: string
  coverage_end: string
  premium_amount: number
  premium_paid: boolean
  created_at: string
}

export default function InsuranceAdmin() {
  const [policies, setPolicies] = useState<PolicyRow[]>([])
  const [page, setPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [filterStatus, setFilterStatus] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    api.get('/insurance/policies', { params: { page, status: filterStatus || undefined } })
      .then((res) => {
        setPolicies(res.data.policies || [])
        setTotalPages(res.data.total_pages || 1)
      })
      .catch((err: unknown) => showLoadError(err, 'insurance policies'))
      .finally(() => setLoading(false))
  }, [page, filterStatus])

  const statusColor = (s: string) => {
    switch (s) {
      case 'active': return 'bg-green-100 text-green-700'
      case 'expired': return 'bg-gray-100 text-gray-700'
      case 'claimed': return 'bg-blue-100 text-blue-700'
      case 'cancelled': return 'bg-red-100 text-red-700'
      default: return 'bg-amber-100 text-amber-700'
    }
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Insurance Monitor</h1>

      <div className="flex gap-3 mb-4">
        <select value={filterStatus} onChange={(e) => { setFilterStatus(e.target.value); setPage(1) }} className="input-field w-auto">
          <option value="">All Status</option>
          <option value="pending">Pending</option>
          <option value="active">Active</option>
          <option value="expired">Expired</option>
          <option value="claimed">Claimed</option>
          <option value="cancelled">Cancelled</option>
        </select>
      </div>

      <div className="card p-0 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Policy #</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Phone</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Product</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Coverage</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Premium</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Paid</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Created</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {policies.length === 0 ? (
                <tr><td colSpan={8} className="px-4 py-8 text-center text-gray-400">No insurance policies found</td></tr>
              ) : policies.map((p) => (
                <tr key={p.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-mono text-xs">{p.policy_number}</td>
                  <td className="px-4 py-3">{p.phone}</td>
                  <td className="px-4 py-3">{p.product_name}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusColor(p.status)}`}>{p.status}</span>
                  </td>
                  <td className="px-4 py-3 text-xs">
                    {new Date(p.coverage_start).toLocaleDateString()} - {new Date(p.coverage_end).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 font-medium">TZS {p.premium_amount.toLocaleString()}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${p.premium_paid ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                      {p.premium_paid ? 'Yes' : 'No'}
                    </span>
                  </td>
                  <td className="px-4 py-3">{new Date(p.created_at).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {totalPages > 1 && (
        <div className="flex justify-center gap-4 mt-4">
          <button onClick={() => setPage(Math.max(1, page - 1))} disabled={page === 1} className="btn-secondary">Prev</button>
          <span className="self-center text-sm text-gray-600">Page {page} / {totalPages}</span>
          <button onClick={() => setPage(Math.min(totalPages, page + 1))} disabled={page === totalPages} className="btn-secondary">Next</button>
        </div>
      )}
    </div>
  )
}
