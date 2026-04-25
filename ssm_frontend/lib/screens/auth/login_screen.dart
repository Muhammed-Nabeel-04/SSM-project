import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import 'two_factor_login_screen.dart';

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

  // 4 role options: 0=student, 1=mentor, 2=hod, 3=admin
  int _selectedRole = 0;

  static const _roles = [
    _RoleOption('Student', Icons.school_rounded, Color(0xFF4361EE),
        isStudent: true),
    _RoleOption('Mentor', Icons.supervisor_account_rounded, Color(0xFF7209B7),
        isStudent: false),
    _RoleOption('HOD', Icons.admin_panel_settings_rounded, Color(0xFF3A86FF),
        isStudent: false),
    _RoleOption('Admin', Icons.manage_accounts_rounded, Color(0xFF06D6A0),
        isStudent: false),
  ];

  bool get _isStudent => _selectedRole == 0;

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
    if (!mounted) return;

    // 2FA required — push the code entry screen
    if (!success && auth.requires2FA) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TwoFactorLoginScreen(
            userId: auth.pendingTwoFactorUserId!,
            userName: auth.pendingTwoFactorUserName ?? 'User',
            role: auth.pendingTwoFactorRole ?? 'staff',
            deptId: auth.pendingTwoFactorDeptId,
          ),
        ),
      );
      return;
    }

    if (!success) {
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
    final role = _roles[_selectedRole];

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(children: [
          // ── HEADER ────────────────────────────────────────────
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
                      color: Colors.white.withValues(alpha: 0.15),
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

          // ── FORM CARD ──────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sign In',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Select your role to continue',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 20),

                      // ── ROLE SELECTOR (4 cards) ──────────────────
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.8,
                        children: List.generate(_roles.length, (i) {
                          final r = _roles[i];
                          final selected = _selectedRole == i;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedRole = i;
                              _regController.clear();
                              _pwdController.clear();
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: selected
                                    ? r.color
                                    : r.color.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: r.color
                                        .withValues(alpha: selected ? 1 : 0.25),
                                    width: selected ? 2 : 1),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(children: [
                                Icon(r.icon,
                                    color: selected ? Colors.white : r.color,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(r.label,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color:
                                            selected ? Colors.white : r.color)),
                              ]),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // ── IDENTIFIER FIELD ────────────────────────
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

                      // ── PASSWORD FIELD ───────────────────────────
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
                        child: ElevatedButton.icon(
                          onPressed: auth.loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: role.color),
                          icon: auth.loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Icon(role.icon, size: 18),
                          label: auth.loading
                              ? const Text('Signing in...')
                              : Text('Sign in as ${role.label}'),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'Contact admin if you need access',
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RoleOption {
  final String label;
  final IconData icon;
  final Color color;
  final bool isStudent;
  const _RoleOption(this.label, this.icon, this.color,
      {required this.isStudent});
}
