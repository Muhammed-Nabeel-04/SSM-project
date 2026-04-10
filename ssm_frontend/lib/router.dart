import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'services/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/student/ssm_form_screen.dart';
import 'screens/student/score_screen.dart';
import 'screens/student/upload_screen.dart';
import 'screens/mentor/mentor_dashboard.dart';
import 'screens/mentor/mentor_review_screen.dart';
import 'screens/hod/hod_dashboard.dart';
import 'screens/hod/hod_approval_screen.dart';
import 'screens/hod/dept_report_screen.dart';
import 'screens/admin/admin_dashboard.dart';

/// Bridges ChangeNotifier → Listenable so GoRouter re-evaluates
/// redirects whenever AuthProvider fires notifyListeners().
class _AuthNotifierWrapper extends ChangeNotifier {
  _AuthNotifierWrapper(this._auth) {
    _auth.addListener(notifyListeners);
  }

  final AuthProvider _auth;

  @override
  void dispose() {
    _auth.removeListener(notifyListeners);
    super.dispose();
  }
}

GoRouter buildRouter(AuthProvider authProvider) {
  final refreshNotifier = _AuthNotifierWrapper(authProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = authProvider;
      final isLoginPage = state.matchedLocation == '/login';

      if (auth.state == AuthState.unknown) return null;

      if (auth.state == AuthState.unauthenticated) {
        return isLoginPage ? null : '/login';
      }

      // Authenticated — redirect from login to role dashboard
      if (isLoginPage) {
        return switch (auth.role) {
          'student' => '/student/dashboard',
          'mentor'  => '/mentor/dashboard',
          'hod'     => '/hod/dashboard',
          'admin'   => '/admin/dashboard',
          _         => '/login',
        };
      }

      // Role-based path protection
      final path = state.matchedLocation;
      if (path.startsWith('/student') && auth.role != 'student') return '/login';
      if (path.startsWith('/mentor') && auth.role != 'mentor')  return '/login';
      if (path.startsWith('/hod')     && auth.role != 'hod')    return '/login';
      if (path.startsWith('/admin')   && auth.role != 'admin')  return '/login';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),

      // ── STUDENT ──────────────────────────────────────────────
      GoRoute(
        path: '/student/dashboard',
        builder: (c, s) => const StudentDashboard(),
      ),
      GoRoute(
        path: '/student/form/:formId',
        builder: (c, s) =>
            SSMFormScreen(formId: int.parse(s.pathParameters['formId']!)),
      ),
      GoRoute(
        path: '/student/form/:formId/score',
        builder: (c, s) =>
            ScoreScreen(formId: int.parse(s.pathParameters['formId']!)),
      ),
      GoRoute(
        path: '/student/form/:formId/upload',
        builder: (c, s) =>
            UploadScreen(formId: int.parse(s.pathParameters['formId']!)),
      ),

      // ── MENTOR ───────────────────────────────────────────────
      GoRoute(
        path: '/mentor/dashboard',
        builder: (c, s) => const MentorDashboard(),
      ),
      GoRoute(
        path: '/mentor/review/:formId',
        builder: (c, s) =>
            MentorReviewScreen(formId: int.parse(s.pathParameters['formId']!)),
      ),

      // ── HOD ──────────────────────────────────────────────────
      GoRoute(
        path: '/hod/dashboard',
        builder: (c, s) => const HodDashboard(),
      ),
      GoRoute(
        path: '/hod/approval/:formId',
        builder: (c, s) =>
            HodApprovalScreen(formId: int.parse(s.pathParameters['formId']!)),
      ),
      GoRoute(
        path: '/hod/reports',
        builder: (c, s) => const DeptReportScreen(),
      ),

      // ── ADMIN ─────────────────────────────────────────────────
      GoRoute(
        path: '/admin/dashboard',
        builder: (c, s) => const AdminDashboard(),
      ),
    ],
  );
}
