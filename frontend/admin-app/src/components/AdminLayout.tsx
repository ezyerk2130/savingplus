import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import { useAdminAuth } from '../store/authStore'
import {
  LayoutDashboard, Users, Receipt, ScrollText, Flag, LogOut, Shield,
} from 'lucide-react'
import clsx from 'clsx'

export default function AdminLayout() {
  const { role, logout } = useAdminAuth()
  const navigate = useNavigate()

  const handleLogout = () => { logout(); navigate('/login') }

  const navItems = [
    { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard, roles: ['support', 'finance', 'super_admin'] },
    { to: '/users', label: 'Users / KYC', icon: Users, roles: ['support', 'super_admin'] },
    { to: '/transactions', label: 'Transactions', icon: Receipt, roles: ['finance', 'super_admin'] },
    { to: '/audit-logs', label: 'Audit Logs', icon: ScrollText, roles: ['super_admin'] },
    { to: '/feature-flags', label: 'Feature Flags', icon: Flag, roles: ['super_admin'] },
  ].filter((item) => role && item.roles.includes(role))

  return (
    <div className="flex min-h-screen">
      <aside className="w-60 bg-gray-900 text-gray-300">
        <div className="p-5 border-b border-gray-800">
          <div className="flex items-center gap-2">
            <Shield className="w-6 h-6 text-emerald-400" />
            <h1 className="text-lg font-bold text-white">SavingPlus Admin</h1>
          </div>
          <p className="text-xs text-gray-500 mt-1 capitalize">{role?.replace('_', ' ')} panel</p>
        </div>

        <nav className="p-3 space-y-1">
          {navItems.map((item) => (
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
        </nav>

        <div className="absolute bottom-0 w-60 p-3 border-t border-gray-800">
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
