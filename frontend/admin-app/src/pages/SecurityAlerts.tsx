import { useEffect, useState } from 'react'
import { AlertTriangle, Lock, DollarSign, XCircle } from 'lucide-react'
import api from '../api/client'
import { showLoadError } from '../utils/error'

interface Alert {
  alert_type: string; entity_id: string; description: string;
  detail: string; created_at: string
}

const alertConfig: Record<string, { icon: typeof AlertTriangle; color: string; label: string }> = {
  locked_account: { icon: Lock, color: 'bg-red-100 text-red-600', label: 'Locked Account' },
  high_value_txn: { icon: DollarSign, color: 'bg-amber-100 text-amber-600', label: 'High Value Transaction' },
  failed_transaction: { icon: XCircle, color: 'bg-orange-100 text-orange-600', label: 'Failed Transaction' },
}

export default function SecurityAlerts() {
  const [alerts, setAlerts] = useState<Alert[]>([])
  const [page, setPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    api.get('/security-alerts', { params: { page } })
      .then((res) => {
        setAlerts(res.data.alerts)
        setTotalPages(res.data.total_pages || 1)
      })
      .catch((err: unknown) => showLoadError(err, 'security alerts'))
      .finally(() => setLoading(false))
  }, [page])

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6 flex items-center gap-2">
        <AlertTriangle className="w-6 h-6 text-amber-500" /> Security Alerts
      </h1>

      {loading ? (
        <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
      ) : alerts.length === 0 ? (
        <div className="card text-center py-12 text-gray-500">No security alerts in the last 24 hours</div>
      ) : (
        <div className="space-y-3">
          {alerts.map((alert, i) => {
            const cfg = alertConfig[alert.alert_type] || { icon: AlertTriangle, color: 'bg-gray-100 text-gray-600', label: alert.alert_type }
            const Icon = cfg.icon
            return (
              <div key={i} className="card flex items-start gap-4">
                <div className={`w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0 ${cfg.color}`}>
                  <Icon className="w-5 h-5" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${cfg.color}`}>{cfg.label}</span>
                    <span className="text-xs text-gray-400">{new Date(alert.created_at).toLocaleString()}</span>
                  </div>
                  <p className="text-sm font-medium mt-1">{alert.detail}</p>
                  <p className="text-xs text-gray-500 mt-0.5 font-mono">{alert.description} ({alert.entity_id.slice(0, 8)}...)</p>
                </div>
              </div>
            )
          })}
        </div>
      )}

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
