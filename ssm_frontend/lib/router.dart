import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/constants.dart'; // Added to ensure AppColors and AppConfig are accessible
import 'services/auth_provider.dart';
import 'screens/auth/login_screen.dart';

// Student
import 'screens/student/activity_dashboard.dart';
import 'screens/student/add_activity_screen.dart';
import 'screens/student/score_screen.dart';
import 'screens/student/form_timeline_screen.dart';

// Mentor
import 'screens/mentor/mentor_dashboard.dart';
import 'screens/mentor/mentor_review_screen.dart';
import 'screens/mentor/mentor_activity_screen.dart';

// HOD
import 'screens/hod/hod_dashboard.dart';
import 'screens/hod/hod_approval_screen.dart';
import 'screens/hod/dept_report_screen.dart';

// Admin
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/admin/admin_create_user_screen.dart';
import 'screens/admin/admin_import_screen.dart';

// Shared
import 'screens/shared/profile_screen.dart';
import 'screens/auth/first_setup_screen.dart';

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
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = authProvider;
      final isSplash = state.matchedLocation == '/splash';

      if (auth.state == AuthState.unknown) {
        return isSplash ? null : '/splash';
      }
      final isLoginPage = state.matchedLocation == '/login';

      if (auth.state == AuthState.unauthenticated) {
        return isLoginPage ? null : '/login';
      }

      if (isLoginPage) {
        return switch (auth.role) {
          'student' => '/student/dashboard',
          'mentor' => '/mentor/dashboard',
          'hod' => '/hod/dashboard',
          'admin' => '/admin/dashboard',
          _ => '/login',
        };
      }

      // Role-based path protection
      final path = state.matchedLocation;
      if (path == '/profile') return null;
      if (path == '/setup') return null;
      if (path == '/splash') return null;
      if (path.startsWith('/student') && auth.role != 'student')
        return '/login';
      if (path.startsWith('/mentor') && auth.role != 'mentor') return '/login';
      if (path.startsWith('/hod') && auth.role != 'hod') return '/login';
      if (path.startsWith('/admin') && auth.role != 'admin') return '/login';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (c, s) => const Scaffold(
          backgroundColor: AppColors.primary,
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.school_rounded, color: Colors.white, size: 64),
              SizedBox(height: 20),
              Text('SSM System',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Student Success Matrix',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              SizedBox(height: 40),
              CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            ]),
          ),
        ),
      ),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/setup', builder: (c, s) => const FirstSetupScreen()),

      // ── PROFILE (all roles) ────────────────────────────────────────────
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),

      // ── STUDENT ───────────────────────────────────────────────────────
      GoRoute(
        path: '/student/dashboard',
        builder: (c, s) => const ActivityDashboard(),
      ),
      GoRoute(
        path: '/student/add-activity',
        builder: (c, s) => const AddActivityScreen(),
      ),
      GoRoute(
        path: '/student/form/:formId/score',
        builder: (c, s) =>
            ScoreScreen(formId: int.parse(s.pathParameters['formId']!)),
      ),
      GoRoute(
        path: '/student/form/:formId/timeline',
        builder: (c, s) =>
            FormTimelineScreen(formId: int.parse(s.pathParameters['formId']!)),
      ),

      // ── MENTOR ────────────────────────────────────────────────────────
      GoRoute(
        path: '/mentor/dashboard',
        builder: (c, s) => const MentorDashboard(),
      ),
      GoRoute(
        path: '/mentor/activities',
        builder: (c, s) => const MentorActivityScreen(),
      ),
      GoRoute(
        path: '/mentor/activity/:activityId/file',
        builder: (c, s) => _ActivityFileViewer(
          activityId: int.parse(s.pathParameters['activityId']!),
        ),
      ),
      GoRoute(
        path: '/mentor/review/:formId',
        builder: (c, s) =>
            MentorReviewScreen(formId: int.parse(s.pathParameters['formId']!)),
      ),

      // ── HOD ───────────────────────────────────────────────────────────
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

      // ── ADMIN ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/admin/dashboard',
        builder: (c, s) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (c, s) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin/create-user',
        builder: (c, s) => const AdminCreateUserScreen(),
      ),
      GoRoute(
        path: '/admin/import',
        builder: (c, s) => const AdminImportScreen(),
      ),
    ],
  );
}

class _ActivityFileViewer extends StatelessWidget {
  final int activityId;
  const _ActivityFileViewer({required this.activityId});

  @override
  Widget build(BuildContext context) {
    final url = '${AppConfig.baseUrl}/activity/$activityId/file';
    return Scaffold(
      appBar: AppBar(title: const Text('View Document')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.picture_as_pdf_rounded,
              size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text('Open document in browser:',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Open Document'),
            onPressed: () async {
              final uri = Uri.parse(url);
              // ignore: deprecated_member_use
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ]),
      ),
    );
  }
}
