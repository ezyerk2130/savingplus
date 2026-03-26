import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import toast from 'react-hot-toast'
import { Lock, Unlock, KeyRound, Receipt, FileCheck, XCircle, CheckCircle, Clock } from 'lucide-react'
import api from '../api/client'
import { showError, showLoadError } from '../utils/error'

interface UserDetailData {
  user: {
    id: string; phone: string; email?: string; full_name: string;
    kyc_status: string; kyc_tier: number; status: string; created_at: string
  }
  available_balance: number
  locked_balance: number
}

interface KYCDoc {
  id: string; user_id: string; phone: string; full_name: string;
  document_type: string; status: string; created_at: string
}

interface TxnRow {
  id: string; type: string; status: string; amount: number; fee: number;
  currency: string; reference: string; created_at: string; completed_at?: string
}

export default function UserDetail() {
  const { id } = useParams<{ id: string }>()
  const [detail, setDetail] = useState<UserDetailData | null>(null)
  const [txns, setTxns] = useState<TxnRow[]>([])
  const [txnPage, setTxnPage] = useState(1)
  const [txnTotalPages, setTxnTotalPages] = useState(1)

  // KYC documents loaded from backend
  const [kycDocs, setKycDocs] = useState<KYCDoc[]>([])
  const [newTier, setNewTier] = useState(1)
  const [rejectReason, setRejectReason] = useState('')

  // PIN reset
  const [newPin, setNewPin] = useState('')

  // Suspend
  const [suspendReason, setSuspendReason] = useState('')

  const loadUser = () => {
    if (id) api.get(`/users/${id}`).then((res) => setDetail(res.data)).catch((err: unknown) => showLoadError(err, 'user details'))
  }

  const loadTxns = () => {
    if (id) api.get(`/users/${id}/transactions`, { params: { page: txnPage } })
      .then((res) => {
        setTxns(res.data.transactions)
        setTxnTotalPages(res.data.total_pages)
      }).catch((err: unknown) => showLoadError(err, 'user transactions'))
  }

  const loadKycDocs = () => {
    if (id) {
      api.get(`/users/${id}/kyc`)
        .then((res) => {
          setKycDocs(res.data.documents || [])
        }).catch((err: unknown) => showLoadError(err, 'KYC documents'))
    }
  }

  useEffect(() => { loadUser(); loadKycDocs() }, [id])
  useEffect(() => { loadTxns() }, [id, txnPage])

  const approveKYC = async (docId: string) => {
    try {
      await api.post(`/users/${id}/kyc/approve`, { document_id: docId, new_tier: newTier })
      toast.success('KYC approved')
      loadUser()
      loadKycDocs()
    } catch (err: unknown) { showError(err, 'Failed to approve KYC') }
  }

  const rejectKYC = async (docId: string) => {
    if (!rejectReason) { toast.error('Enter a rejection reason'); return }
    try {
      await api.post(`/users/${id}/kyc/reject`, { document_id: docId, reason: rejectReason })
      toast.success('KYC rejected')
      setRejectReason('')
      loadUser()
      loadKycDocs()
    } catch (err: unknown) { showError(err, 'Failed to reject KYC') }
  }

  const unlockAccount = async () => {
    try {
      await api.post(`/users/${id}/unlock`)
      toast.success('Account unlocked')
      loadUser()
    } catch (err: unknown) { showError(err, 'Failed to unlock account') }
  }

  const suspendAccount = async () => {
    if (!suspendReason) { toast.error('Enter suspension reason'); return }
    try {
      await api.post(`/users/${id}/suspend`, { reason: suspendReason })
      toast.success('Account suspended')
      setSuspendReason('')
      loadUser()
    } catch (err: unknown) { showError(err, 'Failed to suspend account') }
  }

  const resetPin = async () => {
    if (newPin.length !== 4) { toast.error('PIN must be 4 digits'); return }
    try {
      await api.post(`/users/${id}/reset-pin`, { new_pin: newPin })
      toast.success('PIN reset successfully')
      setNewPin('')
    } catch (err: unknown) { showError(err, 'Failed to reset PIN') }
  }

  if (!detail) return <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>

  const { user } = detail
  const statusColor = (s: string) => {
    switch (s) {
      case 'active': return 'bg-green-100 text-green-700'
      case 'locked': return 'bg-red-100 text-red-700'
      case 'suspended': return 'bg-amber-100 text-amber-700'
      default: return 'bg-gray-100 text-gray-600'
    }
  }

  return (
    <div className="max-w-3xl space-y-6">
      <h1 className="text-2xl font-bold">User Detail</h1>

      {/* User Info */}
      <div className="card">
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div><p className="text-gray-500">Name</p><p className="font-medium">{user.full_name}</p></div>
          <div><p className="text-gray-500">Phone</p><p className="font-medium">{user.phone}</p></div>
          <div><p className="text-gray-500">Email</p><p className="font-medium">{user.email || '-'}</p></div>
          <div>
            <p className="text-gray-500">Status</p>
            <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusColor(user.status)}`}>{user.status}</span>
          </div>
          <div><p className="text-gray-500">KYC Status</p><p className="font-medium capitalize">{user.kyc_status}</p></div>
          <div><p className="text-gray-500">KYC Tier</p><p className="font-medium">{user.kyc_tier}</p></div>
          <div><p className="text-gray-500">Available Balance</p><p className="font-medium">TZS {detail.available_balance.toLocaleString()}</p></div>
          <div><p className="text-gray-500">Locked Balance</p><p className="font-medium">TZS {detail.locked_balance.toLocaleString()}</p></div>
          <div><p className="text-gray-500">Joined</p><p className="font-medium">{new Date(user.created_at).toLocaleString()}</p></div>
        </div>
      </div>

      {/* Account Actions */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-4">Account Actions</h2>
        <div className="flex flex-wrap gap-3">
          {(user.status === 'locked' || user.status === 'suspended') && (
            <button onClick={unlockAccount} className="btn-primary flex items-center gap-2">
              <Unlock className="w-4 h-4" /> Unlock Account
            </button>
          )}
          {user.status === 'active' && (
            <div className="flex gap-2 items-end">
              <div>
                <label className="block text-xs text-gray-500 mb-1">Reason</label>
                <input value={suspendReason} onChange={(e) => setSuspendReason(e.target.value)} className="input-field w-48" placeholder="Suspension reason" />
              </div>
              <button onClick={suspendAccount} className="btn-danger flex items-center gap-2">
                <Lock className="w-4 h-4" /> Suspend
              </button>
            </div>
          )}
          <div className="flex gap-2 items-end">
            <div>
              <label className="block text-xs text-gray-500 mb-1">New PIN (4 digits)</label>
              <input value={newPin} onChange={(e) => setNewPin(e.target.value)} className="input-field w-28" maxLength={4} placeholder="****" type="password" />
            </div>
            <button onClick={resetPin} className="btn-secondary flex items-center gap-2">
              <KeyRound className="w-4 h-4" /> Reset PIN
            </button>
          </div>
        </div>
      </div>

      {/* KYC Documents & Actions */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
          <FileCheck className="w-5 h-5" /> KYC Documents
        </h2>

        {kycDocs.length === 0 ? (
          <div className="text-center py-6">
            <p className="text-gray-500 text-sm">No pending KYC documents for this user</p>
            <p className="text-xs text-gray-400 mt-1">Current KYC status: <span className="capitalize font-medium">{user.kyc_status}</span> (Tier {user.kyc_tier})</p>
          </div>
        ) : (
          <div className="space-y-4">
            {kycDocs.map((doc) => (
              <div key={doc.id} className="border rounded-lg p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <Clock className="w-5 h-5 text-amber-500" />
                    <div>
                      <p className="font-medium capitalize">{doc.document_type.replace(/_/g, ' ')}</p>
                      <p className="text-xs text-gray-500">ID: <span className="font-mono">{doc.id}</span></p>
                      <p className="text-xs text-gray-500">Submitted: {new Date(doc.created_at).toLocaleString()}</p>
                    </div>
                  </div>
                  <span className="text-xs px-2 py-0.5 rounded-full font-medium bg-amber-100 text-amber-700">
                    {doc.status}
                  </span>
                </div>

                {/* Approve/Reject actions */}
                <div className="border-t pt-3 space-y-3">
                  <div className="flex gap-3 items-end">
                    <div className="flex-1">
                      <label className="block text-xs font-medium text-gray-600 mb-1">Approve as Tier</label>
                      <select value={newTier} onChange={(e) => setNewTier(Number(e.target.value))} className="input-field">
                        <option value={1}>Tier 1 - Basic</option>
                        <option value={2}>Tier 2 - Enhanced</option>
                        <option value={3}>Tier 3 - Premium</option>
                      </select>
                    </div>
                    <button onClick={() => approveKYC(doc.id)} className="btn-primary flex items-center gap-1.5">
                      <CheckCircle className="w-4 h-4" /> Approve
                    </button>
                  </div>

                  <div className="flex gap-3 items-end">
                    <div className="flex-1">
                      <label className="block text-xs font-medium text-gray-600 mb-1">Rejection Reason</label>
                      <input
                        value={rejectReason}
                        onChange={(e) => setRejectReason(e.target.value)}
                        className="input-field"
                        placeholder="e.g., Document is blurry, expired, etc."
                      />
                    </div>
                    <button onClick={() => rejectKYC(doc.id)} className="btn-danger flex items-center gap-1.5">
                      <XCircle className="w-4 h-4" /> Reject
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* User Transactions */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
          <Receipt className="w-5 h-5" /> User Transactions
        </h2>
        {txns.length === 0 ? (
          <p className="text-gray-500 text-sm text-center py-6">No transactions</p>
        ) : (
          <>
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b">
                <tr>
                  <th className="text-left px-3 py-2 font-medium text-gray-500">Type</th>
                  <th className="text-left px-3 py-2 font-medium text-gray-500">Amount</th>
                  <th className="text-left px-3 py-2 font-medium text-gray-500">Status</th>
                  <th className="text-left px-3 py-2 font-medium text-gray-500">Reference</th>
                  <th className="text-left px-3 py-2 font-medium text-gray-500">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {txns.map((t) => (
                  <tr key={t.id} className="hover:bg-gray-50">
                    <td className="px-3 py-2 capitalize">{t.type.replace(/_/g, ' ')}</td>
                    <td className="px-3 py-2 font-medium">TZS {t.amount.toLocaleString()}</td>
                    <td className="px-3 py-2">
                      <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                        t.status === 'completed' ? 'bg-green-100 text-green-700' :
                        t.status === 'failed' ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'
                      }`}>{t.status}</span>
                    </td>
                    <td className="px-3 py-2 font-mono text-xs">{t.reference}</td>
                    <td className="px-3 py-2">{new Date(t.created_at).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {txnTotalPages > 1 && (
              <div className="flex justify-center gap-3 mt-3">
                <button onClick={() => setTxnPage(Math.max(1, txnPage - 1))} disabled={txnPage === 1} className="btn-secondary text-xs">Prev</button>
                <span className="self-center text-xs text-gray-500">Page {txnPage}/{txnTotalPages}</span>
                <button onClick={() => setTxnPage(Math.min(txnTotalPages, txnPage + 1))} disabled={txnPage === txnTotalPages} className="btn-secondary text-xs">Next</button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}
