import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().reloadProfile();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final color = _roleColor(auth.role ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: color,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(
                text: 'Details',
                icon: Icon(Icons.person_outline_rounded, size: 18)),
            Tab(
                text: 'Password',
                icon: Icon(Icons.lock_outline_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: auth.profileNotifier,
            builder: (_, profile, __) => _DetailsTab(
                profile: profile ?? auth.profile, role: auth.role ?? ''),
          ),
          const _PasswordTab(),
        ],
      ),
    );
  }

  Color _roleColor(String role) => switch (role) {
        'student' => AppColors.primary,
        'mentor' => AppColors.mentorColor,
        'hod' => AppColors.hodColor,
        'admin' => AppColors.adminColor,
        _ => AppColors.primary,
      };
}

// ─── DETAILS TAB ──────────────────────────────────────────────────────────────

class _DetailsTab extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final String role;
  const _DetailsTab({this.profile, required this.role});

  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _semCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  bool _saving = false;
  String? _message;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _prefill();
    // If profile not loaded yet, fetch it and prefill when ready
    if (widget.profile == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final data = await ApiService.getMe();
          if (mounted) _prefillFromMap(data);
        } catch (_) {}
      });
    }
  }

  @override
  void didUpdateWidget(_DetailsTab old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile && widget.profile != null) {
      _prefill();
    }
  }

  void _prefill() {
    if (widget.profile == null) return;
    _prefillFromMap(widget.profile!);
  }

  void _prefillFromMap(Map<String, dynamic> p) {
    _phoneCtrl.text = p['phone'] ?? '';
    _emailCtrl.text = p['email'] ?? '';
    _semCtrl.text = (p['semester'] ?? '').toString().replaceAll('null', '');
    _batchCtrl.text = p['batch'] ?? '';
    _yearCtrl.text =
        (p['year_of_study'] ?? '').toString().replaceAll('null', '');
    _sectionCtrl.text = p['section'] ?? '';
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _semCtrl.dispose();
    _batchCtrl.dispose();
    _yearCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final payload = <String, dynamic>{};
      if (_phoneCtrl.text.trim().isNotEmpty)
        payload['phone'] = _phoneCtrl.text.trim();
      if (_emailCtrl.text.trim().isNotEmpty)
        payload['email'] = _emailCtrl.text.trim();

      await ApiService.updateProfile(payload);
      context.read<AuthProvider>().updateProfileLocally(payload);

      setState(() {
        _saving = false;
        _success = true;
        _message = 'Profile updated successfully!';
      });
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _success = false;
        _message = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Avatar + read-only header ──────────────────────────────────────
        Center(
          child: Column(children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(
                (p?['name'] ?? '?').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(p?['name'] ?? '—',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(p?['register_number'] ?? '',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            _RoleBadge(widget.role),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Read-only fields ───────────────────────────────────────────────
        _SectionLabel('Account Info'),
        _ReadOnlyField('Name', p?['name'] ?? '—', Icons.person_rounded),
        _ReadOnlyField('Register Number', p?['register_number'] ?? '—',
            Icons.badge_outlined),
        _ReadOnlyField(
            'Role', widget.role.toUpperCase(), Icons.security_rounded),
        if (p?['department_id'] != null)
          _ReadOnlyField('Department ID', p!['department_id'].toString(),
              Icons.business_rounded),

        const SizedBox(height: 8),
        _SectionLabel('Editable Details'),

        // Email
        _field('Email', _emailCtrl, Icons.email_outlined,
            keyboard: TextInputType.emailAddress),
        // Phone
        _field('Phone Number', _phoneCtrl, Icons.phone_outlined,
            keyboard: TextInputType.phone),

        // Student-only fields — academic info is read-only (set by admin)
        if (widget.role == 'student') ...[
          const SizedBox(height: 4),
          _SectionLabel('Academic Info (set by admin)'),
          _ReadOnlyField(
            'Semester',
            _semCtrl.text.isEmpty ? 'Not set' : 'Semester ${_semCtrl.text}',
            Icons.numbers_rounded,
          ),
          _ReadOnlyField(
            'Year of Study',
            _yearCtrl.text.isEmpty ? 'Not set' : 'Year ${_yearCtrl.text}',
            Icons.school_rounded,
          ),
          _ReadOnlyField(
            'Batch',
            _batchCtrl.text.isEmpty ? 'Not set' : _batchCtrl.text,
            Icons.calendar_today_rounded,
          ),
          _ReadOnlyField(
            'Section',
            _sectionCtrl.text.isEmpty ? 'Not set' : _sectionCtrl.text,
            Icons.group_rounded,
          ),
        ],

        const SizedBox(height: 16),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_success ? AppColors.success : AppColors.error)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: (_success ? AppColors.success : AppColors.error)
                        .withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(
                    _success
                        ? Icons.check_circle_rounded
                        : Icons.warning_rounded,
                    color: _success ? AppColors.success : AppColors.error,
                    size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_message!,
                        style: TextStyle(
                            color:
                                _success ? AppColors.success : AppColors.error,
                            fontSize: 13))),
              ]),
            ),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Save Changes'),
          ),
        ),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

