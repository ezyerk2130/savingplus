import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Search } from 'lucide-react'
import toast from 'react-hot-toast'
import api from '../api/client'

interface UserResult {
  id: string
  phone: string
  email?: string
  full_name: string
  kyc_status: string
  kyc_tier: number
  status: string
  created_at: string
}

export default function Users() {
  const [query, setQuery] = useState('')
  const [users, setUsers] = useState<UserResult[]>([])
  const [loading, setLoading] = useState(false)

  const search = async () => {
    if (!query.trim()) return
    setLoading(true)
    try {
      const res = await api.get('/users/search', { params: { q: query } })
      setUsers(res.data.users)
    } catch (err: any) {
      toast.error(err.response?.data?.error || 'Search failed')
    } finally {
      setLoading(false)
    }
  }

  const kycColor = (status: string) => {
    switch (status) {
      case 'approved': return 'bg-green-100 text-green-700'
      case 'rejected': return 'bg-red-100 text-red-700'
      case 'submitted': case 'under_review': return 'bg-amber-100 text-amber-700'
      default: return 'bg-gray-100 text-gray-600'
    }
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">User Management</h1>

      <div className="flex gap-3 mb-6">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-2.5 w-4 h-4 text-gray-400" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && search()}
            className="input-field pl-9"
            placeholder="Search by name, phone, or email..."
          />
        </div>
        <button onClick={search} disabled={loading} className="btn-primary">
          {loading ? 'Searching...' : 'Search'}
        </button>
      </div>

      {users.length > 0 && (
        <div className="card p-0 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Name</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Phone</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">KYC</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Tier</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Joined</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {users.map((u) => (
                <tr key={u.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium">{u.full_name}</td>
                  <td className="px-4 py-3">{u.phone}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${kycColor(u.kyc_status)}`}>
                      {u.kyc_status}
                    </span>
                  </td>
                  <td className="px-4 py-3">{u.kyc_tier}</td>
                  <td className="px-4 py-3 capitalize">{u.status}</td>
                  <td className="px-4 py-3">{new Date(u.created_at).toLocaleDateString()}</td>
                  <td className="px-4 py-3">
                    <Link to={`/users/${u.id}`} className="text-emerald-600 font-medium hover:underline">View</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
