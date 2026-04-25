import 'package:flutter/material.dart';
import 'dart:async';

import '../services/api_service.dart';
import '../screens/shared/notifications_screen.dart';

/// Drop this widget into any AppBar's `actions` list to get a live notification bell.
/// Polls every 60 seconds for unread count.
class NotificationBell extends StatefulWidget {
  /// Color of the bell icon (should contrast with AppBar color)
  final Color iconColor;

  const NotificationBell({super.key, this.iconColor = Colors.white});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    // Poll every 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final data = await ApiService.getUnreadCount();
      if (mounted) setState(() => _unread = (data['count'] as int?) ?? 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        // Refresh count after returning from notifications screen
        _fetch();
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_outlined, color: widget.iconColor, size: 26),
          if (_unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  _unread > 99 ? '99+' : '$_unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
