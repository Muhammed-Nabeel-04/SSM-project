import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../widgets/offline_wrapper.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/notification_bell.dart';

class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});
  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  List<dynamic>? _allStudents;
  List<dynamic>? _activities; // ✅ ADDED: was missing
  bool _loading = true;
  late TabController _tab;
  String _searchQuery = '';
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = (_data == null));
    try {
      final res = await Future.wait([
        ApiService.getMentorDashboard(),
        ApiService.getMentorAllStudents(),
        ApiService.getMentorActivities(), // ✅ ADDED: fetch activities
      ]);
      setState(() {
        _data = res[0] as Map<String, dynamic>;
        final studentsData = res[1] as Map<String, dynamic>;
        _allStudents = (studentsData['items'] as List?) ?? [];
        final activitiesData = res[2] as Map<String, dynamic>;
        _activities = (activitiesData['items'] as List?) ?? []; // ✅ ADDED
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> _filteredStudents() {
    var students = (_allStudents ?? []).where((s) {
      final name = (s['student_name'] ?? '').toLowerCase();
      final reg = (s['register_number'] ?? '').toLowerCase();
      return name.contains(_searchQuery) || reg.contains(_searchQuery);
    }).toList();

    students.sort((a, b) {
      if (_sortBy == 'score') {
        final sa = (a['grand_total'] as num?) ?? 0;
        final sb = (b['grand_total'] as num?) ?? 0;
        return sb.compareTo(sa);
      } else if (_sortBy == 'pending') {
        final pa = (a['pending_activities'] as int?) ?? 0;
        final pb = (b['pending_activities'] as int?) ?? 0;
        return pb.compareTo(pa);
      }
      return (a['student_name'] ?? '').compareTo(b['student_name'] ?? '');
    });
    return students;
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
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
          ),
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
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Students (${_allStudents?.length ?? 0})'),
            Tab(text: 'Activities (${_activities?.length ?? 0})'),
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
                    // ── Pending Tab ──────────────────────────────────
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

                    // ── Students Tab ─────────────────────────────────
                    Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search name or reg no...',
                                prefixIcon:
                                    const Icon(Icons.search_rounded, size: 20),
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (v) => setState(
                                  () => _searchQuery = v.toLowerCase()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.sort_rounded),
                            tooltip: 'Sort',
                            onSelected: (v) => setState(() => _sortBy = v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'name', child: Text('Sort by Name')),
                              PopupMenuItem(
                                  value: 'score', child: Text('Sort by Score')),
                              PopupMenuItem(
                                  value: 'pending',
                                  child: Text('Sort by Pending')),
                            ],
                          ),
                        ]),
                      ),
                      Expanded(
                        child: Builder(builder: (_) {
                          final students = _filteredStudents();
                          if (students.isEmpty) {
                            return const Center(
                                child: Text('No students found',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)));
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: students.length,
                            itemBuilder: (_, i) =>
                                _StudentCard(student: students[i]),
                          );
                        }),
                      ),
                    ]),

                    // ── Activities Tab ───────────────────────────────
                    _ActivitiesTab(
                      activities: _activities ?? [], // ✅ now defined
                      onRefresh: _load,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── ACTIVITIES TAB ───────────────────────────────────────────────────────────

class _ActivitiesTab extends StatefulWidget {
  final List<dynamic> activities;
  final Future<void> Function() onRefresh;

  const _ActivitiesTab({
    required this.activities,
    required this.onRefresh,
  });

  @override
  State<_ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<_ActivitiesTab> {
  String _filter = 'all';

  List<dynamic> _filteredActivities() {
    if (_filter == 'all') return widget.activities;
    return widget.activities
        .where((a) => (a['status'] ?? '').toLowerCase() == _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredActivities();

    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  count: widget.activities.length,
                  isSelected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pending',
                  count: widget.activities
                      .where((a) => a['status'] == 'pending')
                      .length,
                  isSelected: _filter == 'pending',
                  onTap: () => setState(() => _filter = 'pending'),
                  color: AppColors.mentorReview,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Accepted',
                  count: widget.activities
                      .where((a) => a['status'] == 'accepted')
                      .length,
                  isSelected: _filter == 'accepted',
                  onTap: () => setState(() => _filter = 'accepted'),
                  color: AppColors.accepted,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Rejected',
                  count: widget.activities
                      .where((a) => a['status'] == 'rejected')
                      .length,
                  isSelected: _filter == 'rejected',
                  onTap: () => setState(() => _filter = 'rejected'),
                  color: AppColors.rejected,
                ),
              ],
            ),
          ),
        ),

        // Activities List
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No activities found',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ActivityCard(
                    activity: filtered[i],
                    onRefresh: widget.onRefresh,
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── FILTER CHIP ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : chipColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : chipColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : chipColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : chipColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ACTIVITY CARD ────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final Future<void> Function() onRefresh;

  const _ActivityCard({
    required this.activity,
    required this.onRefresh,
  });

  Future<void> _handleAction(
      BuildContext context, String action, int activityId) async {
    if (action == 'view') {
      context.push('/mentor/activity/$activityId');
      return;
    }

    if (action == 'approve') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Approve Activity'),
          content:
              const Text('Are you sure you want to approve this activity?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve',
                  style: TextStyle(color: AppColors.accepted)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await ApiService.approveActivity(activityId, note: null);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Activity approved successfully')),
            );
            await onRefresh();
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to approve: $e')),
            );
          }
        }
      }
    }

    if (action == 'reject') {
      final reason = await showDialog<String>(
        context: context,
        builder: (_) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Reject Activity'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Reject',
                    style: TextStyle(color: AppColors.rejected)),
              ),
            ],
          );
        },
      );

      if (reason != null && reason.isNotEmpty) {
        try {
          await ApiService.rejectActivity(activityId, reason);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Activity rejected')),
            );
            await onRefresh();
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to reject: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (activity['status'] ?? 'pending').toLowerCase();
    final activityId = activity['activity_id'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['activity_name'] ?? 'Unnamed Activity',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity['student_name'] ?? '',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        activity['register_number'] ?? '',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status),
              ],
            ),
            if (activity['submitted_date'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    activity['submitted_date'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'rejected' &&
                activity['rejection_reason'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rejected.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.rejected.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.rejected),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activity['rejection_reason'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.rejected,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildActionButtons(context, status, activityId),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, String status, int activityId) {
    if (status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _handleAction(context, 'reject', activityId),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rejected,
                side: const BorderSide(color: AppColors.rejected),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _handleAction(context, 'approve', activityId),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accepted,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _handleAction(context, 'view', activityId),
            icon: const Icon(Icons.visibility_rounded),
            tooltip: 'View Details',
          ),
        ],
      );
    } else if (status == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _handleAction(context, 'view', activityId),
          icon: const Icon(Icons.visibility_rounded, size: 18),
          label: const Text('View Details'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accepted,
            side: const BorderSide(color: AppColors.accepted),
          ),
        ),
      );
    } else if (status == 'rejected') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _handleAction(context, 'view', activityId),
          icon: const Icon(Icons.visibility_rounded, size: 18),
          label: const Text('View Details'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.rejected,
            side: const BorderSide(color: AppColors.rejected),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ─── PENDING CARD ─────────────────────────────────────────────────────────────

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

// ─── STUDENT CARD ─────────────────────────────────────────────────────────────

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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (student['grand_total'] != null) ...[
              Text(
                '${(student['grand_total'] as num).toStringAsFixed(0)} pts',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.primary),
              ),
              StarRating(stars: student['star_rating'] ?? 0, size: 13),
            ] else
              StatusBadge(student['status'] ?? 'draft'),
            const SizedBox(height: 2),
            if ((student['pending_activities'] ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.mentorReview.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.mentorReview.withOpacity(0.3)),
                ),
                child: Text(
                  '${student['pending_activities']}/${student['total_activities']} pending',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mentorReview,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        onTap: () {
          if (student['form_id'] != null) {
            context.push('/mentor/review/${student['form_id']}');
          }
        },
      ),
    );
  }
}
