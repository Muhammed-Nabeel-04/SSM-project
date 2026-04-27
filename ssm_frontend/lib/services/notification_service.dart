import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/app_config.dart';
import 'token_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;

  final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  void connect() async {
    if (_isConnected) return;

    final token = await TokenService.getToken();
    if (token == null) return;

    final wsUrl = '${AppConfig.wsBaseUrl}/notifications/ws';
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      // ── Send Handshake ─────────────────────────────────────────────────────
      _channel!.sink.add(jsonEncode({'token': token}));

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () => _handleDisconnect(),
        onError: (error) => _handleDisconnect(),
      );

      // ── Start Heartbeat ────────────────────────────────────────────────────
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
        if (_isConnected) {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        }
      });

    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _subscription?.cancel();
    _heartbeatTimer?.cancel();
    // Reconnect after 5 seconds
    Future.delayed(const Duration(seconds: 5), () => connect());
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'notification') {
        _showInAppNotification(data['title'], data['body']);
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  void _showInAppNotification(String title, String body) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {
            messengerKey.currentState?.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
