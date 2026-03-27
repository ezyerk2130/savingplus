import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import { useAuthStore } from '../store/authStore'
import { notificationApi } from '../api/services'
import {
  LayoutDashboard, ArrowDownToLine, ArrowUpFromLine, History,
  PiggyBank, Shield, User, Bell, LogOut, Menu, X,
  TrendingUp, Users, ShieldCheck, Banknote, BookOpen,
} from 'lucide-react'
import { useState, useEffect } from 'react'
import clsx from 'clsx'

const navItems = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/deposit', label: 'Deposit', icon: ArrowDownToLine },
  { to: '/withdraw', label: 'Withdraw', icon: ArrowUpFromLine },
  { to: '/transactions', label: 'Transactions', icon: History },
  { to: '/savings', label: 'Savings', icon: PiggyBank },
  { to: '/investments', label: 'Investments', icon: TrendingUp },
  { to: '/groups', label: 'Groups', icon: Users },
  { to: '/insurance', label: 'Insurance', icon: ShieldCheck },
  { to: '/loans', label: 'Loans', icon: Banknote },
  { to: '/learn', label: 'Learn', icon: BookOpen },
  { to: '/kyc', label: 'KYC', icon: Shield },
  { to: '/notifications', label: 'Notifications', icon: Bell },
  { to: '/profile', label: 'Profile', icon: User },
]

export default function Layout() {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [unreadCount, setUnreadCount] = useState(0)
  const logout = useAuthStore((s) => s.logout)
  const navigate = useNavigate()

  // Load unread notification count (delayed to avoid racing with page data loads)
  useEffect(() => {
    const timeout = setTimeout(() => {
      notificationApi.list()
        .then((res) => setUnreadCount(res.data.unread_count))
        .catch(() => {})
    }, 2000)

    // Refresh every 60 seconds
    const interval = setInterval(() => {
      notificationApi.list()
        .then((res) => setUnreadCount(res.data.unread_count))
        .catch(() => {})
    }, 60000)

    return () => { clearTimeout(timeout); clearInterval(interval) }
  }, [])

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Mobile header */}
      <div className="lg:hidden bg-white border-b border-gray-200 px-4 py-3 flex items-center justify-between">
        <button onClick={() => setSidebarOpen(true)} className="p-1">
          <Menu className="w-6 h-6" />
        </button>
        <h1 className="text-lg font-bold text-primary-600">SavingPlus</h1>
        <div className="w-6" />
      </div>

      {/* Mobile overlay */}
      {sidebarOpen && (
        <div className="fixed inset-0 z-40 lg:hidden" onClick={() => setSidebarOpen(false)}>
          <div className="fixed inset-0 bg-black/50" />
        </div>
      )}

      {/* Sidebar */}
      <aside className={clsx(
        'fixed inset-y-0 left-0 z-50 w-64 bg-white border-r border-gray-200 transform transition-transform duration-200 lg:translate-x-0 flex flex-col',
        sidebarOpen ? 'translate-x-0' : '-translate-x-full'
      )}>
        <div className="flex items-center justify-between p-6 border-b border-gray-100">
          <h1 className="text-xl font-bold text-primary-600">SavingPlus</h1>
          <button onClick={() => setSidebarOpen(false)} className="lg:hidden p-1">
            <X className="w-5 h-5" />
          </button>
        </div>

        <nav className="p-4 space-y-1 flex-1 overflow-y-auto">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) => clsx(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                isActive
                  ? 'bg-primary-50 text-primary-700'
                  : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
              )}
            >
              <item.icon className="w-5 h-5" />
              <span className="flex-1">{item.label}</span>
              {item.to === '/notifications' && unreadCount > 0 && (
                <span className="bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full min-w-[20px] text-center">
                  {unreadCount > 99 ? '99+' : unreadCount}
                </span>
              )}
            </NavLink>
          ))}
        </nav>

        <div className="p-4 border-t border-gray-100 flex-shrink-0">
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 w-full px-3 py-2.5 rounded-lg text-sm font-medium text-red-600 hover:bg-red-50 transition-colors"
          >
            <LogOut className="w-5 h-5" />
            Logout
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="lg:ml-64 min-h-screen">
        <div className="max-w-5xl mx-auto p-4 lg:p-8">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
