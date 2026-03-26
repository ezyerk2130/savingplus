import { Routes, Route, Navigate } from 'react-router-dom'
import { useAdminAuth } from './store/authStore'
import AdminLayout from './components/AdminLayout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Users from './pages/Users'
import UserDetail from './pages/UserDetail'
import PendingKYC from './pages/PendingKYC'
import Transactions from './pages/Transactions'
import Reconciliation from './pages/Reconciliation'
import AuditLogs from './pages/AuditLogs'
import FeatureFlags from './pages/FeatureFlags'
import AdminUsers from './pages/AdminUsers'
import TierLimits from './pages/TierLimits'
import SecurityAlerts from './pages/SecurityAlerts'

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const isAuth = useAdminAuth((s) => s.isAuthenticated)
  return isAuth ? <>{children}</> : <Navigate to="/login" replace />
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={<ProtectedRoute><AdminLayout /></ProtectedRoute>}>
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<Dashboard />} />
        <Route path="users" element={<Users />} />
        <Route path="users/:id" element={<UserDetail />} />
        <Route path="kyc-queue" element={<PendingKYC />} />
        <Route path="transactions" element={<Transactions />} />
        <Route path="reconciliation" element={<Reconciliation />} />
        <Route path="audit-logs" element={<AuditLogs />} />
        <Route path="feature-flags" element={<FeatureFlags />} />
        <Route path="admin-users" element={<AdminUsers />} />
        <Route path="tier-limits" element={<TierLimits />} />
        <Route path="security-alerts" element={<SecurityAlerts />} />
      </Route>
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  )
}