// ─── PASSWORD TAB ─────────────────────────────────────────────────────────────

class _PasswordTab extends StatefulWidget {
  const _PasswordTab();

  @override
  State<_PasswordTab> createState() => _PasswordTabState();
}

class _PasswordTabState extends State<_PasswordTab> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConf = true;
  bool _saving = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_newCtrl.text != _confCtrl.text) {
      setState(() {
        _success = false;
        _message = 'New passwords do not match.';
      });
      return;
    }
    if (_newCtrl.text.length < 8) {
      setState(() {
        _success = false;
        _message = 'Password must be at least 8 characters.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ApiService.changePassword(_oldCtrl.text, _newCtrl.text);
      _oldCtrl.clear();
      _newCtrl.clear();
      _confCtrl.clear();
      setState(() {
        _saving = false;
        _success = true;
        _message = 'Password changed successfully!';
      });
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _success = false;
        _message = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Register number cannot be changed.\nContact admin if you need it updated.',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        _pwdField('Current Password', _oldCtrl, _obscureOld,
            () => setState(() => _obscureOld = !_obscureOld)),
        const SizedBox(height: 14),
        _pwdField('New Password', _newCtrl, _obscureNew,
            () => setState(() => _obscureNew = !_obscureNew)),
        const SizedBox(height: 14),
        _pwdField('Confirm New Password', _confCtrl, _obscureConf,
            () => setState(() => _obscureConf = !_obscureConf)),
        const SizedBox(height: 8),
        const Text('Minimum 8 characters',
            style: TextStyle(color: AppColors.textLight, fontSize: 11)),
        const SizedBox(height: 20),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_success ? AppColors.success : AppColors.error)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: (_success ? AppColors.success : AppColors.error)
                        .withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(
                    _success
                        ? Icons.check_circle_rounded
                        : Icons.warning_rounded,
                    color: _success ? AppColors.success : AppColors.error,
                    size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_message!,
                        style: TextStyle(
                            color:
                                _success ? AppColors.success : AppColors.error,
                            fontSize: 13))),
              ]),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _change,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Change Password'),
          ),
        ),
      ]),
    );
  }

  Widget _pwdField(String label, TextEditingController ctrl, bool obscure,
      VoidCallback toggle) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20),
          onPressed: toggle,
        ),
      ),
    );
  }
}

// ─── SMALL HELPERS ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5)),
      );
}

class _ReadOnlyField extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _ReadOnlyField(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            Text(value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ]),
      );
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge(this.role);

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (role) {
      'student' => (AppColors.studentColor, 'Student'),
      'mentor' => (AppColors.mentorColor, 'Mentor'),
      'hod' => (AppColors.hodColor, 'HOD'),
      'admin' => (AppColors.adminColor, 'Admin'),
      _ => (AppColors.textSecondary, 'Unknown'),
    };
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
