import { useEffect, useState } from 'react'
import { Users, Receipt, Clock, Shield, AlertTriangle, Lock, ArrowDownToLine, ArrowUpFromLine } from 'lucide-react'
import api from '../api/client'
import { showLoadError } from '../utils/error'

interface HealthData {
  total_users: number
  total_transactions: number
  pending_transactions: number
  pending_kyc: number
  failed_txns_24h: number
  locked_accounts: number
  total_deposits: number
  total_withdrawals: number
}

export default function Dashboard() {
  const [health, setHealth] = useState<HealthData | null>(null)

  useEffect(() => {
    api.get('/health').then((res) => setHealth(res.data)).catch((err: unknown) => showLoadError(err, 'dashboard data'))
  }, [])

  if (!health) {
    return (
      <div className="flex items-center justify-center h-32">
        <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" />
      </div>
    )
  }

  const stats = [
    { label: 'Total Users', value: health.total_users, icon: Users, color: 'bg-blue-50 text-blue-600' },
    { label: 'Total Transactions', value: health.total_transactions, icon: Receipt, color: 'bg-emerald-50 text-emerald-600' },
    { label: 'Pending Transactions', value: health.pending_transactions, icon: Clock, color: 'bg-amber-50 text-amber-600' },
    { label: 'Pending KYC', value: health.pending_kyc, icon: Shield, color: 'bg-purple-50 text-purple-600' },
  ]

  const alerts = [
    { label: 'Failed (24h)', value: health.failed_txns_24h, icon: AlertTriangle, color: 'bg-red-50 text-red-600' },
    { label: 'Locked Accounts', value: health.locked_accounts, icon: Lock, color: 'bg-orange-50 text-orange-600' },
  ]

  const fmt = (n: number) => new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(n)

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Admin Dashboard</h1>

      {/* Main stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat) => (
          <div key={stat.label} className="card">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${stat.color}`}>
                <stat.icon className="w-5 h-5" />
              </div>
              <div>
                <p className="text-2xl font-bold">{stat.value.toLocaleString()}</p>
                <p className="text-sm text-gray-500">{stat.label}</p>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Alerts row */}
      {(health.failed_txns_24h > 0 || health.locked_accounts > 0) && (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {alerts.filter((a) => a.value > 0).map((alert) => (
            <div key={alert.label} className={`card border-l-4 ${alert.color.includes('red') ? 'border-l-red-500' : 'border-l-orange-500'}`}>
              <div className="flex items-center gap-3">
                <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${alert.color}`}>
                  <alert.icon className="w-5 h-5" />
                </div>
                <div>
                  <p className="text-xl font-bold">{alert.value}</p>
                  <p className="text-sm text-gray-500">{alert.label}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Financial summary */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="card">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-lg flex items-center justify-center bg-green-50 text-green-600">
              <ArrowDownToLine className="w-5 h-5" />
            </div>
            <div>
              <p className="text-sm text-gray-500">Total Deposits</p>
              <p className="text-xl font-bold">TZS {fmt(health.total_deposits)}</p>
            </div>
          </div>
        </div>
        <div className="card">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-lg flex items-center justify-center bg-red-50 text-red-600">
              <ArrowUpFromLine className="w-5 h-5" />
            </div>
            <div>
              <p className="text-sm text-gray-500">Total Withdrawals</p>
              <p className="text-xl font-bold">TZS {fmt(health.total_withdrawals)}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
