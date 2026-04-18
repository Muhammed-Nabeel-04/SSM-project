import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // --- Constants ---
  // 10.0.2.2 is how the Android Emulator connects to your computer's localhost
  static const String urlEmulator = 'http://10.0.2.2:8000';
  // Standard localhost for Web or iOS Simulator
  static const String urlLocalhost = 'http://127.0.0.1:8000';

  static const String _defaultUrl =
      'https://noisy-unit-b55c.nabeelmdnabeel1229.workers.dev';

  // static const String _defaultUrl = 'http://10.0.2.2:8000';

  static const String _keyBackendUrl = 'backend_url';
  static late SharedPreferences _prefs;

  // --- Initialization ---
  // We must call this inside main.dart before the app starts
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Getters & Setters ---
  static String get backendUrl {
    // Force the explicit URL completely ignoring any ghost saved SharedPreferences states.
    return _defaultUrl;
  }

  static Future<void> setBackendUrl(String url) async {
    // Removes trailing slashes to prevent issues like http://url.com//api
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await _prefs.setString(_keyBackendUrl, cleanUrl);
  }

  static Future<void> reset() async {
    await _prefs.remove(_keyBackendUrl);
  }

  // Alias — used throughout the app as AppConfig.baseUrl
  static String get baseUrl => backendUrl;

  // Token storage keys (previously in constants.dart)
  static const tokenKey = 'ssm_access_token';
  static const userRoleKey = 'ssm_user_role';
  static const userIdKey = 'ssm_user_id';
  static const userNameKey = 'ssm_user_name';
  static const deptIdKey = 'ssm_dept_id';
}
