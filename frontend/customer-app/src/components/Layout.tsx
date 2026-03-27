import { Outlet, NavLink, useNavigate, useLocation } from 'react-router-dom'
import { useAuthStore } from '../store/authStore'
import { notificationApi } from '../api/services'
import {
  LayoutDashboard, ArrowDownToLine, ArrowUpFromLine, History,
  PiggyBank, Shield, User, Bell, LogOut, Menu, X,
  TrendingUp, Users, ShieldCheck, Banknote, BookOpen,
} from 'lucide-react'
import { useState, useEffect } from 'react'
import clsx from 'clsx'

const navSections = [
  {
    items: [
      { to: '/dashboard', label: 'Home', icon: LayoutDashboard },
    ],
  },
  {
    label: 'Money',
    items: [
      { to: '/deposit', label: 'Deposit', icon: ArrowDownToLine },
      { to: '/withdraw', label: 'Withdraw', icon: ArrowUpFromLine },
      { to: '/transactions', label: 'Transactions', icon: History },
    ],
  },
  {
    label: 'Grow',
    items: [
      { to: '/savings', label: 'Savings', icon: PiggyBank },
      { to: '/investments', label: 'Invest', icon: TrendingUp },
      { to: '/groups', label: 'Upatu', icon: Users },
    ],
  },
  {
    label: 'Protect',
    items: [
      { to: '/insurance', label: 'Insurance', icon: ShieldCheck },
      { to: '/loans', label: 'Loans', icon: Banknote },
    ],
  },
  {
    label: 'More',
    items: [
      { to: '/learn', label: 'Learn', icon: BookOpen },
      { to: '/kyc', label: 'Verify', icon: Shield },
      { to: '/notifications', label: 'Notifications', icon: Bell },
      { to: '/profile', label: 'Account', icon: User },
    ],
  },
]

export default function Layout() {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [unreadCount, setUnreadCount] = useState(0)
  const logout = useAuthStore((s) => s.logout)
  const navigate = useNavigate()
  const location = useLocation()

  useEffect(() => {
    const timeout = setTimeout(() => {
      notificationApi.list()
        .then((res) => setUnreadCount(res.data.unread_count))
        .catch(() => {})
    }, 2000)

    const interval = setInterval(() => {
      notificationApi.list()
        .then((res) => setUnreadCount(res.data.unread_count))
        .catch(() => {})
    }, 60000)

    return () => { clearTimeout(timeout); clearInterval(interval) }
  }, [])

  // Close sidebar on route change
  useEffect(() => { setSidebarOpen(false) }, [location.pathname])

  const handleLogout = () => { logout(); navigate('/login') }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Mobile top bar */}
      <div className="lg:hidden bg-white border-b border-gray-100 px-4 py-3 flex items-center justify-between sticky top-0 z-30">
        <button onClick={() => setSidebarOpen(true)} className="p-2 -ml-2 hover:bg-navy-50 rounded-xl">
          <Menu className="w-5 h-5 text-navy-700" />
        </button>
        <span className="text-lg font-bold text-navy-900">Saving<span className="text-primary-700">Plus</span></span>
        <div className="w-9" />
      </div>

      {/* Mobile overlay */}
      {sidebarOpen && (
        <div className="fixed inset-0 z-40 lg:hidden" onClick={() => setSidebarOpen(false)}>
          <div className="fixed inset-0 bg-navy-950/30 backdrop-blur-sm" />
        </div>
      )}

      {/* Sidebar */}
      <aside className={clsx(
        'fixed inset-y-0 left-0 z-50 w-[260px] bg-white border-r border-gray-100 transform transition-transform duration-200 ease-out lg:translate-x-0 flex flex-col',
        sidebarOpen ? 'translate-x-0' : '-translate-x-full'
      )}>
        {/* Logo */}
        <div className="flex items-center justify-between px-6 py-5 flex-shrink-0">
          <span className="text-xl font-bold text-navy-900">Saving<span className="text-primary-700">Plus</span></span>
          <button onClick={() => setSidebarOpen(false)} className="lg:hidden p-1 hover:bg-navy-50 rounded-lg">
            <X className="w-5 h-5 text-navy-500" />
          </button>
        </div>

        {/* Nav */}
        <nav className="flex-1 overflow-y-auto px-3 pb-4">
          {navSections.map((section, i) => (
            <div key={i} className={i > 0 ? 'mt-5' : ''}>
              {section.label && (
                <p className="px-3 mb-1.5 text-2xs font-semibold uppercase tracking-wider text-navy-400">
                  {section.label}
                </p>
              )}
              <div className="space-y-0.5">
                {section.items.map((item) => (
                  <NavLink
                    key={item.to}
                    to={item.to}
                    className={({ isActive }) => clsx(
                      'flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-150',
                      isActive
                        ? 'bg-primary-50 text-primary-800'
                        : 'text-navy-600 hover:bg-navy-50 hover:text-navy-900'
                    )}
                  >
                    <item.icon className="w-[18px] h-[18px]" />
                    <span className="flex-1">{item.label}</span>
                    {item.to === '/notifications' && unreadCount > 0 && (
                      <span className="bg-danger text-white text-2xs font-bold w-5 h-5 rounded-full flex items-center justify-center">
                        {unreadCount > 9 ? '9+' : unreadCount}
                      </span>
                    )}
                  </NavLink>
                ))}
              </div>
            </div>
          ))}
        </nav>

        {/* Logout */}
        <div className="px-3 py-4 border-t border-gray-100 flex-shrink-0">
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 w-full px-3 py-2.5 rounded-xl text-sm font-medium text-navy-500 hover:bg-red-50 hover:text-danger transition-all duration-150"
          >
            <LogOut className="w-[18px] h-[18px]" />
            Log out
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="lg:ml-[260px] min-h-screen">
        <div className="max-w-3xl mx-auto px-4 py-6 lg:px-8 lg:py-8">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
