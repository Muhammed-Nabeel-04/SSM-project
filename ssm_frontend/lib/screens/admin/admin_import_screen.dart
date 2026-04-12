import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class AdminImportScreen extends StatefulWidget {
  const AdminImportScreen({super.key});

  @override
  State<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends State<AdminImportScreen> {
  File? _file;
  bool _uploading = false;
  Map<String, dynamic>? _result;

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (r?.files.single.path != null) {
      setState(() {
        _file = File(r!.files.single.path!);
        _result = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_file == null) return;
    setState(() {
      _uploading = true;
      _result = null;
    });
    try {
      final res = await ApiService.bulkImportUsers(_file!);
      setState(() {
        _uploading = false;
        _result = res;
      });
    } on ApiException catch (e) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _result?['summary'] as Map?;
    final failed = (_result?['failed'] as List?) ?? [];
    final skipped = (_result?['skipped'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk User Import',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.adminColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── CSV format guide ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CSV Format (header row required)',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary)),
              const SizedBox(height: 8),
              const Text(
                'register_number, name, email, role, phone,\n'
                'department_name, mentor_register_number',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 6),
              _rule('role', 'student | mentor | hod | admin'),
              _rule('phone', 'Required — becomes default password'),
              _rule('department_name', 'Exact name as created in departments'),
              _rule('mentor_register_number',
                  'Required for students — import mentors first'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.mentorReview.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠ Import order matters:\n'
                  '1. Departments  2. Mentors/HODs  3. Students',
                  style: TextStyle(fontSize: 12, color: AppColors.mentorReview),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── File picker ────────────────────────────────────────────────
          GestureDetector(
            onTap: _pick,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _file != null ? AppColors.success : AppColors.divider,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(14),
                color: _file != null
                    ? AppColors.success.withOpacity(0.05)
                    : AppColors.background,
              ),
              child: Column(children: [
                Icon(
                  _file != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  size: 40,
                  color:
                      _file != null ? AppColors.success : AppColors.textLight,
                ),
                const SizedBox(height: 8),
                Text(
                  _file != null
                      ? _file!.path.split('/').last
                      : 'Tap to pick CSV file',
                  style: TextStyle(
                    color: _file != null
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_file == null || _uploading) ? null : _upload,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminColor),
              icon: _uploading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_uploading ? 'Importing...' : 'Import Users'),
            ),
          ),

          // ── Result ─────────────────────────────────────────────────────
          if (summary != null) ...[
            const SizedBox(height: 24),
            const Text('Import Result',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            Row(children: [
              _SummaryBox(
                  'Created', summary['created'].toString(), AppColors.success),
              const SizedBox(width: 8),
              _SummaryBox('Skipped', summary['skipped'].toString(),
                  AppColors.mentorReview),
              const SizedBox(width: 8),
              _SummaryBox(
                  'Failed', summary['failed'].toString(), AppColors.error),
            ]),
            if (skipped.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Skipped (already exist)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.mentorReview)),
              const SizedBox(height: 6),
              ...skipped.map((s) => _ResultRow(s['register_number'] ?? '',
                  s['reason'] ?? '', AppColors.mentorReview)),
            ],
            if (failed.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Failed rows',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.error)),
              const SizedBox(height: 6),
              ...failed.map((f) => _ResultRow(
                  'Row ${f['row']}: ${f['register_number'] ?? ''}',
                  f['reason'] ?? '',
                  AppColors.error)),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _rule(String field, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$field: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: AppColors.primary)),
          Expanded(
              child: Text(desc,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary))),
        ]),
      );
}

class _SummaryBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
      );
}

class _ResultRow extends StatelessWidget {
  final String id, reason;
  final Color color;
  const _ResultRow(this.id, this.reason, this.color);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text('$id — $reason',
                  style: TextStyle(fontSize: 12, color: color))),
        ]),
      );
}
