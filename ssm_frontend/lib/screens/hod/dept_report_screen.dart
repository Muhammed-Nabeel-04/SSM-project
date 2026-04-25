import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class DeptReportScreen extends StatefulWidget {
  const DeptReportScreen({super.key});

  @override
  State<DeptReportScreen> createState() => _DeptReportScreenState();
}

class _DeptReportScreenState extends State<DeptReportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await ApiService.getDeptReport(AppStrings.academicYear);
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ── CSV EXPORT ────────────────────────────────────────────────────────────
  Future<void> _exportCsv() async {
    final students = (_data?['students'] as List?) ?? [];
    if (students.isEmpty) return;

    setState(() => _exporting = true);
    try {
      final sb = StringBuffer();
      // Header
      sb.writeln(
          'Rank,Name,Register Number,Grand Total,Star Rating,Status,Academic Year');
      for (int i = 0; i < students.length; i++) {
        final s = students[i];
        sb.writeln([
          i + 1,
          '"${s['student_name'] ?? ''}"',
          s['register_number'] ?? '',
          s['grand_total']?.toStringAsFixed(2) ?? '0',
          s['star_rating'] ?? '0',
          s['status'] ?? '',
          s['academic_year'] ?? AppStrings.academicYear,
        ].join(','));
      }

      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/dept_report_${AppStrings.academicYear}.csv');
      await file.writeAsString(sb.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Department SSM Report ${AppStrings.academicYear}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error));
    } finally {
      setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = (_data?['students'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Department Report',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.hodColor,
        actions: [
          if (!_loading && students.isNotEmpty)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download_rounded),
              tooltip: 'Export CSV',
              onPressed: _exporting ? null : _exportCsv,
            ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // ── Summary row ───────────────────────────────────────────
                Row(children: [
                  Expanded(
                      child: _StatCard(
                          'Total',
                          _data?['total_forms']?.toString() ?? '0',
                          AppColors.hodColor)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _StatCard(
                          'Approved',
                          _data?['approved']?.toString() ?? '0',
                          AppColors.approved)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _StatCard(
                          '⭐×5',
                          _data?['five_star']?.toString() ?? '0',
                          AppColors.starGold)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _StatCard(
                          'Avg',
                          (_data?['average_score'] ?? 0).toStringAsFixed(1),
                          AppColors.academic)),
                ]),
                const SizedBox(height: 20),

                // ── Student list ──────────────────────────────────────────
                if (students.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No approved forms yet.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ...students.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _rankColor(i + 1).withValues(alpha: 0.15),
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _rankColor(i + 1))),
                        ),
                        title: Text(s['student_name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(s['register_number'] ?? '',
                            style: const TextStyle(fontSize: 12)),
                        trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                (s['grand_total'] ?? 0).toStringAsFixed(0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: AppColors.primary),
                              ),
                              StarRating(
                                  stars: s['star_rating'] ?? 0, size: 13),
                            ]),
                      ),
                    );
                  }),
              ]),
            ),
    );
  }

  Color _rankColor(int rank) => switch (rank) {
        1 => const Color(0xFFFFD700),
        2 => const Color(0xFFC0C0C0),
        3 => const Color(0xFFCD7F32),
        _ => AppColors.primary,
      };
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}
