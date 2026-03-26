import { useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import api from '../api/client'
import { showError, showLoadError } from '../utils/error'

interface Summary {
  total_completed: number; total_reconciled: number; total_unreconciled: number;
  amount_completed: number; amount_reconciled: number; amount_unreconciled: number
}

interface TxnRow {
  id: string; user_id: string; phone: string; type: string; amount: number;
  fee: number; reference: string; gateway_ref?: string; created_at: string; completed_at?: string
}

export default function Reconciliation() {
  const [summary, setSummary] = useState<Summary | null>(null)
  const [txns, setTxns] = useState<TxnRow[]>([])
  const [page, setPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [loading, setLoading] = useState(true)
  const [reconId, setReconId] = useState<string | null>(null)
  const [settlementRef, setSettlementRef] = useState('')
  const [notes, setNotes] = useState('')

  const loadData = () => {
    setLoading(true)
    Promise.all([
      api.get('/reconciliation/summary'),
      api.get('/transactions/unreconciled', { params: { page } }),
    ]).then(([sumRes, txnRes]) => {
      setSummary(sumRes.data)
      setTxns(txnRes.data.transactions)
      setTotalPages(txnRes.data.total_pages)
    }).catch((err: unknown) => showLoadError(err, 'reconciliation data')).finally(() => setLoading(false))
  }

  useEffect(() => { loadData() }, [page])

  const reconcile = async (txnId: string) => {
    if (!settlementRef) { toast.error('Enter settlement reference'); return }
    try {
      await api.post(`/transactions/${txnId}/reconcile`, { settlement_ref: settlementRef, notes })
      toast.success('Transaction reconciled')
      setReconId(null); setSettlementRef(''); setNotes('')
      loadData()
    } catch (err: unknown) { showError(err, 'Failed to reconcile transaction') }
  }

  const fmt = (n: number) => new Intl.NumberFormat('en-TZ').format(n)

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Reconciliation</h1>

      {/* Summary */}
      {summary && (
        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="card">
            <p className="text-sm text-gray-500">Total Completed</p>
            <p className="text-xl font-bold">{summary.total_completed}</p>
            <p className="text-sm text-gray-400">TZS {fmt(summary.amount_completed)}</p>
          </div>
          <div className="card border-green-200 bg-green-50">
            <p className="text-sm text-green-600">Reconciled</p>
            <p className="text-xl font-bold text-green-700">{summary.total_reconciled}</p>
            <p className="text-sm text-green-500">TZS {fmt(summary.amount_reconciled)}</p>
          </div>
          <div className="card border-amber-200 bg-amber-50">
            <p className="text-sm text-amber-600">Unreconciled</p>
            <p className="text-xl font-bold text-amber-700">{summary.total_unreconciled}</p>
            <p className="text-sm text-amber-500">TZS {fmt(summary.amount_unreconciled)}</p>
          </div>
        </div>
      )}

      {/* Unreconciled Transactions */}
      <div className="card p-0 overflow-hidden">
        <div className="px-4 py-3 bg-gray-50 border-b">
          <h2 className="font-semibold">Unreconciled Transactions</h2>
        </div>
        {loading ? (
          <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
        ) : txns.length === 0 ? (
          <p className="text-center text-gray-500 py-12">All transactions are reconciled</p>
        ) : (
          <table className="w-full text-sm">
            <thead className="border-b">
              <tr>
                <th className="text-left px-4 py-2 text-gray-500 font-medium">Reference</th>
                <th className="text-left px-4 py-2 text-gray-500 font-medium">Phone</th>
                <th className="text-left px-4 py-2 text-gray-500 font-medium">Type</th>
                <th className="text-left px-4 py-2 text-gray-500 font-medium">Amount</th>
                <th className="text-left px-4 py-2 text-gray-500 font-medium">Gateway Ref</th>
                <th className="text-left px-4 py-2 text-gray-500 font-medium">Completed</th>
                <th className="px-4 py-2"></th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {txns.map((t) => (
                <tr key={t.id} className="hover:bg-gray-50">
                  <td className="px-4 py-2 font-mono text-xs">{t.reference}</td>
                  <td className="px-4 py-2">{t.phone}</td>
                  <td className="px-4 py-2 capitalize">{t.type}</td>
                  <td className="px-4 py-2 font-medium">TZS {t.amount.toLocaleString()}</td>
                  <td className="px-4 py-2 font-mono text-xs">{t.gateway_ref || '-'}</td>
                  <td className="px-4 py-2">{t.completed_at ? new Date(t.completed_at).toLocaleDateString() : '-'}</td>
                  <td className="px-4 py-2">
                    {reconId === t.id ? (
                      <div className="flex gap-2 items-end">
                        <input value={settlementRef} onChange={(e) => setSettlementRef(e.target.value)} className="input-field w-32 text-xs" placeholder="Settlement ref" />
                        <input value={notes} onChange={(e) => setNotes(e.target.value)} className="input-field w-24 text-xs" placeholder="Notes" />
                        <button onClick={() => reconcile(t.id)} className="btn-primary text-xs py-1 px-2">Save</button>
                        <button onClick={() => setReconId(null)} className="btn-secondary text-xs py-1 px-2">Cancel</button>
                      </div>
                    ) : (
                      <button onClick={() => setReconId(t.id)} className="text-emerald-600 font-medium text-xs hover:underline">Reconcile</button>
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
          <span className="self-center text-sm text-gray-600">Page {page}/{totalPages}</span>
          <button onClick={() => setPage(Math.min(totalPages, page + 1))} disabled={page === totalPages} className="btn-secondary">Next</button>
        </div>
      )}
    </div>
  )
}
