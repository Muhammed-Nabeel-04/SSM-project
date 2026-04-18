import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  Map<String, dynamic>? _settings;
  bool _loading = true;
  bool _promoting = false;
  bool _saving = false;
  String? _error;

  final _yearCtrl = TextEditingController();
  int? _selectedSemester;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getSystemSettings();
      setState(() {
        _settings = data;
        _loading = false;
        _yearCtrl.text = data['academic_year'] ?? '';
        _selectedSemester = data['current_semester'] as int?;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.updateSystemSettings(
        academicYear: _yearCtrl.text.trim(),
        currentSemester: _selectedSemester,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Settings saved!'),
        backgroundColor: AppColors.success,
      ));
      _load();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _promoteStudents() async {
    // Step 1 — First confirmation
    final step1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.mentorReview),
          SizedBox(width: 8),
          Text('Promote Students?'),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This will move ALL active students from '
                  'Semester ${_settings?['current_semester']} → '
                  'Semester ${(_settings?['current_semester'] as int? ?? 1) + 1}.'),
              const SizedBox(height: 10),
              const Text('• A new blank form will be created for each student',
                  style: TextStyle(fontSize: 13)),
              const Text('• Old submissions and scores are NEVER deleted',
                  style: TextStyle(fontSize: 13)),
              const Text('• Semester 8 students will be marked as graduated',
                  style: TextStyle(fontSize: 13, color: AppColors.error)),
              const SizedBox(height: 10),
              const Text('This action cannot be undone.',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.error)),
            ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mentorReview),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    // Step 2 — Type PROMOTE to confirm
    final confirmCtrl = TextEditingController();
    final step2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Type PROMOTE to confirm:',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: confirmCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Type PROMOTE',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (confirmCtrl.text.trim() == 'PROMOTE') {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Type PROMOTE exactly to confirm'),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Promote'),
          ),
        ],
      ),
    );
    confirmCtrl.dispose();
    if (step2 != true || !mounted) return;

    // Execute
    setState(() => _promoting = true);
    try {
      final result = await ApiService.promoteStudents();
      final summary = result['summary'] as Map<String, dynamic>;
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success),
              SizedBox(width: 8),
              Text('Promotion Complete!'),
            ]),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New semester: ${result['new_semester']}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Academic year: ${result['new_academic_year']}'),
                  const SizedBox(height: 12),
                  _ResultRow(Icons.arrow_upward_rounded, AppColors.success,
                      '${summary['promoted']} students promoted'),
                  _ResultRow(Icons.school_rounded, AppColors.primary,
                      '${summary['forms_created']} new forms created'),
                  _ResultRow(Icons.emoji_events_rounded, AppColors.mentorReview,
                      '${summary['graduated']} students graduated'),
                ]),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
        _load();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _promoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Settings',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.adminColor,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Current status card ────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.adminColor, Color(0xFFB71C1C)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Academic Period',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(_settings?['academic_year'] ?? '—',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                                'Semester ${_settings?['current_semester'] ?? '—'}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              'Auto-suggested: ${_settings?['auto_academic_year']} '
                              '(${_settings?['semester_period']} period)',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 24),

                    // ── Edit settings ──────────────────────────────────────
                    const Text('Override Settings',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text(
                      'The system auto-detects academic year from date. '
                      'Override only if needed.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _yearCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        hintText: 'e.g. 2025-2026',
                        prefixIcon:
                            Icon(Icons.calendar_today_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                          'Current semester: ${_settings?['current_semester'] ?? 1}  '
                          '→  Year ${(((_settings?['current_semester'] as int? ?? 1) + 1) ~/ 2)}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ErrorBanner(_error!),
                      ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.adminColor),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save Settings'),
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),

                    // ── Promote section ────────────────────────────────────
                    const Text('Student Promotion',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.mentorReview.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.mentorReview.withOpacity(0.3)),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.info_outline_rounded,
                                  color: AppColors.mentorReview, size: 16),
                              SizedBox(width: 8),
                              Text('What happens when you promote:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.mentorReview)),
                            ]),
                            const SizedBox(height: 8),
                            _BulletPoint('All active students → semester +1'),
                            _BulletPoint('New blank form created per student'),
                            _BulletPoint('Old forms & scores kept forever'),
                            _BulletPoint('Semester 8 students → graduated'),
                            _BulletPoint(
                                'Even→odd promotion → academic year increments'),
                          ]),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _promoting ? null : _promoteStudents,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: _promoting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.arrow_upward_rounded),
                        label: Text(
                          _promoting
                              ? 'Promoting...'
                              : 'Promote All Students to Next Semester',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ]),
            ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _ResultRow(this.icon, this.color, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ]),
      );
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(color: AppColors.mentorReview)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))),
        ]),
      );
}
