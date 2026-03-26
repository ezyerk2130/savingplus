import { useEffect, useState } from 'react'
import api from '../api/client'

interface AuditEntry {
  id: string; actor_type: string; actor_id?: string; action: string;
  ip_address?: string; response_status?: number; created_at: string
}

export default function AuditLogs() {
  const [logs, setLogs] = useState<AuditEntry[]>([])
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    api.get('/audit-logs', { params: { page } })
      .then((res) => setLogs(res.data.audit_logs))
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [page])

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Audit Logs</h1>

      <div className="card p-0 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Action</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Actor</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">IP</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Time</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {logs.map((log) => (
                <tr key={log.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-mono text-xs">{log.action}</td>
                  <td className="px-4 py-3">
                    <span className="text-xs px-2 py-0.5 rounded bg-gray-100">{log.actor_type}</span>
                    {log.actor_id && <span className="text-xs text-gray-400 ml-1">{log.actor_id.slice(0, 8)}...</span>}
                  </td>
                  <td className="px-4 py-3 text-gray-500">{log.ip_address || '-'}</td>
                  <td className="px-4 py-3">
                    {log.response_status && (
                      <span className={`text-xs font-medium ${log.response_status < 400 ? 'text-green-600' : 'text-red-600'}`}>
                        {log.response_status}
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3">{new Date(log.created_at).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="flex justify-center gap-4 mt-4">
        <button onClick={() => setPage(Math.max(1, page - 1))} disabled={page === 1} className="btn-secondary">Prev</button>
        <span className="self-center text-sm text-gray-600">Page {page}</span>
        <button onClick={() => setPage(page + 1)} className="btn-secondary">Next</button>
      </div>
    </div>
  )
}
