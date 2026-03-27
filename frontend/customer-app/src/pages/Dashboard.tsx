import { useEffect, useState, useCallback } from 'react'
import { Link } from 'react-router-dom'
import { ArrowDownToLine, ArrowUpFromLine, PiggyBank, Eye, EyeOff, Lock, Unlock, RefreshCw, ChevronRight, TrendingUp, ShieldCheck } from 'lucide-react'
import { walletApi, transactionApi, userApi } from '../api/services'
import { useAuthStore } from '../store/authStore'
import { showLoadError } from '../utils/error'
import type { WalletBalance, Transaction, User } from '../types'

export default function Dashboard() {
  const [balance, setBalance] = useState<WalletBalance | null>(null)
  const [recentTxns, setRecentTxns] = useState<Transaction[]>([])
  const [profile, setProfile] = useState<User | null>(null)
  const [showBalance, setShowBalance] = useState(false)
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const setUser = useAuthStore((s) => s.setUser)

  const loadDashboard = useCallback(async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true)
    else setLoading(true)

    const results = await Promise.allSettled([
      walletApi.getBalance(),
      transactionApi.list({ page_size: 5 }),
      userApi.getProfile(),
    ])

    if (results[0].status === 'fulfilled') setBalance(results[0].value.data)
    else showLoadError(results[0].reason, 'balance')

    if (results[1].status === 'fulfilled') setRecentTxns(results[1].value.data.transactions)
    else showLoadError(results[1].reason, 'transactions')

    if (results[2].status === 'fulfilled') {
      setProfile(results[2].value.data)
      setUser(results[2].value.data)
    } else showLoadError(results[2].reason, 'profile')

    setLoading(false)
    setRefreshing(false)
  }, [setUser])

  useEffect(() => { loadDashboard() }, [loadDashboard])

  const fmt = (amount: string) =>
    new Intl.NumberFormat('en-TZ', { minimumFractionDigits: 2 }).format(parseFloat(amount))

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-2 border-primary-500 border-t-transparent" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Greeting */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-navy-900">
            Hi, {profile?.full_name?.split(' ')[0] || 'there'}
          </h1>
          <p className="text-navy-400 text-sm mt-0.5">Welcome back to SavingPlus</p>
        </div>
        <button
          onClick={() => loadDashboard(true)}
          disabled={refreshing}
          className="p-2.5 text-navy-400 hover:text-navy-600 hover:bg-navy-50 rounded-xl transition-all"
        >
          <RefreshCw className={`w-5 h-5 ${refreshing ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {/* Balance Card - Wise style */}
      <div className="card bg-navy-900 border-navy-800 text-white relative overflow-hidden">
        <div className="absolute top-0 right-0 w-40 h-40 bg-primary-400/10 rounded-full -translate-y-10 translate-x-10" />
        <div className="relative">
          <div className="flex items-center justify-between mb-1">
            <p className="text-navy-300 text-sm font-medium">Total Balance</p>
            <button onClick={() => setShowBalance(!showBalance)} className="p-1.5 hover:bg-white/10 rounded-lg transition-colors">
              {showBalance ? <EyeOff className="w-4 h-4 text-navy-300" /> : <Eye className="w-4 h-4 text-navy-300" />}
            </button>
          </div>
          <p className="text-display text-white mb-1">
            {balance
              ? showBalance ? `TZS ${fmt(balance.available_balance)}` : 'TZS ••••••'
              : 'TZS --'
            }
          </p>
          {balance && showBalance && parseFloat(balance.locked_balance) > 0 && (
            <p className="text-navy-400 text-sm">
              + TZS {fmt(balance.locked_balance)} in savings
            </p>
          )}

          {/* Quick actions */}
          <div className="flex gap-2 mt-6">
            <Link to="/deposit" className="flex-1 bg-primary-600 hover:bg-primary-700 text-white rounded-2xl py-3 text-center text-sm font-semibold transition-all active:scale-[0.98]">
              <ArrowDownToLine className="w-4 h-4 mx-auto mb-1" />
              Add money
            </Link>
            <Link to="/withdraw" className="flex-1 bg-white/10 hover:bg-white/15 text-white rounded-2xl py-3 text-center text-sm font-semibold transition-all active:scale-[0.98]">
              <ArrowUpFromLine className="w-4 h-4 mx-auto mb-1" />
              Send
            </Link>
            <Link to="/savings" className="flex-1 bg-white/10 hover:bg-white/15 text-white rounded-2xl py-3 text-center text-sm font-semibold transition-all active:scale-[0.98]">
              <PiggyBank className="w-4 h-4 mx-auto mb-1" />
              Save
            </Link>
          </div>
        </div>
      </div>

      {/* Quick links - Wise style horizontal scroll */}
      <div className="flex gap-3 overflow-x-auto pb-1 -mx-1 px-1 scrollbar-hide">
        <Link to="/investments" className="flex-shrink-0 card py-4 px-5 flex items-center gap-3 hover:border-primary-200 transition-colors">
          <div className="w-10 h-10 bg-green-50 rounded-xl flex items-center justify-center">
            <TrendingUp className="w-5 h-5 text-green-600" />
          </div>
          <div>
            <p className="text-sm font-semibold text-navy-900">Invest</p>
            <p className="text-2xs text-navy-400">Up to 25% p.a.</p>
          </div>
        </Link>
        <Link to="/groups" className="flex-shrink-0 card py-4 px-5 flex items-center gap-3 hover:border-primary-200 transition-colors">
          <div className="w-10 h-10 bg-purple-50 rounded-xl flex items-center justify-center">
            <svg className="w-5 h-5 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
          </div>
          <div>
            <p className="text-sm font-semibold text-navy-900">Upatu</p>
            <p className="text-2xs text-navy-400">Group savings</p>
          </div>
        </Link>
        <Link to="/insurance" className="flex-shrink-0 card py-4 px-5 flex items-center gap-3 hover:border-primary-200 transition-colors">
          <div className="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center">
            <ShieldCheck className="w-5 h-5 text-blue-600" />
          </div>
          <div>
            <p className="text-sm font-semibold text-navy-900">Insure</p>
            <p className="text-2xs text-navy-400">From 2K/mo</p>
          </div>
        </Link>
      </div>

      {/* KYC Banner */}
      {profile && profile.kyc_status !== 'approved' && (
        <Link to="/kyc" className="card border-l-4 border-l-warning bg-amber-50/50 flex items-center justify-between group">
          <div>
            <p className="font-semibold text-navy-900 text-sm">Complete verification</p>
            <p className="text-2xs text-navy-500 mt-0.5">Unlock higher limits and withdrawals</p>
          </div>
          <ChevronRight className="w-5 h-5 text-navy-300 group-hover:text-navy-500 transition-colors" />
        </Link>
      )}

      {/* Recent Transactions */}
      <div>
        <div className="flex justify-between items-center mb-3">
          <h2 className="text-base font-semibold text-navy-900">Recent activity</h2>
          <Link to="/transactions" className="text-sm font-medium text-primary-700 hover:text-primary-800">
            See all
          </Link>
        </div>

        <div className="card p-0 overflow-hidden divide-y divide-gray-50">
          {recentTxns.length === 0 ? (
            <p className="text-navy-400 text-sm text-center py-10">No transactions yet</p>
          ) : (
            recentTxns.map((txn) => {
              const isIncoming = txn.type === 'deposit' || txn.type === 'savings_unlock' || txn.type === 'interest'
              const isSavings = txn.type === 'savings_lock' || txn.type === 'savings_unlock'
              return (
                <div key={txn.id} className="flex items-center justify-between px-5 py-3.5 hover:bg-navy-50/50 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${
                      isSavings ? 'bg-purple-50' : isIncoming ? 'bg-green-50' : 'bg-navy-50'
                    }`}>
                      {txn.type === 'savings_lock' ? <Lock className="w-4 h-4 text-purple-600" /> :
                       txn.type === 'savings_unlock' ? <Unlock className="w-4 h-4 text-purple-600" /> :
                       isIncoming ? <ArrowDownToLine className="w-4 h-4 text-green-600" /> :
                       <ArrowUpFromLine className="w-4 h-4 text-navy-500" />}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-navy-900 capitalize">{txn.type.replace(/_/g, ' ')}</p>
                      <p className="text-2xs text-navy-400">{new Date(txn.created_at).toLocaleDateString()}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className={`text-sm font-semibold ${
                      isSavings ? 'text-purple-600' : isIncoming ? 'text-green-600' : 'text-navy-900'
                    }`}>
                      {isIncoming ? '+' : '-'}TZS {fmt(txn.amount)}
                    </p>
                    <span className={`text-2xs font-medium ${
                      txn.status === 'completed' ? 'text-green-500' :
                      txn.status === 'failed' ? 'text-danger' : 'text-warning'
                    }`}>
                      {txn.status}
                    </span>
                  </div>
                </div>
              )
            })
          )}
        </div>
      </div>
    </div>
  )
}
