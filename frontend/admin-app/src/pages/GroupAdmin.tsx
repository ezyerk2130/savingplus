import { useEffect, useState } from 'react'
import api from '../api/client'
import { showLoadError } from '../utils/error'

interface GroupRow {
  id: string
  name: string
  type: string
  member_count: number
  contribution_amount: number
  frequency: string
  status: string
  total_rounds: number
  current_round: number
  created_at: string
}

export default function GroupAdmin() {
  const [groups, setGroups] = useState<GroupRow[]>([])
  const [page, setPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [filterStatus, setFilterStatus] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    api.get('/groups', { params: { page, status: filterStatus || undefined } })
      .then((res) => {
        setGroups(res.data.groups || [])
        setTotalPages(res.data.total_pages || 1)
      })
      .catch((err: unknown) => showLoadError(err, 'savings groups'))
      .finally(() => setLoading(false))
  }, [page, filterStatus])

  const statusColor = (s: string) => {
    switch (s) {
      case 'active': return 'bg-green-100 text-green-700'
      case 'completed': return 'bg-blue-100 text-blue-700'
      case 'disbanded': return 'bg-red-100 text-red-700'
      default: return 'bg-amber-100 text-amber-700'
    }
  }

  const typeColor = (t: string) => {
    switch (t) {
      case 'rotating': return 'bg-purple-100 text-purple-700'
      case 'fixed': return 'bg-indigo-100 text-indigo-700'
      default: return 'bg-gray-100 text-gray-700'
    }
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Group Monitor</h1>

      <div className="flex gap-3 mb-4">
        <select value={filterStatus} onChange={(e) => { setFilterStatus(e.target.value); setPage(1) }} className="input-field w-auto">
          <option value="">All Status</option>
          <option value="forming">Forming</option>
          <option value="active">Active</option>
          <option value="completed">Completed</option>
          <option value="disbanded">Disbanded</option>
        </select>
      </div>

      <div className="card p-0 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Name</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Type</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Members</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Contribution</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Frequency</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Round</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Created</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {groups.length === 0 ? (
                <tr><td colSpan={8} className="px-4 py-8 text-center text-gray-400">No savings groups found</td></tr>
              ) : groups.map((g) => (
                <tr key={g.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium">{g.name}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${typeColor(g.type)}`}>{g.type}</span>
                  </td>
                  <td className="px-4 py-3">{g.member_count}</td>
                  <td className="px-4 py-3 font-medium">TZS {g.contribution_amount.toLocaleString()}</td>
                  <td className="px-4 py-3 capitalize">{g.frequency}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusColor(g.status)}`}>{g.status}</span>
                  </td>
                  <td className="px-4 py-3">{g.current_round} / {g.total_rounds}</td>
                  <td className="px-4 py-3">{new Date(g.created_at).toLocaleString()}</td>
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
