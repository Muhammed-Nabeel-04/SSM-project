import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:async'; // ✅ ADD THIS if not present
import 'dart:io'; // ✅ Should already be there

import '../config/constants.dart';
import 'token_service.dart';
import '../core/app_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static final _base = Uri.parse(AppConfig.baseUrl);
  static const _kTimeout = Duration(seconds: 30);

  static Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      http.get(url, headers: headers).timeout(_kTimeout);
  static Future<http.Response> _post(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      http.post(url, headers: headers, body: body).timeout(_kTimeout);
  static Future<http.Response> _put(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      http.put(url, headers: headers, body: body).timeout(_kTimeout);
  static Future<http.Response> _del(Uri url, {Map<String, String>? headers}) =>
      http.delete(url, headers: headers).timeout(_kTimeout);

  // ─── HELPERS ──────────────────────────────────────────────

  static const _timeout = Duration(seconds: 30);

  static Future<Map<String, String>> _authHeaders() async {
    final token = await TokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _handle(http.Response res) {
    dynamic body;
    try {
      body = json.decode(res.body);
    } on FormatException {
      throw ApiException(500,
          'Server error: Invalid response format. Please try again later.');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401) {
      throw ApiException(401, 'Invalid credentials or session expired.');
    }
    final msg = body['detail'] ?? 'Request failed';
    throw ApiException(res.statusCode, msg is String ? msg : msg.toString());
  }

  static Uri _url(String path, [Map<String, String>? params]) {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    return params != null ? uri.replace(queryParameters: params) : uri;
  }

  static ApiException _timeoutError() =>
      ApiException(408, 'Connection timed out. Check your internet.');

  // ─── AUTH ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
    String identifier,
    String password, {
    bool isStudent = true,
  }) async {
    try {
      final res = await http
          .post(
            _url('/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: json.encode({
              if (isStudent)
                'register_number': identifier
              else
                'email': identifier,
              'password': password,
            }),
          )
          .timeout(_timeout, onTimeout: () => throw _timeoutError());
      return _handle(res);
    } on SocketException catch (e) {
      if (e.message.contains('Failed host lookup')) {
        throw ApiException(
            503, 'Cannot reach server. Check your internet connection.');
      }
      throw ApiException(
          503, 'No internet connection. Please check your network.');
    } on HandshakeException {
      throw ApiException(
          495, 'Security error. Try enabling VPN or use mobile data.');
    } on TimeoutException {
      throw ApiException(408,
          'Connection too slow. Please try again or use a different network.');
    } on FormatException {
      throw ApiException(
          500, 'Server returned invalid response. Please try again later.');
    } on HttpException catch (e) {
      throw ApiException(500, 'Connection error: ${e.message}');
    }
  }

  static Future<void> logout() async {
    final headers = await _authHeaders();
    try {
      await http
          .post(_url('/auth/logout'), headers: headers)
          .timeout(_timeout, onTimeout: () => throw _timeoutError());
    } catch (_) {}
    await TokenService.clearSession();
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http
        .get(_url('/auth/me'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> payload,
  ) async {
    final res = await http
        .put(
          _url('/auth/profile'),
          headers: await _authHeaders(),
          body: json.encode(payload),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> changePassword(
    String oldPwd,
    String newPwd,
  ) async {
    final res = await http
        .post(
          _url('/auth/change-password'),
          headers: await _authHeaders(),
          body: json.encode({'old_password': oldPwd, 'new_password': newPwd}),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final res = await http
        .post(
          _url('/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'refresh_token': refreshToken}),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  // ─── STUDENT ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStudentDashboard() async {
    final res = await http
        .get(_url('/student/dashboard'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> submitForm(int formId) async {
    final res = await http
        .post(
          _url('/student/form/$formId/submit'),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getScore(int formId) async {
    final res = await http
        .get(_url('/student/form/$formId/score'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getFormTimeline(int formId) async {
    final res = await http
        .get(_url('/student/form/$formId/score'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  // ─── ACTIVITIES ───────────────────────────────────────────

  static Future<Map<String, dynamic>> submitActivity({
    required Map<String, String> fields,
    File? file,
  }) async {
    final token = await TokenService.getToken();
    final request = http.MultipartRequest('POST', _url('/activity/submit'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    if (file != null) {
      final ext = file.path.split('.').last.toLowerCase();
      final mimeType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType.parse(mimeType),
        ),
      );
    }

    // Multipart requests need timeout on the send and stream conversion
    final streamed = await request.send().timeout(
          _timeout,
          onTimeout: () => throw _timeoutError(),
        );
    final res = await http.Response.fromStream(
      streamed,
    ).timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMyActivities({
    String? category,
    String? mentorStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (category != null) params['category'] = category;
    if (mentorStatus != null) params['mentor_status'] = mentorStatus;
    final res = await http
        .get(_url('/activity/my', params), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<void> deleteActivity(int activityId) async {
    final res = await http
        .delete(_url('/activity/$activityId'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    _handle(res);
  }

  static Future<void> restoreActivity(int activityId) async {
    final res = await http
        .post(_url('/activity/$activityId/restore'),
            headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    _handle(res);
  }

  static Future<Map<String, dynamic>> getMentorPendingActivities({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await http
        .get(
          _url('/activity/mentor/pending', {
            'limit': limit.toString(),
            'offset': offset.toString(),
          }),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> approveActivity(
    int activityId, {
    String? note,
  }) async {
    final token = await TokenService.getToken();
    final request = http.MultipartRequest(
      'POST',
      _url('/activity/mentor/$activityId/approve'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    if (note != null) request.fields['note'] = note;
    final streamed = await request.send().timeout(
          _timeout,
          onTimeout: () => throw _timeoutError(),
        );
    final res = await http.Response.fromStream(
      streamed,
    ).timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> rejectActivity(
    int activityId,
    String note,
  ) async {
    final token = await TokenService.getToken();
    final request = http.MultipartRequest(
      'POST',
      _url('/activity/mentor/$activityId/reject'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['note'] = note;
    final streamed = await request.send().timeout(
          _timeout,
          onTimeout: () => throw _timeoutError(),
        );
    final res = await http.Response.fromStream(
      streamed,
    ).timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  // ─── MENTOR ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMentorDashboard() async {
    final res = await http
        .get(_url('/mentor/dashboard'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMentorFormDetails(int formId) async {
    final res = await http
        .get(_url('/mentor/form/$formId'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> submitMentorReview(
    int formId,
    Map<String, dynamic> payload,
  ) async {
    final res = await http
        .post(
          _url('/mentor/form/$formId/review'),
          headers: await _authHeaders(),
          body: json.encode(payload),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> rejectForm(
    int formId,
    String reason,
  ) async {
    final res = await http
        .post(
          _url('/mentor/form/$formId/reject', {'reason': reason}),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMentorAllStudents({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await http
        .get(
          _url('/mentor/all-students', {
            'limit': limit.toString(),
            'offset': offset.toString(),
          }),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  // ─── HOD ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getHodDashboard() async {
    final res = await http
        .get(_url('/hod/dashboard'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getHodFormDetails(int formId) async {
    final res = await http
        .get(_url('/hod/form/$formId'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> hodApproveForm(
    int formId,
    Map<String, dynamic> payload,
  ) async {
    final res = await http
        .post(
          _url('/hod/form/$formId/approve'),
          headers: await _authHeaders(),
          body: json.encode(payload),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getDeptReport([
    String? academicYear,
  ]) async {
    final params =
        academicYear != null ? {'academic_year': academicYear} : null;
    final res = await http
        .get(
          _url('/hod/reports/department', params),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  // ─── ADMIN ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAdminAnalytics([
    String? academicYear,
  ]) async {
    final params =
        academicYear != null ? {'academic_year': academicYear} : null;
    final res = await http
        .get(
          _url('/admin/analytics/overview', params),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getTopStudents([
    String? academicYear,
  ]) async {
    final params =
        academicYear != null ? {'academic_year': academicYear} : null;
    final res = await http
        .get(
          _url('/admin/analytics/top-students', params),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getUsers({
    String? role,
    int? departmentId,
    bool? isActive,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (role != null) params['role'] = role;
    if (departmentId != null) params['department_id'] = departmentId.toString();
    if (isActive != null) params['is_active'] = isActive.toString();

    final res = await http
        .get(_url('/admin/users', params), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createUser(
    Map<String, dynamic> payload,
  ) async {
    final res = await http
        .post(
          _url('/auth/users'),
          headers: await _authHeaders(),
          body: json.encode(payload),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> toggleUserActive(int userId) async {
    final res = await http
        .put(
          _url('/admin/users/$userId/toggle-active'),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> bulkImportUsers(File file) async {
    final token = await TokenService.getToken();
    final request = http.MultipartRequest('POST', _url('/admin/users/import'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse('text/csv'),
      ),
    );
    final streamed = await request.send().timeout(
          _timeout,
          onTimeout: () => throw _timeoutError(),
        );
    final res = await http.Response.fromStream(
      streamed,
    ).timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<List<dynamic>> getDepartments() async {
    final res = await http
        .get(_url('/admin/departments'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createDepartment(
    String name,
    String code,
  ) async {
    final res = await http
        .post(
          _url('/admin/departments'),
          headers: await _authHeaders(),
          body: json.encode({'name': name, 'code': code}),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<int> getDepartmentCount() async {
    final res = await http
        .get(_url('/admin/departments/count'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    final data = _handle(res);
    return data['count'] as int;
  }

  static Future<List<Map<String, dynamic>>> getMentors({
    int? departmentId,
  }) async {
    final params = <String, String>{};
    if (departmentId != null) params['department_id'] = departmentId.toString();
    final res = await http
        .get(_url('/admin/mentors', params), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    final list = _handle(res) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getSystemSettings() async {
    final res = await http
        .get(_url('/settings/current'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> updateSystemSettings({
    String? academicYear,
    int? currentSemester,
  }) async {
    final params = <String, String>{};
    if (academicYear != null) params['academic_year'] = academicYear;
    if (currentSemester != null)
      params['current_semester'] = currentSemester.toString();
    final res = await http
        .put(_url('/settings/update', params), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> promoteStudents() async {
    final res = await http
        .post(_url('/settings/promote'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  // ─── 2FA ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> setup2FA() async {
    final res = await http
        .post(_url('/auth/2fa/setup'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> enable2FA(String code) async {
    final res = await http
        .post(
          _url('/auth/2fa/enable', {'code': code}),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> disable2FA(String code) async {
    final res = await http
        .post(
          _url('/auth/2fa/disable', {'code': code}),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> loginWith2FA({
    required int userId,
    required String code,
  }) async {
    final res = await http.post(
      _url('/auth/login/2fa', {'user_id': userId.toString(), 'code': code}),
      headers: {'Content-Type': 'application/json'},
    ).timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  // ─── CSV IMPORT JOB STATUS ────────────────────────────────

  static Future<Map<String, dynamic>> getImportJobStatus(String jobId) async {
    final res = await http
        .get(_url('/admin/users/import/$jobId'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  // ─── NOTIFICATIONS ────────────────────────────────────────

  static Future<List<dynamic>> getNotifications() async {
    final res = await http
        .get(_url('/notifications/'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getUnreadCount() async {
    final res = await http
        .get(_url('/notifications/unread-count'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    return _handle(res);
  }

  static Future<void> markNotificationRead(int id) async {
    final res = await http
        .put(_url('/notifications/$id/read'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    _handle(res);
  }

  static Future<void> markAllNotificationsRead() async {
    final res = await http
        .put(_url('/notifications/read-all'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    _handle(res);
  }

  static Future<void> deleteNotification(int id) async {
    final res = await http
        .delete(_url('/notifications/$id'), headers: await _authHeaders())
        .timeout(_timeout, onTimeout: () => throw _timeoutError());
    _handle(res);
  }
}
