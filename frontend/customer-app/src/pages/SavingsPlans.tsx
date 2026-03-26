import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { PiggyBank, Plus, Target, Lock, Wallet } from 'lucide-react'
import { savingsApi } from '../api/services'
import type { SavingsPlan } from '../types'

const typeIcon = (type: string) => {
  switch (type) {
    case 'flexible': return <Wallet className="w-5 h-5 text-blue-600" />
    case 'locked': return <Lock className="w-5 h-5 text-purple-600" />
    case 'target': return <Target className="w-5 h-5 text-green-600" />
    default: return <PiggyBank className="w-5 h-5" />
  }
}

const typeColor = (type: string) => {
  switch (type) {
    case 'flexible': return 'bg-blue-50 border-blue-200'
    case 'locked': return 'bg-purple-50 border-purple-200'
    case 'target': return 'bg-green-50 border-green-200'
    default: return 'bg-gray-50'
  }
}

export default function SavingsPlans() {
  const [plans, setPlans] = useState<SavingsPlan[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    savingsApi.listPlans().then((res) => {
      setPlans(res.data.plans)
    }).catch(console.error).finally(() => setLoading(false))
  }, [])

  const formatAmount = (amount: string) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(parseFloat(amount))

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Savings Plans</h1>
        <Link to="/savings/new" className="btn-primary flex items-center gap-2">
          <Plus className="w-4 h-4" /> New Plan
        </Link>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
        </div>
      ) : plans.length === 0 ? (
        <div className="card text-center py-12">
          <PiggyBank className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-500 mb-4">No savings plans yet</p>
          <Link to="/savings/new" className="btn-primary">Create Your First Plan</Link>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {plans.map((plan) => (
            <div key={plan.id} className={`card border ${typeColor(plan.type)}`}>
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-2">
                  {typeIcon(plan.type)}
                  <div>
                    <h3 className="font-semibold text-gray-900">{plan.name}</h3>
                    <p className="text-xs text-gray-500 capitalize">{plan.type} savings</p>
                  </div>
                </div>
                <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                  plan.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'
                }`}>
                  {plan.status}
                </span>
              </div>

              <div className="space-y-2">
                <div>
                  <p className="text-xs text-gray-500">Saved</p>
                  <p className="text-lg font-bold">TZS {formatAmount(plan.current_amount)}</p>
                </div>

                {plan.target_amount && (
                  <div>
                    <div className="flex justify-between text-xs text-gray-500 mb-1">
                      <span>Target: TZS {formatAmount(plan.target_amount)}</span>
                      <span>{Math.round((parseFloat(plan.current_amount) / parseFloat(plan.target_amount)) * 100)}%</span>
                    </div>
                    <div className="w-full bg-gray-200 rounded-full h-2">
                      <div
                        className="bg-green-500 rounded-full h-2 transition-all"
                        style={{ width: `${Math.min(100, (parseFloat(plan.current_amount) / parseFloat(plan.target_amount)) * 100)}%` }}
                      />
                    </div>
                  </div>
                )}

                <div className="flex justify-between text-xs text-gray-500 pt-2">
                  <span>Rate: {plan.interest_rate}</span>
                  {plan.maturity_date && (
                    <span>Matures: {new Date(plan.maturity_date).toLocaleDateString()}</span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
