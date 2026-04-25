import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getNotifications();
      setState(() => _notifications = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      setState(() {
        for (final n in _notifications) {
          n['is_read'] = true;
        }
      });
    } catch (_) {}
  }

  Future<void> _markRead(int index) async {
    final n = _notifications[index];
    if (n['is_read'] == true) return;
    try {
      await ApiService.markNotificationRead(n['id']);
      setState(() => _notifications[index]['is_read'] = true);
    } catch (_) {}
  }

  Future<void> _delete(int index) async {
    final n = _notifications[index];
    try {
      await ApiService.deleteNotification(n['id']);
      setState(() => _notifications.removeAt(index));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final roleColor = _roleColor(auth.role ?? '');
    final unreadCount =
        _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(children: [
          const Text('Notifications',
              style: TextStyle(fontWeight: FontWeight.w700)),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$unreadCount new',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
        backgroundColor: roleColor,
        foregroundColor: Colors.white,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (ctx, i) {
                      final n = _notifications[i];
                      return _NotificationTile(
                        notification: n,
                        onTap: () => _markRead(i),
                        onDelete: () => _delete(i),
                      );
                    },
                  ),
                ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'student':
        return AppColors.primary;
      case 'mentor':
        return AppColors.mentorColor;
      case 'hod':
        return AppColors.hodColor;
      case 'admin':
        return AppColors.adminColor;
      default:
        return AppColors.primary;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] == true;
    final icon = notification['icon'] ?? 'info';
    final createdAt = notification['created_at'] as String? ?? '';

    return Dismissible(
      key: Key('notif_${notification['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: AppColors.error,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: isRead
              ? Colors.transparent
              : AppColors.primary.withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _iconBgColor(icon),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconData(icon), color: _iconColor(icon), size: 20),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['title'] ?? '',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['body'] ?? '',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _iconBgColor(String icon) {
    switch (icon) {
      case 'check':
        return const Color(0xFF06D6A0).withValues(alpha: 0.12);
      case 'warning':
        return Colors.orange.withValues(alpha: 0.12);
      case 'star':
        return const Color(0xFFFFD700).withValues(alpha: 0.15);
      default:
        return AppColors.primary.withValues(alpha: 0.10);
    }
  }

  Color _iconColor(String icon) {
    switch (icon) {
      case 'check':
        return const Color(0xFF06D6A0);
      case 'warning':
        return Colors.orange;
      case 'star':
        return const Color(0xFFFFAA00);
      default:
        return AppColors.primary;
    }
  }

  IconData _iconData(String icon) {
    switch (icon) {
      case 'check':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'star':
        return Icons.star_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded,
                size: 52, color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          const Text("You're all caught up!",
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text("Notifications about your forms will appear here.",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
