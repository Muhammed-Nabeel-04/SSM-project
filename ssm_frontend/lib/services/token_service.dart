import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

/// Stores JWT and user metadata in encrypted secure storage.
/// Never stores tokens in SharedPreferences (plain text).
class TokenService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ─── SAVE ──────────────────────────────────────────────────
  static Future<void> saveSession({
    required String token,
    required String role,
    required int userId,
    required String name,
    int? deptId,
  }) async {
    await Future.wait([
      _storage.write(key: AppConfig.tokenKey, value: token),
      _storage.write(key: AppConfig.userRoleKey, value: role),
      _storage.write(key: AppConfig.userIdKey, value: userId.toString()),
      _storage.write(key: AppConfig.userNameKey, value: name),
      _storage.write(key: AppConfig.deptIdKey, value: deptId?.toString() ?? ''),
    ]);
  }

  // ─── READ ──────────────────────────────────────────────────
  static Future<String?> getToken() => _storage.read(key: AppConfig.tokenKey);
  static Future<String?> getRole() => _storage.read(key: AppConfig.userRoleKey);
  static Future<String?> getName() => _storage.read(key: AppConfig.userNameKey);
  static Future<int?> getUserId() async {
    final val = await _storage.read(key: AppConfig.userIdKey);
    return val != null ? int.tryParse(val) : null;
  }
  static Future<int?> getDeptId() async {
    final val = await _storage.read(key: AppConfig.deptIdKey);
    return (val != null && val.isNotEmpty) ? int.tryParse(val) : null;
  }

  // ─── CLEAR (LOGOUT) ────────────────────────────────────────
  static Future<void> clearSession() async {
    await _storage.deleteAll();
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
