import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _analytics;
  List<dynamic>? _topStudents;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await Future.wait([
        ApiService.getAdminAnalytics(AppStrings.academicYear),
        ApiService.getTopStudents(AppStrings.academicYear),
      ]);
      setState(() {
        _analytics = res[0] as Map<String, dynamic>;
        _topStudents = res[1] as List<dynamic>;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final starDist = _analytics?['star_distribution'] as Map? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.adminColor,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── STATS GRID ───────────────────────────────
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.6,
                    children: [
                      _AdminStatCard('Total Forms', _analytics?['total_forms']?.toString() ?? '0',
                          Icons.assignment_rounded, AppColors.primary),
                      _AdminStatCard('Approved', _analytics?['approved']?.toString() ?? '0',
                          Icons.check_circle_rounded, AppColors.approved),
                      _AdminStatCard('Pending Mentor', _analytics?['pending_mentor']?.toString() ?? '0',
                          Icons.hourglass_empty_rounded, AppColors.mentorReview),
                      _AdminStatCard('Pending HOD', _analytics?['pending_hod']?.toString() ?? '0',
                          Icons.pending_rounded, AppColors.hodReview),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── AVG SCORE ─────────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                        Column(children: [
                          Text(
                            _analytics?['average_score']?.toString() ?? '0',
                            style: const TextStyle(fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary),
                          ),
                          const Text('Avg Score', style: TextStyle(color: AppColors.textSecondary)),
                        ]),
                        Column(children: [
                          Text(
                            _analytics?['highest_score']?.toStringAsFixed(0) ?? '0',
                            style: const TextStyle(fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success),
                          ),
                          const Text('Highest', style: TextStyle(color: AppColors.textSecondary)),
                        ]),
                        Column(children: [
                          Text(
                            _analytics?['rejected']?.toString() ?? '0',
                            style: const TextStyle(fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.rejected),
                          ),
                          const Text('Rejected', style: TextStyle(color: AppColors.textSecondary)),
                        ]),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── STAR DISTRIBUTION BAR CHART ───────────────
                  if (starDist.isNotEmpty) ...[
                    const Text('Star Rating Distribution',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: ((starDist.values
                                  .map((v) => (v as num).toDouble())
                                  .fold(0.0, (a, b) => a > b ? a : b)) +
                              2),
                          barGroups: [1, 2, 3, 4, 5].map((star) {
                            final colors = [
                              Colors.red,
                              Colors.orange,
                              Colors.yellow.shade700,
                              Colors.lightGreen,
                              Colors.green
                            ];
                            return BarChartGroupData(x: star, barRods: [
                              BarChartRodData(
                                toY: (starDist[star.toString()] as num?)
                                        ?.toDouble() ??
                                    0,
                                color: colors[star - 1],
                                width: 28,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ]);
                          }).toList(),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) =>
                                    Text('${v.toInt()}⭐',
                                        style: const TextStyle(fontSize: 11)),
                              ),
                            ),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── TOP STUDENTS ──────────────────────────────
                  const Text('Top Students',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),

                  ...(_topStudents ?? []).asMap().entries.map((e) {
                    final i = e.key;
                    final s = e.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: i < 3
                              ? [AppColors.starGold, Colors.grey, Colors.brown][i]
                              : AppColors.primary.withOpacity(0.7),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                        ),
                        title: Text(s['student_name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(s['register_number'] ?? '',
                            style: const TextStyle(fontSize: 12)),
                        trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Text(
                            '${(s['grand_total'] as num).toStringAsFixed(0)} pts',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.primary),
                          ),
                          StarRating(stars: s['star_rating'] as int, size: 13),
                        ]),
                      ),
                    );
                  }),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _AdminStatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
      );
}
