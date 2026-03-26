import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import { useAdminAuth } from '../store/authStore'
import {
  LayoutDashboard, Users, Receipt, ScrollText, Flag, LogOut, Shield,
  FileCheck, Scale, UserCog, Sliders, AlertTriangle,
} from 'lucide-react'
import clsx from 'clsx'

export default function AdminLayout() {
  const { role, logout } = useAdminAuth()
  const navigate = useNavigate()

  const handleLogout = () => { logout(); navigate('/login') }

  const navItems = [
    { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard, roles: ['support', 'finance', 'super_admin'] },
    // Support
    { to: '/users', label: 'Users', icon: Users, roles: ['support', 'super_admin'] },
    { to: '/kyc-queue', label: 'KYC Queue', icon: FileCheck, roles: ['support', 'super_admin'] },
    // Finance
    { to: '/transactions', label: 'Transactions', icon: Receipt, roles: ['finance', 'super_admin'] },
    { to: '/reconciliation', label: 'Reconciliation', icon: Scale, roles: ['finance', 'super_admin'] },
    // Super Admin
    { to: '/admin-users', label: 'Admin Users', icon: UserCog, roles: ['super_admin'] },
    { to: '/tier-limits', label: 'Tier Limits', icon: Sliders, roles: ['super_admin'] },
    { to: '/audit-logs', label: 'Audit Logs', icon: ScrollText, roles: ['super_admin'] },
    { to: '/feature-flags', label: 'Feature Flags', icon: Flag, roles: ['super_admin'] },
    { to: '/security-alerts', label: 'Security Alerts', icon: AlertTriangle, roles: ['super_admin'] },
  ].filter((item) => role && item.roles.includes(role))

  // Group nav items
  const supportItems = navItems.filter((i) => ['/users', '/kyc-queue'].includes(i.to))
  const financeItems = navItems.filter((i) => ['/transactions', '/reconciliation'].includes(i.to))
  const superItems = navItems.filter((i) => ['/admin-users', '/tier-limits', '/audit-logs', '/feature-flags', '/security-alerts'].includes(i.to))
  const dashItem = navItems.filter((i) => i.to === '/dashboard')

  const renderNav = (items: typeof navItems, label?: string) => (
    <>
      {label && items.length > 0 && (
        <p className="px-3 pt-4 pb-1 text-xs font-semibold text-gray-500 uppercase tracking-wider">{label}</p>
      )}
      {items.map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          className={({ isActive }) => clsx(
            'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
            isActive ? 'bg-emerald-600 text-white' : 'text-gray-400 hover:bg-gray-800 hover:text-white'
          )}
        >
          <item.icon className="w-5 h-5" />
          {item.label}
        </NavLink>
      ))}
    </>
  )

  return (
    <div className="flex min-h-screen">
      <aside className="w-60 bg-gray-900 text-gray-300 flex flex-col">
        <div className="p-5 border-b border-gray-800">
          <div className="flex items-center gap-2">
            <Shield className="w-6 h-6 text-emerald-400" />
            <h1 className="text-lg font-bold text-white">SavingPlus Admin</h1>
          </div>
          <p className="text-xs text-gray-500 mt-1 capitalize">{role?.replace('_', ' ')} panel</p>
        </div>

        <nav className="p-3 space-y-0.5 flex-1 overflow-y-auto">
          {renderNav(dashItem)}
          {renderNav(supportItems, 'Support')}
          {renderNav(financeItems, 'Finance')}
          {renderNav(superItems, 'System')}
        </nav>

        <div className="p-3 border-t border-gray-800">
          <button onClick={handleLogout} className="flex items-center gap-3 w-full px-3 py-2.5 rounded-lg text-sm text-red-400 hover:bg-gray-800">
            <LogOut className="w-5 h-5" /> Logout
          </button>
        </div>
      </aside>

      <main className="flex-1 p-8 overflow-auto">
        <Outlet />
      </main>
    </div>
  )
}
