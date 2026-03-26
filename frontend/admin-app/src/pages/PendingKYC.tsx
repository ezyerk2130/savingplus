import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import api from '../api/client'
import { showLoadError } from '../utils/error'

interface KYCRow {
  id: string; user_id: string; phone: string; full_name: string;
  document_type: string; status: string; created_at: string
}

export default function PendingKYC() {
  const [docs, setDocs] = useState<KYCRow[]>([])
  const [page, setPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    api.get('/kyc/pending', { params: { page } })
      .then((res) => { setDocs(res.data.documents); setTotalPages(res.data.total_pages); setTotal(res.data.total) })
      .catch((err: unknown) => showLoadError(err, 'pending KYC documents'))
      .finally(() => setLoading(false))
  }, [page])

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Pending KYC Queue</h1>
        <span className="text-sm text-gray-500">{total} document(s) pending review</span>
      </div>

      <div className="card p-0 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
        ) : docs.length === 0 ? (
          <p className="text-center text-gray-500 py-12">No pending KYC documents</p>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-500">User</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Phone</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Document Type</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Doc ID</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Submitted</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {docs.map((d) => (
                <tr key={d.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium">{d.full_name}</td>
                  <td className="px-4 py-3">{d.phone}</td>
                  <td className="px-4 py-3 capitalize">{d.document_type.replace('_', ' ')}</td>
                  <td className="px-4 py-3 font-mono text-xs">{d.id.slice(0, 8)}...</td>
                  <td className="px-4 py-3">{new Date(d.created_at).toLocaleDateString()}</td>
                  <td className="px-4 py-3">
                    <Link to={`/users/${d.user_id}`} className="text-emerald-600 font-medium hover:underline">Review</Link>
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
