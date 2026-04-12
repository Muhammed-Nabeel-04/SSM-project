// ═══ mentor_dashboard.dart ══════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../widgets/offline_wrapper.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import 'mentor_activity_screen.dart';

class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});
  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  List<dynamic>? _allStudents;
  bool _loading = true;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = (_data == null); // Show loader only on first load
    });
    try {
      final res = await Future.wait([
        ApiService.getMentorDashboard(),
        ApiService.getMentorAllStudents(),
      ]);
      setState(() {
        _data = res[0] as Map<String, dynamic>;
        final studentsData = res[1] as Map<String, dynamic>;
        _allStudents = (studentsData['items'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = (_data?['pending_reviews'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mentor Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(_data?['mentor'] ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'All Students (${_allStudents?.length ?? 0})'),
            const Tab(text: 'Activities'),
          ],
        ),
      ),
      body: OfflineWrapper(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: TabBarView(
                  controller: _tab,
                  children: [
                    // Activities tab
                    const MentorActivityScreen(),
                    // Pending
                    pending.isEmpty
                        ? const SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: 300,
                              child: Center(
                                child: Text('No pending reviews 🎉',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: pending.length,
                            itemBuilder: (_, i) =>
                                _PendingCard(form: pending[i]),
                          ),

                    // All Students Tab
                    // All students
                    ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _allStudents?.length ?? 0,
                      itemBuilder: (_, i) =>
                          _StudentCard(student: _allStudents![i]),
                    ),

                    // Activity reviews
                    const MentorActivityScreen(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> form;
  const _PendingCard({required this.form});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/mentor/review/${form['form_id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const CircleAvatar(
              backgroundColor: AppColors.mentorColor,
              child: Icon(Icons.person_rounded, color: Colors.white),
            ),
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
              StatusBadge(form['status']),
              if (form['preview_score'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${(form['preview_score'] as num).toStringAsFixed(0)} pts',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 13),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
        ),
        title: Text(student['student_name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(student['register_number'] ?? '',
            style: const TextStyle(fontSize: 12)),
        trailing: student['grand_total'] != null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  '${(student['grand_total'] as num).toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.primary),
                ),
                StarRating(stars: student['star_rating'] ?? 0, size: 14),
              ])
            : StatusBadge(student['status'] ?? 'draft'),
        onTap: () {
          if (student['form_id'] != null) {
            context.push('/mentor/review/${student['form_id']}');
          }
        },
      ),
    );
  }
}
