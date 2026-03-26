import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { ArrowDownToLine, ArrowUpFromLine, PiggyBank, Eye, EyeOff, Lock, Unlock } from 'lucide-react'
import { walletApi, transactionApi, userApi } from '../api/services'
import { useAuthStore } from '../store/authStore'
import { showLoadError } from '../utils/error'
import type { WalletBalance, Transaction, User } from '../types'

export default function Dashboard() {
  const [balance, setBalance] = useState<WalletBalance | null>(null)
  const [recentTxns, setRecentTxns] = useState<Transaction[]>([])
  const [profile, setProfile] = useState<User | null>(null)
  const [showBalance, setShowBalance] = useState(true)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const setUser = useAuthStore((s) => s.setUser)

  const loadDashboard = async () => {
    setLoading(true)
    setError(false)
    try {
      const [balRes, txnRes, profileRes] = await Promise.all([
        walletApi.getBalance(),
        transactionApi.list({ page_size: 5 }),
        userApi.getProfile(),
      ])
      setBalance(balRes.data)
      setRecentTxns(txnRes.data.transactions)
      setProfile(profileRes.data)
      setUser(profileRes.data)
    } catch (err: unknown) {
      showLoadError(err, 'dashboard data')
      setError(true)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadDashboard()
  }, [setUser])

  if (loading) {
    return <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600" /></div>
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center h-64 space-y-4">
        <p className="text-gray-600">Failed to load dashboard data</p>
        <button onClick={loadDashboard} className="btn-primary">Retry</button>
      </div>
    )
  }

  const formatAmount = (amount: string) => {
    return new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(parseFloat(amount))
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">
          Hello, {profile?.full_name?.split(' ')[0] || 'there'}
        </h1>
        <p className="text-gray-500 text-sm mt-1">Welcome to your SavingPlus dashboard</p>
      </div>

      {/* Balance Card */}
      <div className="bg-gradient-to-r from-primary-600 to-primary-800 rounded-2xl p-6 text-white">
        <div className="flex justify-between items-start">
          <div>
            <p className="text-primary-200 text-sm font-medium">Available Balance</p>
            <p className="text-3xl font-bold mt-1">
              {showBalance ? `TZS ${formatAmount(balance?.available_balance || '0')}` : 'TZS ****'}
            </p>
            {balance?.locked_balance && parseFloat(balance.locked_balance) > 0 && (
              <p className="text-primary-200 text-sm mt-2">
                Locked: TZS {showBalance ? formatAmount(balance.locked_balance) : '****'}
              </p>
            )}
          </div>
          <button onClick={() => setShowBalance(!showBalance)} className="p-2 hover:bg-white/10 rounded-lg">
            {showBalance ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
          </button>
        </div>

        <div className="flex gap-3 mt-6">
          <Link to="/deposit" className="flex-1 bg-white/20 hover:bg-white/30 transition-colors rounded-xl py-3 text-center text-sm font-medium">
            <ArrowDownToLine className="w-5 h-5 mx-auto mb-1" />
            Deposit
          </Link>
          <Link to="/withdraw" className="flex-1 bg-white/20 hover:bg-white/30 transition-colors rounded-xl py-3 text-center text-sm font-medium">
            <ArrowUpFromLine className="w-5 h-5 mx-auto mb-1" />
            Withdraw
          </Link>
          <Link to="/savings" className="flex-1 bg-white/20 hover:bg-white/30 transition-colors rounded-xl py-3 text-center text-sm font-medium">
            <PiggyBank className="w-5 h-5 mx-auto mb-1" />
            Save
          </Link>
        </div>
      </div>

      {/* KYC Banner */}
      {profile?.kyc_status !== 'approved' && (
        <Link to="/kyc" className="block card border-l-4 border-l-warning bg-amber-50">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-medium text-amber-800">Complete your KYC verification</p>
              <p className="text-sm text-amber-600 mt-1">
                Verify your identity to unlock higher limits and withdrawals
              </p>
            </div>
            <span className="text-amber-700 font-medium text-sm">Go &rarr;</span>
          </div>
        </Link>
      )}

      {/* Recent Transactions */}
      <div className="card">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-semibold">Recent Transactions</h2>
          <Link to="/transactions" className="text-primary-600 text-sm font-medium hover:underline">
            View all
          </Link>
        </div>

        {recentTxns.length === 0 ? (
          <p className="text-gray-500 text-sm text-center py-8">No transactions yet</p>
        ) : (
          <div className="space-y-3">
            {recentTxns.map((txn) => {
              const isIncoming = txn.type === 'deposit' || txn.type === 'savings_unlock' || txn.type === 'interest'
              const isSavings = txn.type === 'savings_lock' || txn.type === 'savings_unlock'
              return (
                <div key={txn.id} className="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
                  <div className="flex items-center gap-3">
                    <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                      isSavings ? 'bg-purple-100' : isIncoming ? 'bg-green-100' : 'bg-red-100'
                    }`}>
                      {txn.type === 'savings_lock' ? <Lock className="w-5 h-5 text-purple-600" /> :
                       txn.type === 'savings_unlock' ? <Unlock className="w-5 h-5 text-purple-600" /> :
                       isIncoming ? <ArrowDownToLine className="w-5 h-5 text-green-600" /> :
                       <ArrowUpFromLine className="w-5 h-5 text-red-600" />}
                    </div>
                    <div>
                      <p className="text-sm font-medium capitalize">{txn.type.replace(/_/g, ' ')}</p>
                      <p className="text-xs text-gray-500">{new Date(txn.created_at).toLocaleDateString()}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className={`text-sm font-semibold ${
                      isSavings ? 'text-purple-600' : isIncoming ? 'text-green-600' : 'text-red-600'
                    }`}>
                      {isIncoming ? '+' : '-'}TZS {formatAmount(txn.amount)}
                    </p>
                    <p className={`text-xs capitalize ${
                      txn.status === 'completed' ? 'text-green-500' :
                      txn.status === 'failed' ? 'text-red-500' : 'text-amber-500'
                    }`}>
                      {txn.status}
                    </p>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
