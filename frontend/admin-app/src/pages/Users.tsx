import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Search, Users as UsersIcon } from 'lucide-react'
import api from '../api/client'
import { showError, showLoadError } from '../utils/error'

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
  const [loading, setLoading] = useState(true)
  const [searched, setSearched] = useState(false)

  // Load all users on mount (search with wildcard)
  useEffect(() => {
    setLoading(true)
    api.get('/users/search', { params: { q: '%' } })
      .then((res) => setUsers(res.data.users))
      .catch((err: unknown) => showLoadError(err, 'users'))
      .finally(() => setLoading(false))
  }, [])

  const search = async () => {
    if (!query.trim()) {
      // If empty, reload all users
      setLoading(true)
      setSearched(false)
      api.get('/users/search', { params: { q: '%' } })
        .then((res) => setUsers(res.data.users))
        .catch((err: unknown) => showLoadError(err, 'users'))
        .finally(() => setLoading(false))
      return
    }
    setLoading(true)
    setSearched(true)
    try {
      const res = await api.get('/users/search', { params: { q: query } })
      setUsers(res.data.users)
    } catch (err: unknown) {
      showError(err, 'Search failed')
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

  const statusColor = (status: string) => {
    switch (status) {
      case 'active': return 'bg-green-100 text-green-700'
      case 'locked': return 'bg-red-100 text-red-700'
      case 'suspended': return 'bg-amber-100 text-amber-700'
      default: return 'bg-gray-100 text-gray-600'
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold flex items-center gap-2">
          <UsersIcon className="w-6 h-6" /> User Management
        </h1>
        <span className="text-sm text-gray-500">{users.length} user(s){searched ? ' found' : ''}</span>
      </div>

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

      <div className="card p-0 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-32">
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" />
          </div>
        ) : users.length === 0 ? (
          <p className="text-center text-gray-500 py-12">No users found</p>
        ) : (
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
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusColor(u.status)}`}>
                      {u.status}
                    </span>
                  </td>
                  <td className="px-4 py-3">{new Date(u.created_at).toLocaleDateString()}</td>
                  <td className="px-4 py-3">
                    <Link to={`/users/${u.id}`} className="text-emerald-600 font-medium hover:underline">View</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
