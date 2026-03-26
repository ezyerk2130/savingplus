import { useEffect, useState } from 'react'
import { ArrowDownToLine, ArrowUpFromLine, ChevronLeft, ChevronRight, Lock, Unlock } from 'lucide-react'
import { transactionApi } from '../api/services'
import { showLoadError } from '../utils/error'
import type { Transaction } from '../types'

export default function Transactions() {
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const [page, setPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [filterType, setFilterType] = useState('')
  const [filterStatus, setFilterStatus] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)

  const loadTransactions = async () => {
    setLoading(true)
    setError(false)
    try {
      const res = await transactionApi.list({
        page, page_size: 20,
        type: filterType || undefined,
        status: filterStatus || undefined,
      })
      setTransactions(res.data.transactions)
      setTotalPages(res.data.total_pages)
    } catch (err: unknown) {
      showLoadError(err, 'transactions')
      setError(true)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadTransactions()
  }, [page, filterType, filterStatus])

  const formatAmount = (amount: string) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(parseFloat(amount))

  const statusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'bg-green-100 text-green-700'
      case 'failed': return 'bg-red-100 text-red-700'
      case 'reversed': return 'bg-gray-100 text-gray-700'
      default: return 'bg-amber-100 text-amber-700'
    }
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Transaction History</h1>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <select value={filterType} onChange={(e) => { setFilterType(e.target.value); setPage(1) }} className="input-field w-auto">
          <option value="">All Types</option>
          <option value="deposit">Deposits</option>
          <option value="withdrawal">Withdrawals</option>
          <option value="savings_lock">Savings Lock</option>
          <option value="savings_unlock">Savings Unlock</option>
          <option value="interest">Interest</option>
        </select>
        <select value={filterStatus} onChange={(e) => { setFilterStatus(e.target.value); setPage(1) }} className="input-field w-auto">
          <option value="">All Status</option>
          <option value="completed">Completed</option>
          <option value="pending">Pending</option>
          <option value="failed">Failed</option>
        </select>
      </div>

      {/* List */}
      <div className="card p-0 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" /></div>
        ) : error ? (
          <div className="flex flex-col items-center justify-center py-12 space-y-3">
            <p className="text-gray-600">Failed to load transactions</p>
            <button onClick={loadTransactions} className="btn-primary text-sm">Retry</button>
          </div>
        ) : transactions.length === 0 ? (
          <p className="text-gray-500 text-sm text-center py-12">No transactions found</p>
        ) : (
          <div className="divide-y divide-gray-100">
            {transactions.map((txn) => {
              const isIncoming = txn.type === 'deposit' || txn.type === 'savings_unlock' || txn.type === 'interest'
              const isSavings = txn.type === 'savings_lock' || txn.type === 'savings_unlock'
              return (
              <div key={txn.id} className="flex items-center justify-between p-4 hover:bg-gray-50">
                <div className="flex items-center gap-3">
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                    isSavings ? 'bg-purple-100' : isIncoming ? 'bg-green-100' : 'bg-red-100'
                  }`}>
                    {txn.type === 'savings_lock' ? <Lock className="w-5 h-5 text-purple-600" /> :
                     txn.type === 'savings_unlock' ? <Unlock className="w-5 h-5 text-purple-600" /> :
                     isIncoming ? <ArrowDownToLine className="w-5 h-5 text-green-600" /> :
                     <ArrowUpFromLine className="w-5 h-5 text-red-600" />}
                  </div>
                  <div>
                    <p className="text-sm font-medium capitalize">{txn.type.replace(/_/g, ' ')}</p>
                    <p className="text-xs text-gray-500">{new Date(txn.created_at).toLocaleString()}</p>
                    <p className="text-xs text-gray-400">{txn.reference}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className={`text-sm font-semibold ${
                    isSavings ? 'text-purple-600' : isIncoming ? 'text-green-600' : 'text-red-600'
                  }`}>
                    {isIncoming ? '+' : '-'}TZS {formatAmount(txn.amount)}
                  </p>
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusColor(txn.status)}`}>
                    {txn.status}
                  </span>
                </div>
              </div>
              )
            })}
          </div>
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-4">
          <button onClick={() => setPage(Math.max(1, page - 1))} disabled={page === 1} className="btn-secondary flex items-center gap-1">
            <ChevronLeft className="w-4 h-4" /> Prev
          </button>
          <span className="text-sm text-gray-600">Page {page} of {totalPages}</span>
          <button onClick={() => setPage(Math.min(totalPages, page + 1))} disabled={page === totalPages} className="btn-secondary flex items-center gap-1">
            Next <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      )}
    </div>
  )
}
