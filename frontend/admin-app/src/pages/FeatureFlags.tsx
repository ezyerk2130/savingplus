import { useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import api from '../api/client'

interface Flag {
  id: string; name: string; description?: string; enabled: boolean;
  created_at: string; updated_at: string
}

export default function FeatureFlags() {
  const [flags, setFlags] = useState<Flag[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.get('/feature-flags')
      .then((res) => setFlags(res.data.feature_flags))
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [])

  const toggle = async (id: string, enabled: boolean) => {
    try {
      await api.put(`/feature-flags/${id}`, { enabled: !enabled })
      setFlags((prev) => prev.map((f) => f.id === id ? { ...f, enabled: !enabled } : f))
      toast.success(`Flag ${!enabled ? 'enabled' : 'disabled'}`)
    } catch (err: any) {
      toast.error(err.response?.data?.error || 'Failed to toggle flag')
    }
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Feature Flags</h1>

      {loading ? (
        <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
      ) : flags.length === 0 ? (
        <div className="card text-center py-12 text-gray-500">No feature flags configured</div>
      ) : (
        <div className="card p-0 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Name</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Description</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Status</th>
                <th className="px-4 py-3 font-medium text-gray-500">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {flags.map((f) => (
                <tr key={f.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-mono font-medium">{f.name}</td>
                  <td className="px-4 py-3 text-gray-500">{f.description || '-'}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                      f.enabled ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'
                    }`}>
                      {f.enabled ? 'Enabled' : 'Disabled'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-center">
                    <button
                      onClick={() => toggle(f.id, f.enabled)}
                      className={`text-xs font-medium px-3 py-1 rounded ${
                        f.enabled ? 'bg-red-50 text-red-600 hover:bg-red-100' : 'bg-green-50 text-green-600 hover:bg-green-100'
                      }`}
                    >
                      {f.enabled ? 'Disable' : 'Enable'}
                    </button>
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
