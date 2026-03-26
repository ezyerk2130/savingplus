import { useEffect, useState } from 'react'
import { Bell, Check, CheckCheck } from 'lucide-react'
import toast from 'react-hot-toast'
import { notificationApi } from '../api/services'
import { showLoadError } from '../utils/error'
import type { Notification } from '../types'

export default function Notifications() {
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [unreadCount, setUnreadCount] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadNotifications()
  }, [])

  const loadNotifications = async () => {
    try {
      const res = await notificationApi.list()
      setNotifications(res.data.notifications)
      setUnreadCount(res.data.unread_count)
    } catch (err: unknown) {
      showLoadError(err, 'notifications')
    } finally {
      setLoading(false)
    }
  }

  const markRead = async (id: string) => {
    try {
      await notificationApi.markRead(id)
      setNotifications((prev) =>
        prev.map((n) => (n.id === id ? { ...n, read: true } : n))
      )
      setUnreadCount((c) => Math.max(0, c - 1))
    } catch (err: unknown) {
      showLoadError(err, 'marking notification as read')
    }
  }

  const markAllRead = async () => {
    try {
      await notificationApi.markAllRead()
      setNotifications((prev) => prev.map((n) => ({ ...n, read: true })))
      setUnreadCount(0)
      toast.success('All marked as read')
    } catch (err: unknown) {
      showLoadError(err, 'marking all notifications as read')
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Notifications</h1>
          {unreadCount > 0 && (
            <p className="text-sm text-gray-500">{unreadCount} unread</p>
          )}
        </div>
        {unreadCount > 0 && (
          <button onClick={markAllRead} className="btn-secondary flex items-center gap-2 text-sm">
            <CheckCheck className="w-4 h-4" /> Mark all read
          </button>
        )}
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
        </div>
      ) : notifications.length === 0 ? (
        <div className="card text-center py-12">
          <Bell className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-500">No notifications yet</p>
        </div>
      ) : (
        <div className="space-y-2">
          {notifications.map((notif) => (
            <div
              key={notif.id}
              className={`card flex items-start gap-3 cursor-pointer transition-colors ${
                !notif.read ? 'bg-primary-50 border-primary-100' : ''
              }`}
              onClick={() => !notif.read && markRead(notif.id)}
            >
              <div className={`w-2 h-2 rounded-full mt-2 flex-shrink-0 ${
                notif.read ? 'bg-transparent' : 'bg-primary-500'
              }`} />
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between">
                  <p className="font-medium text-sm">{notif.title}</p>
                  <span className="text-xs text-gray-400 flex-shrink-0 ml-2">
                    {new Date(notif.created_at).toLocaleDateString()}
                  </span>
                </div>
                <p className="text-sm text-gray-600 mt-0.5">{notif.message}</p>
              </div>
              {!notif.read && (
                <button className="flex-shrink-0 p-1 text-gray-400 hover:text-primary-600">
                  <Check className="w-4 h-4" />
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
