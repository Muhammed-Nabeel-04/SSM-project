import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.unknown;
  String? _role;
  String? _name;
  int? _userId;
  int? _deptId;
  String? _errorMessage;
  bool _loading = false;
  bool mustChangePassword = false;

  // ── 2FA pending state ──
  bool requires2FA = false;
  int? pendingTwoFactorUserId;
  String? pendingTwoFactorUserName;
  String? pendingTwoFactorRole;
  int? pendingTwoFactorDeptId;

  // Full profile — populated after login via /auth/me
  Map<String, dynamic>? _profile;

  AuthState get state => _state;
  String? get role => _role;
  String? get name => _name;
  int? get userId => _userId;
  int? get deptId => _deptId;
  String? get errorMessage => _errorMessage;
  bool get loading => _loading;
  Map<String, dynamic>? get profile => _profile;

  bool get isStudent => _role == 'student';
  bool get isMentor => _role == 'mentor';
  bool get isHod => _role == 'hod';
  bool get isAdmin => _role == 'admin';

  // ─── SESSION RESTORE ──────────────────────────────────────
  Future<void> checkSession() async {
    final hasToken = await TokenService.hasToken();
    if (hasToken) {
      _role = await TokenService.getRole();
      _name = await TokenService.getName();
      _userId = await TokenService.getUserId();
      _deptId = await TokenService.getDeptId();
      _state = AuthState.authenticated;
      _fetchProfile(); // non-blocking
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // ─── LOGIN ────────────────────────────────────────────────
  Future<bool> login(String identifier, String password,
      {bool isStudent = true}) async {
    _loading = true;
    _errorMessage = null;
    requires2FA = false;
    notifyListeners();

    try {
      final data =
          await ApiService.login(identifier, password, isStudent: isStudent);

      // ── 2FA check ─────────────────────────────────────────────
      if (data['requires_2fa'] == true) {
        requires2FA = true;
        pendingTwoFactorUserId = data['user_id'];
        pendingTwoFactorUserName = data['name'];
        pendingTwoFactorRole = data['role'];
        pendingTwoFactorDeptId = data['department_id'];
        _loading = false;
        notifyListeners();
        return false; // caller will push TwoFactorLoginScreen
      }

      await TokenService.saveSession(
        token: data['access_token'],
        refreshToken: data['refresh_token'] ?? '',
        role: data['role'],
        userId: data['user_id'],
        name: data['name'],
        deptId: data['department_id'],
      );
      _role = data['role'];
      _name = data['name'];
      _userId = data['user_id'];
      _deptId = data['department_id'];
      mustChangePassword = data['must_change_password'] ?? false;
      _state = AuthState.authenticated;
      _loading = false;
      notifyListeners();
      _fetchProfile();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _loading = false;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection failed. Please try again.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── 2FA SECOND STEP ──────────────────────────────────────
  Future<bool> loginWith2FA({required int userId, required String code}) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await ApiService.loginWith2FA(userId: userId, code: code);
      await TokenService.saveSession(
        token: data['access_token'],
        refreshToken: data['refresh_token'] ?? '',
        role: data['role'],
        userId: data['user_id'],
        name: data['name'],
        deptId: data['department_id'],
      );
      _role = data['role'];
      _name = data['name'];
      _userId = data['user_id'];
      _deptId = data['department_id'];
      mustChangePassword = data['must_change_password'] ?? false;
      requires2FA = false;
      pendingTwoFactorUserId = null;
      _state = AuthState.authenticated;
      _loading = false;
      notifyListeners();
      _fetchProfile();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Verification failed. Please try again.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── REFRESH TOKEN ────────────────────────────────────────
  Future<bool> refreshToken() async {
    final refreshTok = await TokenService.getRefreshToken();
    if (refreshTok == null || refreshTok.isEmpty) return false;
    try {
      final data = await ApiService.refreshToken(refreshTok);
      await TokenService.updateTokens(
        token: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  // ─── PROFILE ──────────────────────────────────────────────
  // Separate notifier for profile — GoRouter only listens to AuthProvider,
  // so profile updates won't trigger redirect re-evaluation.
  final profileNotifier = ValueNotifier<Map<String, dynamic>?>(null);

  Future<void> _fetchProfile() async {
    try {
      _profile = await ApiService.getMe();
      profileNotifier.value = _profile; // ← notify listeners so ProfileScreen updates
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Try refresh token first before logging out
        final refreshed = await refreshToken();
        if (refreshed) {
          // Retry profile fetch with new token
          try {
            _profile = await ApiService.getMe();
            profileNotifier.value = _profile; // ← update after retry too
          } catch (_) {}
        } else {
          // Refresh failed — session truly expired, logout silently
          _state = AuthState.unauthenticated;
          _role = null;
          _profile = null;
          profileNotifier.value = null;
          await TokenService.clearSession();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> reloadProfile() => _fetchProfile();

  void updateProfileLocally(Map<String, dynamic> updates) {
    if (_profile != null) {
      _profile = {..._profile!, ...updates};
      profileNotifier.value = _profile; // keep notifier in sync
      // Silent update — no router re-eval needed
    }
  }

  /// Call this after student/mentor completes their first-login profile setup
  /// (or after admin saves departments). Clears the mustChangePassword flag
  /// so the router no longer redirects to /profile or /setup.
  void clearMustChangePassword() {
    mustChangePassword = false;
    notifyListeners();
  }

  // ─── LOGOUT ───────────────────────────────────────────────
  Future<void> logout() async {
    await ApiService.logout();
    _state = AuthState.unauthenticated;
    _role = null;
    _name = null;
    _userId = null;
    _deptId = null;
    _profile = null;
    notifyListeners();
  }
}
