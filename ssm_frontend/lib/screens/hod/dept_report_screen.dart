// ════════════════════════════════════════════════
// dept_report_screen.dart
// ════════════════════════════════════════════════
import 'package:flutter/material.dart';
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

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await ApiService.getDeptReport(AppStrings.academicYear);
      setState(() { _data = d; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final students = (_data?['students'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Department Report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Summary row
                Row(children: [
                  Expanded(child: _StatCard('Total', _data?['total_forms']?.toString() ?? '0', AppColors.hodColor)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard('Approved', _data?['approved']?.toString() ?? '0', AppColors.approved)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard('⭐×5', _data?['five_star']?.toString() ?? '0', AppColors.starGold)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard('Avg', _data?['average_score']?.toString() ?? '0', AppColors.academic)),
                ]),
                const SizedBox(height: 20),

                // Student list
                ...students.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: AppColors.hodColor,
                        child: Icon(Icons.person_rounded, color: Colors.white, size: 18)),
                    title: Text(s['student_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(s['register_number'] ?? '',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(s['grand_total']?.toStringAsFixed(0) ?? '0',
                          style: const TextStyle(fontWeight: FontWeight.w800,
                              fontSize: 16, color: AppColors.primary)),
                      StarRating(stars: s['star_rating'] ?? 0, size: 12),
                    ]),
                  ),
                )),
              ]),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]),
  );
}
