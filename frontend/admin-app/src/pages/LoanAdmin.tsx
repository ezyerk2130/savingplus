import { useEffect, useState } from 'react'
import api from '../api/client'
import { showLoadError, showError } from '../utils/error'
import toast from 'react-hot-toast'

interface LoanRow {
  id: string; user_id: string; phone: string; type: string; status: string;
  amount: number; fee: number; reference: string; created_at: string
}

export default function LoanAdmin() {
  const [loans, setLoans] = useState<LoanRow[]>([])
  const [page, setPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [filterStatus, setFilterStatus] = useState('')
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  const fetchLoans = () => {
    setLoading(true)
    api.get('/transactions', { params: { page, status: filterStatus || undefined, type: 'loan_disbursement' } })
      .then((res) => {
        setLoans(res.data.transactions)
        setTotalPages(res.data.total_pages)
      })
      .catch((err: unknown) => showLoadError(err, 'loans'))
      .finally(() => setLoading(false))
  }

  useEffect(() => { fetchLoans() }, [page, filterStatus])

  const handleAction = (loanId: string, action: 'approve' | 'reject') => {
    setActionLoading(loanId)
    api.post(`/loans/${loanId}/${action}`)
      .then(() => {
        toast.success(`Loan ${action}d successfully`)
        fetchLoans()
      })
      .catch((err: unknown) => showError(err, `Failed to ${action} loan`))
      .finally(() => setActionLoading(null))
  }

  const statusColor = (s: string) => {
    switch (s) {
      case 'completed': return 'bg-green-100 text-green-700'
      case 'disbursed': return 'bg-blue-100 text-blue-700'
      case 'failed': return 'bg-red-100 text-red-700'
      case 'rejected': return 'bg-red-100 text-red-700'
      default: return 'bg-amber-100 text-amber-700'
    }
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Loan Management</h1>

      <div className="flex gap-3 mb-4">
        <select value={filterStatus} onChange={(e) => { setFilterStatus(e.target.value); setPage(1) }} className="input-field w-auto">
          <option value="">All Status</option>
          <option value="pending">Pending Approval</option>
          <option value="completed">Disbursed</option>
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
                <th className="text-left px-4 py-3 font-medium text-gray-500">Loan Ref</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Phone</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Principal</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Fee</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Date</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {loans.length === 0 ? (
                <tr><td colSpan={7} className="px-4 py-8 text-center text-gray-400">No loan transactions found</td></tr>
              ) : loans.map((loan) => (
                <tr key={loan.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-mono text-xs">{loan.reference}</td>
                  <td className="px-4 py-3">{loan.phone}</td>
                  <td className="px-4 py-3 font-medium">TZS {loan.amount.toLocaleString()}</td>
                  <td className="px-4 py-3">TZS {loan.fee.toLocaleString()}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusColor(loan.status)}`}>{loan.status}</span>
                  </td>
                  <td className="px-4 py-3">{new Date(loan.created_at).toLocaleString()}</td>
                  <td className="px-4 py-3">
                    {loan.status === 'pending' ? (
                      <div className="flex gap-2">
                        <button
                          onClick={() => handleAction(loan.id, 'approve')}
                          disabled={actionLoading === loan.id}
                          className="text-xs px-2 py-1 rounded bg-green-600 text-white hover:bg-green-700 disabled:opacity-50"
                        >
                          Approve
                        </button>
                        <button
                          onClick={() => handleAction(loan.id, 'reject')}
                          disabled={actionLoading === loan.id}
                          className="text-xs px-2 py-1 rounded bg-red-600 text-white hover:bg-red-700 disabled:opacity-50"
                        >
                          Reject
                        </button>
                      </div>
                    ) : (
                      <span className="text-xs text-gray-400">--</span>
                    )}
                  </td>
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
