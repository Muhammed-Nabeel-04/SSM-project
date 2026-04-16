// ════════════════════════════════════════════════
// hod_dashboard.dart
// ════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../widgets/offline_wrapper.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/notification_bell.dart';

class HodDashboard extends StatefulWidget {
  const HodDashboard({super.key});
  @override
  State<HodDashboard> createState() => _HodDashboardState();
}

class _HodDashboardState extends State<HodDashboard> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = (_data == null); // Only show spinner if no data exists yet
    });
    try {
      final d = await ApiService.getHodDashboard();
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = (_data?['pending_approvals'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HOD Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(_data?['hod'] ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              onPressed: () => context.push('/hod/reports')),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
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
                context.read<AuthProvider>().logout();
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
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Summary
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppColors.hodColor, Color(0xFF9C27B0)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _Stat('Pending', pending.length.toString(),
                                  Icons.hourglass_empty_rounded),
                              _Stat(
                                  'Approved',
                                  _data?['approved_count']?.toString() ?? '0',
                                  Icons.check_circle_rounded),
                              _Stat(
                                  'Total',
                                  _data?['total_students']?.toString() ?? '0',
                                  Icons.people_rounded),
                            ]),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: pending.isEmpty
                          ? const SliverToBoxAdapter(
                              child: Center(
                                  child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('No pending approvals 🎉',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                            )))
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _HodPendingCard(form: pending[i]),
                                childCount: pending.length,
                              ),
                            ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);
}

class _HodPendingCard extends StatelessWidget {
  final Map<String, dynamic> form;
  const _HodPendingCard({required this.form});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/hod/approval/${form['form_id']}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const CircleAvatar(
                  backgroundColor: AppColors.hodColor,
                  child: Icon(Icons.person_rounded, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(form['student_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(form['register_number'] ?? '',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      Text('AY ${form['academic_year']}',
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 11)),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (form['preview_score'] != null)
                  Text(
                    '${(form['preview_score'] as num).toStringAsFixed(0)} pts',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.hodColor,
                        fontSize: 14),
                  ),
                if (form['star_rating'] != null)
                  StarRating(stars: form['star_rating'] as int, size: 14),
              ]),
            ]),
          ),
        ),
      );
}
