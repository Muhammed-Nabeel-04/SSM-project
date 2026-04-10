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

  AuthState get state => _state;
  String? get role => _role;
  String? get name => _name;
  int? get userId => _userId;
  int? get deptId => _deptId;
  String? get errorMessage => _errorMessage;
  bool get loading => _loading;

  bool get isStudent => _role == 'student';
  bool get isMentor => _role == 'mentor';
  bool get isHod => _role == 'hod';
  bool get isAdmin => _role == 'admin';

  /// Called on app start — restores session if token exists
  Future<void> checkSession() async {
    final hasToken = await TokenService.hasToken();
    if (hasToken) {
      _role = await TokenService.getRole();
      _name = await TokenService.getName();
      _userId = await TokenService.getUserId();
      _deptId = await TokenService.getDeptId();
      _state = AuthState.authenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String registerNumber, String password) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiService.login(registerNumber, password);
      await TokenService.saveSession(
        token: data['access_token'],
        role: data['role'],
        userId: data['user_id'],
        name: data['name'],
        deptId: data['department_id'],
      );
      _role = data['role'];
      _name = data['name'];
      _userId = data['user_id'];
      _deptId = data['department_id'];
      _state = AuthState.authenticated;
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _loading = false;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Connection failed. Check server.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    _state = AuthState.unauthenticated;
    _role = null;
    _name = null;
    _userId = null;
    _deptId = null;
    notifyListeners();
  }
}
