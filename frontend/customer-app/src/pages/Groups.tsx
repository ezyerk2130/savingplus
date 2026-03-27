import { useEffect, useState } from 'react'
import { Users, Plus, ArrowDownCircle, Play, LogOut as LeaveIcon, LogIn } from 'lucide-react'
import toast from 'react-hot-toast'
import { groupApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { SavingsGroup } from '../types'

const typeColor = (type: string) => {
  switch (type) {
    case 'upatu': return 'bg-purple-100 text-purple-700'
    case 'goal': return 'bg-blue-100 text-blue-700'
    case 'challenge': return 'bg-amber-100 text-amber-700'
    default: return 'bg-gray-100 text-gray-600'
  }
}

const statusBadge = (status: string) => {
  switch (status) {
    case 'active': return 'bg-green-100 text-green-700'
    case 'forming': return 'bg-amber-100 text-amber-700'
    case 'completed': return 'bg-blue-100 text-blue-700'
    default: return 'bg-gray-100 text-gray-600'
  }
}

export default function Groups() {
  const [groups, setGroups] = useState<SavingsGroup[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)

  // Create modal state
  const [showCreate, setShowCreate] = useState(false)
  const [createForm, setCreateForm] = useState({
    name: '', description: '', type: 'upatu', contribution_amount: '',
    frequency: 'monthly', max_members: '10',
  })
  const [submitting, setSubmitting] = useState(false)

  const formatAmount = (amt: string | number) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(typeof amt === 'string' ? parseFloat(amt) : amt)

  const loadGroups = () => {
    setLoading(true)
    setError(false)
    groupApi.list().then((res) => {
      setGroups(res.data.groups || [])
    }).catch((err: unknown) => {
      showLoadError(err, 'groups')
      setError(true)
    }).finally(() => setLoading(false))
  }

  useEffect(() => { loadGroups() }, [])

  const handleCreate = async () => {
    if (!createForm.name || !createForm.contribution_amount || parseFloat(createForm.contribution_amount) <= 0) {
      toast.error('Please fill in all required fields')
      return
    }
    setSubmitting(true)
    try {
      await groupApi.create({
        name: createForm.name,
        description: createForm.description || undefined,
        type: createForm.type,
        contribution_amount: parseFloat(createForm.contribution_amount),
        frequency: createForm.frequency,
        max_members: parseInt(createForm.max_members),
      })
      toast.success('Group created successfully')
      setShowCreate(false)
      setCreateForm({ name: '', description: '', type: 'upatu', contribution_amount: '', frequency: 'monthly', max_members: '10' })
      loadGroups()
    } catch (err: unknown) {
      showError(err, 'Failed to create group')
    } finally {
      setSubmitting(false)
    }
  }

  const handleAction = async (action: 'join' | 'leave' | 'contribute' | 'start', group: SavingsGroup) => {
    try {
      switch (action) {
        case 'join': await groupApi.join(group.id); toast.success(`Joined ${group.name}`); break
        case 'leave': await groupApi.leave(group.id); toast.success(`Left ${group.name}`); break
        case 'contribute': await groupApi.contribute(group.id); toast.success('Contribution made'); break
        case 'start': await groupApi.start(group.id); toast.success('Group started'); break
      }
      loadGroups()
    } catch (err: unknown) {
      showError(err, `${action} failed`)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Savings Groups</h1>
        <button onClick={() => setShowCreate(true)} className="btn-primary flex items-center gap-2">
          <Plus className="w-4 h-4" /> Create Group
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
        </div>
      ) : error ? (
        <div className="card text-center py-12">
          <p className="text-gray-600 mb-4">Failed to load groups</p>
          <button onClick={loadGroups} className="btn-primary">Retry</button>
        </div>
      ) : groups.length === 0 ? (
        <div className="card text-center py-12">
          <Users className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-500 mb-4">No savings groups yet</p>
          <button onClick={() => setShowCreate(true)} className="btn-primary">Create Your First Group</button>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {groups.map((group) => (
            <div key={group.id} className="card border border-gray-200">
              <div className="flex items-start justify-between mb-3">
                <div>
                  <h3 className="font-semibold text-gray-900">{group.name}</h3>
                  {group.description && (
                    <p className="text-xs text-gray-500 mt-0.5">{group.description}</p>
                  )}
                </div>
                <div className="flex gap-1.5">
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${typeColor(group.type)}`}>
                    {group.type}
                  </span>
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusBadge(group.status)}`}>
                    {group.status}
                  </span>
                </div>
              </div>

              <div className="space-y-2 text-sm">
                <div className="flex justify-between text-gray-600">
                  <span>Contribution</span>
                  <span className="font-semibold text-gray-900">TZS {formatAmount(group.contribution_amount)}</span>
                </div>
                <div className="flex justify-between text-gray-600">
                  <span>Frequency</span>
                  <span className="capitalize">{group.frequency}</span>
                </div>
                <div className="flex justify-between text-gray-600">
                  <span>Max Members</span>
                  <span>{group.max_members}</span>
                </div>
                <div className="flex justify-between text-gray-600">
                  <span>Round</span>
                  <span>{group.current_round}</span>
                </div>
              </div>

              <div className="flex gap-2 pt-3 border-t border-gray-200 mt-3">
                {group.status === 'forming' && (
                  <>
                    <button
                      onClick={() => handleAction('join', group)}
                      className="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-emerald-100 text-emerald-700 hover:bg-emerald-200 transition-colors"
                    >
                      <LogIn className="w-3.5 h-3.5" /> Join
                    </button>
                    <button
                      onClick={() => handleAction('start', group)}
                      className="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-blue-100 text-blue-700 hover:bg-blue-200 transition-colors"
                    >
                      <Play className="w-3.5 h-3.5" /> Start
                    </button>
                  </>
                )}
                {group.status === 'active' && (
                  <>
                    <button
                      onClick={() => handleAction('contribute', group)}
                      className="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-emerald-100 text-emerald-700 hover:bg-emerald-200 transition-colors"
                    >
                      <ArrowDownCircle className="w-3.5 h-3.5" /> Contribute
                    </button>
                    <button
                      onClick={() => handleAction('leave', group)}
                      className="flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-medium rounded-lg bg-red-100 text-red-700 hover:bg-red-200 transition-colors"
                    >
                      <LeaveIcon className="w-3.5 h-3.5" /> Leave
                    </button>
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Create Group Modal */}
      {showCreate && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4" onClick={() => setShowCreate(false)}>
          <div className="bg-white rounded-xl shadow-xl w-full max-w-sm max-h-[90vh] overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-4">Create Savings Group</h2>

            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name *</label>
                <input
                  type="text"
                  value={createForm.name}
                  onChange={(e) => setCreateForm({ ...createForm, name: e.target.value })}
                  className="input-field"
                  placeholder="Group name"
                  autoFocus
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <input
                  type="text"
                  value={createForm.description}
                  onChange={(e) => setCreateForm({ ...createForm, description: e.target.value })}
                  className="input-field"
                  placeholder="Optional description"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Type *</label>
                <select
                  value={createForm.type}
                  onChange={(e) => setCreateForm({ ...createForm, type: e.target.value })}
                  className="input-field"
                >
                  <option value="upatu">Upatu (Rotating)</option>
                  <option value="goal">Goal-based</option>
                  <option value="challenge">Challenge</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Contribution Amount (TZS) *</label>
                <input
                  type="number"
                  value={createForm.contribution_amount}
                  onChange={(e) => setCreateForm({ ...createForm, contribution_amount: e.target.value })}
                  className="input-field"
                  placeholder="Amount per round"
                  min={1}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Frequency *</label>
                <select
                  value={createForm.frequency}
                  onChange={(e) => setCreateForm({ ...createForm, frequency: e.target.value })}
                  className="input-field"
                >
                  <option value="daily">Daily</option>
                  <option value="weekly">Weekly</option>
                  <option value="biweekly">Bi-weekly</option>
                  <option value="monthly">Monthly</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Max Members *</label>
                <input
                  type="number"
                  value={createForm.max_members}
                  onChange={(e) => setCreateForm({ ...createForm, max_members: e.target.value })}
                  className="input-field"
                  min={2}
                  max={50}
                />
              </div>
            </div>

            <div className="flex gap-3 mt-5">
              <button onClick={() => setShowCreate(false)} className="flex-1 btn-secondary">
                Cancel
              </button>
              <button
                onClick={handleCreate}
                disabled={submitting || !createForm.name || !createForm.contribution_amount}
                className="flex-1 btn-primary disabled:opacity-50"
              >
                {submitting ? 'Creating...' : 'Create Group'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
