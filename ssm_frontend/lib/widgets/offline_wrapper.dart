import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Wrap any screen with this to show an offline banner automatically.
/// Usage: OfflineWrapper(child: YourScreen())
class OfflineWrapper extends StatefulWidget {
  final Widget child;
  const OfflineWrapper({required this.child, super.key});

  @override
  State<OfflineWrapper> createState() => _OfflineWrapperState();
}

class _OfflineWrapperState extends State<OfflineWrapper> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _check();
    Connectivity().onConnectivityChanged.listen((results) {
      final offline =
          results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (offline != _isOffline) setState(() => _isOffline = offline);
    });
  }

  Future<void> _check() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOffline = results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (_isOffline)
        Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            color: const Color(0xFFB71C1C),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text('No internet connection',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              const Spacer(),
              GestureDetector(
                onTap: _check,
                child: const Text('Retry',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        decoration: TextDecoration.underline)),
              ),
            ]),
          ),
        ),
      Expanded(child: widget.child),
    ]);
  }
}

/// Call this in main() before runApp() for crash reporting.
void setupCrashHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // TODO: send to Sentry / Firebase Crashlytics
    debugPrint('FLUTTER ERROR: ${details.exception}');
    debugPrint(details.stack.toString());
  };
}
