import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _api = ApiClient();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/notifications');
      final list = (res.data as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _notifications = list.cast<Map<String, dynamic>>();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to load notifications';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _api.post('/notifications/$id/read');
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx != -1) {
          _notifications[idx] = {..._notifications[idx], 'read': true};
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await _api.post('/notifications/read-all');
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) => {...n, 'read': true}).toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['read'] != true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No notifications', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(0),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      final isRead = n['read'] == true;
                      return ListTile(
                        onTap: () {
                          if (!isRead) _markRead(n['id'] as String);
                        },
                        tileColor: isRead ? null : const Color(0xFF2563EB).withOpacity(0.03),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.grey[100],
                              child: Icon(Icons.notifications, color: Colors.grey[400]),
                            ),
                            if (!isRead)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          n['title'] as String? ?? '',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n['message'] as String? ?? '',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDateTime(n['created_at'] as String? ?? DateTime.now().toIso8601String()),
                              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
    );
  }
}
