import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import toast from 'react-hot-toast'
import api from '../api/client'

interface UserDetail {
  user: {
    id: string; phone: string; email?: string; full_name: string;
    kyc_status: string; kyc_tier: number; status: string; created_at: string
  }
  available_balance: number
  locked_balance: number
}

export default function UserDetail() {
  const { id } = useParams<{ id: string }>()
  const [detail, setDetail] = useState<UserDetail | null>(null)
  const [docId, setDocId] = useState('')
  const [newTier, setNewTier] = useState(1)
  const [rejectReason, setRejectReason] = useState('')

  useEffect(() => {
    if (id) api.get(`/users/${id}`).then((res) => setDetail(res.data)).catch(console.error)
  }, [id])

  const approveKYC = async () => {
    if (!docId) { toast.error('Enter document ID'); return }
    try {
      await api.post(`/users/${id}/kyc/approve`, { document_id: docId, new_tier: newTier })
      toast.success('KYC approved')
      api.get(`/users/${id}`).then((res) => setDetail(res.data))
    } catch (err: any) {
      toast.error(err.response?.data?.error || 'Failed')
    }
  }

  const rejectKYC = async () => {
    if (!docId || !rejectReason) { toast.error('Enter document ID and reason'); return }
    try {
      await api.post(`/users/${id}/kyc/reject`, { document_id: docId, reason: rejectReason })
      toast.success('KYC rejected')
      api.get(`/users/${id}`).then((res) => setDetail(res.data))
    } catch (err: any) {
      toast.error(err.response?.data?.error || 'Failed')
    }
  }

  if (!detail) return <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>

  const { user } = detail

  return (
    <div className="max-w-2xl space-y-6">
      <h1 className="text-2xl font-bold">User Detail</h1>

      <div className="card">
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div><p className="text-gray-500">Name</p><p className="font-medium">{user.full_name}</p></div>
          <div><p className="text-gray-500">Phone</p><p className="font-medium">{user.phone}</p></div>
          <div><p className="text-gray-500">Email</p><p className="font-medium">{user.email || '-'}</p></div>
          <div><p className="text-gray-500">Status</p><p className="font-medium capitalize">{user.status}</p></div>
          <div><p className="text-gray-500">KYC Status</p><p className="font-medium capitalize">{user.kyc_status}</p></div>
          <div><p className="text-gray-500">KYC Tier</p><p className="font-medium">{user.kyc_tier}</p></div>
          <div><p className="text-gray-500">Available Balance</p><p className="font-medium">TZS {detail.available_balance.toLocaleString()}</p></div>
          <div><p className="text-gray-500">Locked Balance</p><p className="font-medium">TZS {detail.locked_balance.toLocaleString()}</p></div>
          <div><p className="text-gray-500">Joined</p><p className="font-medium">{new Date(user.created_at).toLocaleString()}</p></div>
        </div>
      </div>

      {/* KYC Actions */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-4">KYC Actions</h2>
        <div className="space-y-3">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Document ID</label>
            <input value={docId} onChange={(e) => setDocId(e.target.value)} className="input-field" placeholder="UUID of the KYC document" />
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="block text-sm font-medium text-gray-700 mb-1">New Tier (for approval)</label>
              <select value={newTier} onChange={(e) => setNewTier(Number(e.target.value))} className="input-field">
                <option value={1}>Tier 1 - Basic</option>
                <option value={2}>Tier 2 - Enhanced</option>
                <option value={3}>Tier 3 - Premium</option>
              </select>
            </div>
            <button onClick={approveKYC} className="btn-primary self-end">Approve KYC</button>
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="block text-sm font-medium text-gray-700 mb-1">Rejection Reason</label>
              <input value={rejectReason} onChange={(e) => setRejectReason(e.target.value)} className="input-field" placeholder="Reason for rejection" />
            </div>
            <button onClick={rejectKYC} className="btn-danger self-end">Reject KYC</button>
          </div>
        </div>
      </div>
    </div>
  )
}
