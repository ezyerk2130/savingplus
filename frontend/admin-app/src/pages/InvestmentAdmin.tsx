import { useEffect, useState } from 'react'
import api from '../api/client'
import { showLoadError } from '../utils/error'

interface InvestmentRow {
  id: string; user_id: string; phone: string; type: string; status: string;
  amount: number; fee: number; reference: string; created_at: string
}

export default function InvestmentAdmin() {
  const [investments, setInvestments] = useState<InvestmentRow[]>([])
  const [page, setPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [filterStatus, setFilterStatus] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    api.get('/transactions', { params: { page, status: filterStatus || undefined, type: 'investment' } })
      .then((res) => {
        setInvestments(res.data.transactions)
        setTotalPages(res.data.total_pages)
      })
      .catch((err: unknown) => showLoadError(err, 'investments'))
      .finally(() => setLoading(false))
  }, [page, filterStatus])

  const statusColor = (s: string) => {
    switch (s) {
      case 'completed': return 'bg-green-100 text-green-700'
      case 'matured': return 'bg-blue-100 text-blue-700'
      case 'failed': return 'bg-red-100 text-red-700'
      default: return 'bg-amber-100 text-amber-700'
    }
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Investment Monitor</h1>

      <div className="flex gap-3 mb-4">
        <select value={filterStatus} onChange={(e) => { setFilterStatus(e.target.value); setPage(1) }} className="input-field w-auto">
          <option value="">All Status</option>
          <option value="pending">Pending</option>
          <option value="completed">Active</option>
          <option value="matured">Matured</option>
          <option value="failed">Failed</option>
        </select>
      </div>

      <div className="card p-0 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Reference</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Phone</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Product</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Amount</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Created</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {investments.length === 0 ? (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-400">No investment transactions found</td></tr>
              ) : investments.map((inv) => (
                <tr key={inv.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-mono text-xs">{inv.reference}</td>
                  <td className="px-4 py-3">{inv.phone}</td>
                  <td className="px-4 py-3 capitalize">{inv.type}</td>
                  <td className="px-4 py-3 font-medium">TZS {inv.amount.toLocaleString()}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusColor(inv.status)}`}>{inv.status}</span>
                  </td>
                  <td className="px-4 py-3">{new Date(inv.created_at).toLocaleString()}</td>
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
