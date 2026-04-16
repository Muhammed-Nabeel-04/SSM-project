import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';

/// Screen for Admin/HOD/Mentor to set up and manage 2FA.
/// Accessible from their profile / settings area.
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  bool _loading = false;
  String? _error;

  // State machine
  _PageState _pageState = _PageState.idle;
  String? _provisioningUri;
  String? _secret;

  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startSetup() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.setup2FA();
      setState(() {
        _provisioningUri = data['provisioning_uri'];
        _secret = data['secret'];
        _pageState = _PageState.scanQR;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _enableTwoFA() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator app.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.enable2FA(code);
      // Reload profile so the in-app is_2fa_enabled reflects the change
      await context.read<AuthProvider>().reloadProfile();
      setState(() { _pageState = _PageState.enabled; });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _disableTwoFA() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter your current 6-digit code to disable 2FA.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.disable2FA(code);
      await context.read<AuthProvider>().reloadProfile();
      setState(() {
        _pageState = _PageState.idle;
        _codeController.clear();
        _provisioningUri = null;
        _secret = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('2FA has been disabled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final is2FAEnabled = profile?['is_2fa_enabled'] == true;

    // Sync state machine with actual server state on first build
    if (_pageState == _PageState.idle && is2FAEnabled) {
      _pageState = _PageState.enabled;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Two-Factor Authentication'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Banner ──────────────────────────────────────────
            _StatusBanner(isEnabled: is2FAEnabled || _pageState == _PageState.enabled),
            const SizedBox(height: 28),

            // ── Page Content ───────────────────────────────────────────
            if (_pageState == _PageState.idle) ...[
              _InfoSection(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _startSetup,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(_loading ? 'Generating...' : 'Set Up 2FA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            if (_pageState == _PageState.scanQR) ...[
              _Step(number: 1, title: 'Install an Authenticator App',
                body: 'Download Google Authenticator, Microsoft Authenticator, or Authy from your app store.'),
              const SizedBox(height: 20),
              _Step(number: 2, title: 'Scan the QR Code or Enter Manually',
                body: 'Open the authenticator app → tap "+" → scan the secret below manually.'),
              const SizedBox(height: 16),
              // Manual secret (since we can't render a QR widget without qr_flutter)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Manual Entry Key',
                        style: TextStyle(color: Colors.white70, fontSize: 11,
                            fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _secret ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _secret ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Secret copied!')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Time-based (TOTP) · SSM System',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _Step(number: 3, title: 'Enter the 6-Digit Code',
                body: 'After adding the account in your authenticator app, enter the code it shows below.'),
              const SizedBox(height: 12),
              _CodeInput(controller: _codeController),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _enableTwoFA,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.verified_user_rounded),
                  label: Text(_loading ? 'Verifying...' : 'Verify & Enable 2FA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06D6A0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            if (_pageState == _PageState.enabled) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF06D6A0).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF06D6A0).withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.shield_rounded, color: Color(0xFF06D6A0), size: 20),
                      SizedBox(width: 8),
                      Text('Your account is secured!',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: Color(0xFF06D6A0))),
                    ]),
                    SizedBox(height: 8),
                    Text('Each time you sign in, you will be asked for your '
                        'authenticator code after entering your password.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text('Disable 2FA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Enter your current authenticator code to remove 2FA from your account.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              _CodeInput(controller: _codeController),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _disableTwoFA,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.no_encryption_gmailerrorred_rounded),
                  label: Text(_loading ? 'Disabling...' : 'Disable 2FA'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _PageState { idle, scanQR, enabled }

// ─── HELPER WIDGETS ──────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final bool isEnabled;
  const _StatusBanner({required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled
            ? const Color(0xFF06D6A0).withOpacity(0.1)
            : Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF06D6A0).withOpacity(0.5)
              : Colors.orange.withOpacity(0.4),
        ),
      ),
      child: Row(children: [
        Icon(
          isEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
          color: isEnabled ? const Color(0xFF06D6A0) : Colors.orange,
          size: 28,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isEnabled ? 'Protected' : 'Not Protected',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isEnabled ? const Color(0xFF06D6A0) : Colors.orange,
              ),
            ),
            Text(
              isEnabled
                  ? '2FA is active on your account'
                  : 'Enable 2FA to secure your staff account',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _InfoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _InfoRow(
        icon: Icons.security_rounded,
        color: AppColors.primary,
        title: 'Extra layer of security',
        body: 'Even if someone knows your password, they cannot access your account without your phone.',
      ),
      const SizedBox(height: 12),
      _InfoRow(
        icon: Icons.timer_rounded,
        color: const Color(0xFF7209B7),
        title: 'Works offline',
        body: 'Codes are generated by your authenticator app. No internet or SMS needed.',
      ),
      const SizedBox(height: 12),
      _InfoRow(
        icon: Icons.phone_android_rounded,
        color: const Color(0xFF06D6A0),
        title: 'Free forever',
        body: 'Works with Google Authenticator, Microsoft Authenticator, or Authy — all free.',
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _InfoRow({required this.icon, required this.color, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
              color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
    ]);
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  const _Step({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 28, height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Text('$number',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
              color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
    ]);
  }
}

class _CodeInput extends StatelessWidget {
  final TextEditingController controller;
  const _CodeInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 14,
        color: AppColors.textPrimary,
      ),
      decoration: const InputDecoration(
        hintText: '000000',
        hintStyle: TextStyle(letterSpacing: 14, fontSize: 28, color: AppColors.textLight),
        counterText: '',
        contentPadding: EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
