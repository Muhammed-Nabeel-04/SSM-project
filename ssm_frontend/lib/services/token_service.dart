import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';
import '../core/app_config.dart';

class TokenService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _refreshKey = 'ssm_refresh_token';

  // ─── SAVE ──────────────────────────────────────────────────
  static Future<void> saveSession({
    required String token,
    required String refreshToken,
    required String role,
    required int userId,
    required String name,
    int? deptId,
  }) async {
    await Future.wait([
      _storage.write(key: AppConfig.tokenKey, value: token),
      _storage.write(key: _refreshKey, value: refreshToken),
      _storage.write(key: AppConfig.userRoleKey, value: role),
      _storage.write(key: AppConfig.userIdKey, value: userId.toString()),
      _storage.write(key: AppConfig.userNameKey, value: name),
      _storage.write(key: AppConfig.deptIdKey, value: deptId?.toString() ?? ''),
    ]);
  }

  // ─── READ ──────────────────────────────────────────────────
  static Future<String?> getToken() => _storage.read(key: AppConfig.tokenKey);
  static Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);
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

  // ─── UPDATE (after token refresh) ──────────────────────────
  static Future<void> updateTokens({
    required String token,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: AppConfig.tokenKey, value: token),
      _storage.write(key: _refreshKey, value: refreshToken),
    ]);
  }

  // ─── CLEAR (LOGOUT) ────────────────────────────────────────
  static Future<void> clearSession() => _storage.deleteAll();

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
