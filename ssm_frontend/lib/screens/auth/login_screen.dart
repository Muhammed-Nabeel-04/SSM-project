import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import 'package:ssm_app/screens/admin/backend_settings_screen.dart';

// TODO: Make sure to import your BackendSettingsScreen here!
// import 'path/to/backend_settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _regController = TextEditingController();
  final _pwdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePwd = true;
  bool _isStudent = true; // toggle student vs staff login

  @override
  void dispose() {
    _regController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _regController.text.trim(),
      _pwdController.text,
      isStudent: _isStudent,
    );
    // Navigation handled by GoRouter redirect on role change
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Login failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      // ── SETTINGS APPBAR ──────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.settings_outlined, color: Colors.white),
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => BackendSettingsScreen(),
          //       ),
          //     );
          //   },
          //   tooltip: 'Backend Settings',
          // ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          // ── HEADER ──────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SSM System',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Student Success Matrix',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),

          // ── FORM CARD ────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sign In',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Enter your register number and password',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 24),

                    // Login type toggle
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isStudent = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color:
                                  _isStudent ? AppColors.primary : Colors.white,
                              borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(10)),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Text('Student',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: _isStudent
                                        ? Colors.white
                                        : AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isStudent = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isStudent
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(10)),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Text('Staff / Admin',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: !_isStudent
                                        ? Colors.white
                                        : AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Register number (student) or email (staff)
                    TextFormField(
                      controller: _regController,
                      decoration: InputDecoration(
                        labelText: _isStudent ? 'Register Number' : 'Email',
                        prefixIcon: Icon(_isStudent
                            ? Icons.badge_outlined
                            : Icons.email_outlined),
                      ),
                      textCapitalization: _isStudent
                          ? TextCapitalization.characters
                          : TextCapitalization.none,
                      keyboardType: _isStudent
                          ? TextInputType.text
                          : TextInputType.emailAddress,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    TextFormField(
                      controller: _pwdController,
                      obscureText: _obscurePwd,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePwd
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscurePwd = !_obscurePwd),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 8)
                          ? 'Min 8 characters'
                          : null,
                    ),
                    const SizedBox(height: 8),

                    if (auth.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ErrorBanner(auth.errorMessage!),
                      ),

                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.loading ? null : _login,
                        child: auth.loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Sign In'),
                      ),
                    ),

                    const Spacer(),
                    const Center(
                      child: Text(
                        'Contact admin if you need access',
                        style:
                            TextStyle(color: AppColors.textLight, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
