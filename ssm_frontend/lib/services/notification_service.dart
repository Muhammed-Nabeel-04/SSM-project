import 'dart:convert';
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

  final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  void connect() async {
    if (_isConnected) return;

    final token = await TokenService.getToken();
    if (token == null) return;

    final wsUrl = '${AppConfig.wsBaseUrl}/notifications/ws/$token';
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          _isConnected = false;
          // Reconnect logic can go here
          Future.delayed(const Duration(seconds: 5), () => connect());
        },
        onError: (error) {
          _isConnected = false;
        },
      );
    } catch (e) {
      _isConnected = false;
    }
  }

  void disconnect() {
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
