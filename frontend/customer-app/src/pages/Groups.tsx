import { useEffect, useState } from 'react'
import { Users, Plus, ArrowDownCircle, Play, LogOut as LeaveIcon, LogIn, RefreshCw } from 'lucide-react'
import toast from 'react-hot-toast'
import { groupApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { SavingsGroup } from '../types'

const typeLabel: Record<string, { bg: string; text: string; label: string }> = {
  upatu: { bg: 'bg-purple-50', text: 'text-purple-700', label: 'Upatu' },
  goal: { bg: 'bg-blue-50', text: 'text-blue-700', label: 'Goal' },
  challenge: { bg: 'bg-amber-50', text: 'text-amber-700', label: 'Challenge' },
}

const statusStyle: Record<string, string> = {
  active: 'badge-success',
  forming: 'badge-warning',
  completed: 'badge-info',
}

export default function Groups() {
  const [groups, setGroups] = useState<SavingsGroup[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [refreshing, setRefreshing] = useState(false)

  // Create modal state
  const [showCreate, setShowCreate] = useState(false)
  const [createForm, setCreateForm] = useState({
    name: '', description: '', type: 'upatu', contribution_amount: '',
    frequency: 'monthly', max_members: '10',
  })
  const [submitting, setSubmitting] = useState(false)

  const fmt = (amt: string | number) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(typeof amt === 'string' ? parseFloat(amt) : amt)

  const loadGroups = (isRefresh = false) => {
    if (isRefresh) setRefreshing(true)
    else setLoading(true)
    setError(false)
    groupApi.list().then((res) => {
      setGroups(res.data.groups || [])
    }).catch((err: unknown) => {
      showLoadError(err, 'groups')
      setError(true)
    }).finally(() => {
      setLoading(false)
      setRefreshing(false)
    })
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
      {/* Page header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-purple-50 rounded-xl flex items-center justify-center">
            <Users className="w-5 h-5 text-purple-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-navy-900">Upatu Groups</h1>
            <p className="text-navy-400 text-sm">Save together, grow together</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => loadGroups(true)}
            disabled={refreshing}
            className="p-2.5 text-navy-400 hover:text-navy-600 hover:bg-navy-50 rounded-xl transition-all"
          >
            <RefreshCw className={`w-5 h-5 ${refreshing ? 'animate-spin' : ''}`} />
          </button>
          <button onClick={() => setShowCreate(true)} className="btn-primary flex items-center gap-2">
            <Plus className="w-4 h-4" /> Create Group
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-primary-500 border-t-transparent" />
        </div>
      ) : error ? (
        <div className="card text-center py-16">
          <p className="text-navy-500 mb-4">Failed to load groups</p>
          <button onClick={() => loadGroups()} className="btn-primary">Retry</button>
        </div>
      ) : groups.length === 0 ? (
        <div className="card text-center py-16">
          <div className="w-16 h-16 bg-navy-50 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <Users className="w-8 h-8 text-navy-300" />
          </div>
          <p className="text-navy-500 font-medium mb-1">No savings groups yet</p>
          <p className="text-navy-400 text-sm mb-6">Create or join a group to start saving together</p>
          <button onClick={() => setShowCreate(true)} className="btn-primary">Create Your First Group</button>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {groups.map((group) => {
            const t = typeLabel[group.type] || { bg: 'bg-navy-50', text: 'text-navy-600', label: group.type }
            return (
              <div key={group.id} className="card bg-navy-50/50 border-navy-100 hover:border-navy-200 transition-colors">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex-1 min-w-0">
                    <h3 className="font-semibold text-navy-900 truncate">{group.name}</h3>
                    {group.description && (
                      <p className="text-2xs text-navy-400 mt-0.5 line-clamp-1">{group.description}</p>
                    )}
                  </div>
                  <div className="flex gap-1.5 ml-2 flex-shrink-0">
                    <span className={`badge ${t.bg} ${t.text}`}>{t.label}</span>
                    <span className={statusStyle[group.status] || 'badge-neutral'}>{group.status}</span>
                  </div>
                </div>

                {/* Contribution highlight */}
                <div className="bg-white rounded-2xl p-3.5 mb-4">
                  <p className="text-2xs text-navy-400 font-medium mb-0.5">Contribution per round</p>
                  <p className="text-lg font-bold text-navy-900">TZS {fmt(group.contribution_amount)}</p>
                  <p className="text-2xs text-navy-400 capitalize">{group.frequency}</p>
                </div>

                <div className="grid grid-cols-2 gap-3 text-sm mb-4">
                  <div>
                    <p className="text-2xs text-navy-400">Max Members</p>
                    <p className="font-semibold text-navy-700">{group.max_members}</p>
                  </div>
                  <div>
                    <p className="text-2xs text-navy-400">Current Round</p>
                    <p className="font-semibold text-navy-700">{group.current_round}</p>
                  </div>
                </div>

                {/* Action buttons */}
                <div className="flex gap-2 pt-3 border-t border-navy-100">
                  {group.status === 'forming' && (
                    <>
                      <button
                        onClick={() => handleAction('join', group)}
                        className="flex-1 flex items-center justify-center gap-1.5 py-2.5 px-3 text-sm font-semibold rounded-2xl bg-green-50 text-green-700 hover:bg-green-100 transition-all active:scale-[0.98]"
                      >
                        <LogIn className="w-4 h-4" /> Join
                      </button>
                      <button
                        onClick={() => handleAction('start', group)}
                        className="flex-1 flex items-center justify-center gap-1.5 py-2.5 px-3 text-sm font-semibold rounded-2xl bg-primary-50 text-primary-700 hover:bg-primary-100 transition-all active:scale-[0.98]"
                      >
                        <Play className="w-4 h-4" /> Start
                      </button>
                    </>
                  )}
                  {group.status === 'active' && (
                    <>
                      <button
                        onClick={() => handleAction('contribute', group)}
                        className="flex-1 flex items-center justify-center gap-1.5 py-2.5 px-3 text-sm font-semibold rounded-2xl bg-green-50 text-green-700 hover:bg-green-100 transition-all active:scale-[0.98]"
                      >
                        <ArrowDownCircle className="w-4 h-4" /> Contribute
                      </button>
                      <button
                        onClick={() => handleAction('leave', group)}
                        className="flex items-center justify-center gap-1.5 py-2.5 px-3 text-sm font-semibold rounded-2xl bg-red-50 text-red-700 hover:bg-red-100 transition-all active:scale-[0.98]"
                      >
                        <LeaveIcon className="w-4 h-4" /> Leave
                      </button>
                    </>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Create Group Modal */}
      {showCreate && (
        <div className="fixed inset-0 bg-navy-950/50 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setShowCreate(false)}>
          <div className="bg-white rounded-3xl shadow-xl w-full max-w-md max-h-[90vh] overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center gap-3 mb-6">
              <div className="w-10 h-10 bg-purple-50 rounded-xl flex items-center justify-center">
                <Users className="w-5 h-5 text-purple-600" />
              </div>
              <div>
                <h2 className="text-lg font-bold text-navy-900">Create Savings Group</h2>
                <p className="text-2xs text-navy-400">Set up a new group for your circle</p>
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-navy-700 mb-1.5">Group Name *</label>
                <input
                  type="text"
                  value={createForm.name}
                  onChange={(e) => setCreateForm({ ...createForm, name: e.target.value })}
                  className="input-field"
                  placeholder="e.g. Family Savings Circle"
                  autoFocus
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-navy-700 mb-1.5">Description</label>
                <input
                  type="text"
                  value={createForm.description}
                  onChange={(e) => setCreateForm({ ...createForm, description: e.target.value })}
                  className="input-field"
                  placeholder="What is this group for?"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-navy-700 mb-1.5">Type *</label>
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
                <label className="block text-sm font-medium text-navy-700 mb-1.5">Contribution Amount (TZS) *</label>
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
                <label className="block text-sm font-medium text-navy-700 mb-1.5">Frequency *</label>
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
                <label className="block text-sm font-medium text-navy-700 mb-1.5">Max Members *</label>
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

            <div className="flex gap-3 mt-6">
              <button onClick={() => setShowCreate(false)} className="flex-1 btn-secondary">
                Cancel
              </button>
              <button
                onClick={handleCreate}
                disabled={submitting || !createForm.name || !createForm.contribution_amount}
                className="flex-1 btn-primary"
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
