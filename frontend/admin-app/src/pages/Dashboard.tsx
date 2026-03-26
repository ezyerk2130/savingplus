import { useEffect, useState } from 'react'
import { Users, Receipt, Clock, Shield } from 'lucide-react'
import api from '../api/client'

interface HealthData {
  total_users: number
  total_transactions: number
  pending_transactions: number
  pending_kyc: number
}

export default function Dashboard() {
  const [health, setHealth] = useState<HealthData | null>(null)

  useEffect(() => {
    api.get('/health').then((res) => setHealth(res.data)).catch(console.error)
  }, [])

  const stats = health ? [
    { label: 'Total Users', value: health.total_users, icon: Users, color: 'bg-blue-50 text-blue-600' },
    { label: 'Total Transactions', value: health.total_transactions, icon: Receipt, color: 'bg-green-50 text-green-600' },
    { label: 'Pending Transactions', value: health.pending_transactions, icon: Clock, color: 'bg-amber-50 text-amber-600' },
    { label: 'Pending KYC', value: health.pending_kyc, icon: Shield, color: 'bg-purple-50 text-purple-600' },
  ] : []

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Admin Dashboard</h1>

      {!health ? (
        <div className="flex items-center justify-center h-32">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" />
        </div>
      ) : (
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
      )}
    </div>
  )
}
