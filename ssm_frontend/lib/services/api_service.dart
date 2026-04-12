import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/constants.dart';
import 'token_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static final _base = Uri.parse(AppConfig.baseUrl);

  // ─── HELPERS ──────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await TokenService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _handle(http.Response res) {
    final body = json.decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401) {
      throw ApiException(401, 'Session expired. Please log in again.');
    }
    final msg = body['detail'] ?? 'Request failed';
    throw ApiException(res.statusCode, msg is String ? msg : msg.toString());
  }

  static Uri _url(String path, [Map<String, String>? params]) {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    return params != null ? uri.replace(queryParameters: params) : uri;
  }

  // ─── AUTH ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(String identifier, String password,
      {bool isStudent = true}) async {
    final res = await http.post(
      _url('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        if (isStudent) 'register_number': identifier else 'email': identifier,
        'password': password,
      }),
    );
    return _handle(res);
  }

  static Future<void> logout() async {
    final headers = await _authHeaders();
    try {
      await http.post(_url('/auth/logout'), headers: headers);
    } catch (_) {}
    await TokenService.clearSession();
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(_url('/auth/me'), headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> payload) async {
    final res = await http.put(
      _url('/auth/profile'),
      headers: await _authHeaders(),
      body: json.encode(payload),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> changePassword(
      String oldPwd, String newPwd) async {
    final res = await http.post(
      _url('/auth/change-password'),
      headers: await _authHeaders(),
      body: json.encode({'old_password': oldPwd, 'new_password': newPwd}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final res = await http.post(
      _url('/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh_token': refreshToken}),
    );
    return _handle(res);
  }

  // ─── STUDENT ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStudentDashboard() async {
    final res = await http.get(_url('/student/dashboard'),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createForm(String academicYear) async {
    final res = await http.post(
      _url('/student/form/create', {'academic_year': academicYear}),
      headers: await _authHeaders(),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getForm(int formId) async {
    final res = await http.get(_url('/student/form/$formId'),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> saveForm(
      int formId, Map<String, dynamic> payload) async {
    final res = await http.put(
      _url('/student/form/$formId/save'),
      headers: await _authHeaders(),
      body: json.encode(payload),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> submitForm(int formId) async {
    final res = await http.post(_url('/student/form/$formId/submit'),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getScore(int formId) async {
    final res = await http.get(_url('/student/form/$formId/score'),
        headers: await _authHeaders());
    return _handle(res);
  }

  /// Form timeline — reuses the score endpoint which has status + remarks.
  static Future<Map<String, dynamic>> getFormTimeline(int formId) async {
    final res = await http.get(_url('/student/form/$formId/score'),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> uploadDocument({
    required int formId,
    required String category,
    required String documentType,
    required File file,
  }) async {
    final token = await TokenService.getToken();
    final request = http.MultipartRequest(
      'POST',
      _url('/student/form/$formId/upload', {'category': category}),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['document_type'] = documentType;

    final ext = file.path.split('.').last.toLowerCase();
    final mimeType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType.parse(mimeType),
    ));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
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
      request.files.add(await http.MultipartFile.fromPath('file', file.path,
          contentType: MediaType.parse(mimeType)));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
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
    final res = await http.get(_url('/activity/my', params),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<void> deleteActivity(int activityId) async {
    final res = await http.delete(_url('/activity/$activityId'),
        headers: await _authHeaders());
    _handle(res);
  }

  static Future<Map<String, dynamic>> getMentorPendingActivities({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await http.get(
      _url('/activity/mentor/pending', {
        'limit': limit.toString(),
        'offset': offset.toString(),
      }),
      headers: await _authHeaders(),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> approveActivity(int activityId,
      {String? note}) async {
    final token = await TokenService.getToken();
    final request = http.MultipartRequest(
        'POST', _url('/activity/mentor/$activityId/approve'));
    request.headers['Authorization'] = 'Bearer $token';
    if (note != null) request.fields['note'] = note;
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> rejectActivity(
      int activityId, String note) async {
    final token = await TokenService.getToken();
    final request = http.MultipartRequest(
        'POST', _url('/activity/mentor/$activityId/reject'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['note'] = note;
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  // ─── MENTOR ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMentorDashboard() async {
    final res = await http.get(_url('/mentor/dashboard'),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMentorFormDetails(int formId) async {
    final res = await http.get(_url('/mentor/form/$formId'),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> submitMentorReview(
      int formId, Map<String, dynamic> payload) async {
    final res = await http.post(
      _url('/mentor/form/$formId/review'),
      headers: await _authHeaders(),
      body: json.encode(payload),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> rejectForm(
      int formId, String reason) async {
    final res = await http.post(
      _url('/mentor/form/$formId/reject', {'reason': reason}),
      headers: await _authHeaders(),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMentorAllStudents({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await http.get(
      _url('/mentor/all-students', {
        'limit': limit.toString(),
        'offset': offset.toString(),
      }),
      headers: await _authHeaders(),
    );
    return _handle(res);
  }

  // ─── HOD ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getHodDashboard() async {
    final res =
        await http.get(_url('/hod/dashboard'), headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getHodFormDetails(int formId) async {
    final res = await http.get(_url('/hod/form/$formId'),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> hodApproveForm(
      int formId, Map<String, dynamic> payload) async {
    final res = await http.post(
      _url('/hod/form/$formId/approve'),
      headers: await _authHeaders(),
      body: json.encode(payload),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getDeptReport(
      [String? academicYear]) async {
    final params =
        academicYear != null ? {'academic_year': academicYear} : null;
    final res = await http.get(_url('/hod/reports/department', params),
        headers: await _authHeaders());
    return _handle(res);
  }

  // ─── ADMIN ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAdminAnalytics(
      [String? academicYear]) async {
    final params =
        academicYear != null ? {'academic_year': academicYear} : null;
    final res = await http.get(_url('/admin/analytics/overview', params),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<List<dynamic>> getTopStudents([String? academicYear]) async {
    final params =
        academicYear != null ? {'academic_year': academicYear} : null;
    final res = await http.get(_url('/admin/analytics/top-students', params),
        headers: await _authHeaders());
    return _handle(res);
  }

  /// Returns paginated users. Result has keys: total, offset, limit, items.
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

    final res = await http.get(_url('/admin/users', params),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createUser(
      Map<String, dynamic> payload) async {
    final res = await http.post(
      _url('/auth/users'),
      headers: await _authHeaders(),
      body: json.encode(payload),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> toggleUserActive(int userId) async {
    final res = await http.put(
      _url('/admin/users/$userId/toggle-active'),
      headers: await _authHeaders(),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> bulkImportUsers(File file) async {
    final token = await TokenService.getToken();
    final request = http.MultipartRequest('POST', _url('/admin/users/import'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType.parse('text/csv'),
    ));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  static Future<List<dynamic>> getDepartments() async {
    final res = await http.get(_url('/admin/departments'),
        headers: await _authHeaders());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createDepartment(
      String name, String code) async {
    final res = await http.post(
      _url('/admin/departments'),
      headers: await _authHeaders(),
      body: json.encode({'name': name, 'code': code}),
    );
    return _handle(res);
  }

  static Future<int> getDepartmentCount() async {
    final res = await http.get(_url('/admin/departments/count'),
        headers: await _authHeaders());
    final data = _handle(res);
    return data['count'] as int;
  }

  static Future<List<Map<String, dynamic>>> getMentors(
      {int? departmentId}) async {
    final params = <String, String>{};
    if (departmentId != null) {
      params['department_id'] = departmentId.toString();
    }
    final res = await http.get(_url('/admin/mentors', params),
        headers: await _authHeaders());
    final list = _handle(res) as List;
    return list.cast<Map<String, dynamic>>();
  }
}
