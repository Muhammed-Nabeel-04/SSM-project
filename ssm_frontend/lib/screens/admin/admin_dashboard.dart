import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/offline_wrapper.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/notification_bell.dart';

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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = (_analytics == null);
    });
    try {
      // First-time setup check
      try {
        final deptCount = await ApiService.getDepartmentCount();
        if (deptCount <= 1 && mounted) {
          context.go('/setup');
          return;
        }
      } catch (_) {} // don't block dashboard if this fails

      final res = await Future.wait([
        ApiService.getAdminAnalytics(AppStrings.academicYear),
        ApiService.getTopStudents(AppStrings.academicYear),
      ]);
      final topData = res[1] as Map<String, dynamic>;
      setState(() {
        _analytics = res[0] as Map<String, dynamic>;
        _topStudents = (topData['items'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final starDist = _analytics?['star_distribution'] as Map? ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.adminColor,
        elevation: 0,
        actions: [
          const NotificationBell(iconColor: Colors.white),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                auth.logout();
              }
            },
          ),
        ],
      ),
      body: OfflineWrapper(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── HEADER BANNER ─────────────────────────────────
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: AppColors.adminColor,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(28),
                            bottomRight: Radius.circular(28),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white.withOpacity(0.25),
                              child: Text(
                                (auth.name ?? 'A')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(auth.name ?? 'Admin',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700)),
                                const Text('System Administrator',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                        child: Text('Quick Actions',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF1A1A2E))),
                      ),

                      // ── QUICK ACTIONS GRID ────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.55,
                          children: [
                            _QuickActionCard(
                              icon: Icons.manage_accounts_rounded,
                              label: 'User Management',
                              subtitle: 'Add, edit & manage users',
                              color: const Color(0xFF4361EE),
                              onTap: () => context.push('/admin/users'),
                            ),
                            _QuickActionCard(
                              icon: Icons.apartment_rounded,
                              label: 'Departments',
                              subtitle: 'Manage departments',
                              color: const Color(0xFF7209B7),
                              onTap: () => context.push('/setup'),
                            ),
                            _QuickActionCard(
                              icon: Icons.settings_rounded,
                              label: 'Academic Settings',
                              subtitle: 'Year & semester control',
                              color: const Color(0xFF3A86FF),
                              onTap: () => context.push('/admin/settings'),
                            ),
                            _QuickActionCard(
                              icon: Icons.account_circle_rounded,
                              label: 'My Profile',
                              subtitle: 'View & edit profile',
                              color: const Color(0xFF06D6A0),
                              onTap: () => context.push('/profile'),
                            ),
                          ],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                        child: Text('Analytics Overview',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF1A1A2E))),
                      ),

                      // ── STATS GRID ────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.6,
                          children: [
                            _AdminStatCard(
                                'Total Forms',
                                _analytics?['total_forms']?.toString() ?? '0',
                                Icons.assignment_rounded,
                                AppColors.primary),
                            _AdminStatCard(
                                'Approved',
                                _analytics?['approved']?.toString() ?? '0',
                                Icons.check_circle_rounded,
                                AppColors.approved),
                            _AdminStatCard(
                                'Pending Mentor',
                                _analytics?['pending_mentor']?.toString() ??
                                    '0',
                                Icons.hourglass_empty_rounded,
                                AppColors.mentorReview),
                            _AdminStatCard(
                                'Pending HOD',
                                _analytics?['pending_hod']?.toString() ?? '0',
                                Icons.pending_rounded,
                                AppColors.hodReview),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── AVG / HIGHEST / REJECTED ROW ──────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _ScorePill(
                                    label: 'Avg Score',
                                    value: _analytics?['average_score']
                                            ?.toString() ??
                                        '0',
                                    color: AppColors.primary,
                                  ),
                                  _ScorePill(
                                    label: 'Highest',
                                    value:
                                        (_analytics?['highest_score'] as num?)
                                                ?.toStringAsFixed(0) ??
                                            '0',
                                    color: AppColors.success,
                                  ),
                                  _ScorePill(
                                    label: 'Rejected',
                                    value:
                                        _analytics?['rejected']?.toString() ??
                                            '0',
                                    color: AppColors.rejected,
                                  ),
                                ]),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── STAR DISTRIBUTION BAR CHART ───────────────────
                      if (starDist.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Star Rating Distribution',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
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
                                  leftTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (v, _) => Text(
                                          '${v.toInt()}⭐',
                                          style: const TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── TOP STUDENTS ──────────────────────────────────
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Top Students',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      const SizedBox(height: 12),

                      ...(_topStudents ?? []).asMap().entries.map((e) {
                        final i = e.key;
                        final s = e.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: i < 3
                                    ? [
                                        AppColors.starGold,
                                        Colors.grey,
                                        Colors.brown
                                      ][i]
                                    : AppColors.primary.withOpacity(0.7),
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                              ),
                              title: Text(s['student_name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
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
                                    StarRating(
                                        stars: s['star_rating'] as int,
                                        size: 13),
                                  ]),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ── QUICK ACTION CARD ─────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15), width: 1.5),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1A1A2E))),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── STAT CARD ─────────────────────────────────────────────────────────────────

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
                    fontWeight: FontWeight.w800, fontSize: 22, color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
      );
}

// ── SCORE PILL ────────────────────────────────────────────────────────────────

class _ScorePill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ScorePill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ]);
}
