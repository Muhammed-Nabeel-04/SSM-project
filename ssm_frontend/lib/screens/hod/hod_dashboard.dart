// ════════════════════════════════════════════════
// hod_dashboard.dart  —  Tabbed HOD Dashboard
// Tabs: Pending | Approved | Students
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

class _HodDashboardState extends State<HodDashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  List<dynamic>? _allStudents;
  List<dynamic>? _approved;
  bool _loading = true;
  late TabController _tab;

  // Students tab filters
  String _searchQuery = '';
  String _sortBy = 'name';
  String _filterStatus = 'all'; // all | submitted | not_submitted

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = (_data == null));
    try {
      final res = await Future.wait([
        ApiService.getHodDashboard(),
        ApiService.getHodAllStudents(),
      ]);
      setState(() {
        _data = res[0] as Map<String, dynamic>;
        final studentsData = res[1] as Map<String, dynamic>;
        _allStudents = (studentsData['items'] as List?) ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
      }
    }

    // Load approved separately
    try {
      final approvedData = await ApiService.getHodApproved();
      setState(() {
        _approved = (approvedData['items'] as List?) ?? [];
      });
    } catch (_) {
      setState(() => _approved = []);
    }
  }

  List<dynamic> get _pending => (_data?['pending_approvals'] as List?) ?? [];

  List<dynamic> _filteredStudents() {
    var students = (_allStudents ?? []).where((s) {
      final name = (s['student_name'] ?? '').toString().toLowerCase();
      final reg = (s['register_number'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || reg.contains(q);

      final status = (s['form_status'] ?? '').toString();
      final hasSubmitted = status == 'hod_review' ||
          status == 'approved' ||
          status == 'mentor_review' ||
          status == 'submitted' ||
          status == 'draft';
      final matchesFilter = _filterStatus == 'all' ||
          (_filterStatus == 'submitted' && hasSubmitted) ||
          (_filterStatus == 'not_submitted' && !hasSubmitted);

      return matchesSearch && matchesFilter;
    }).toList();

    students.sort((a, b) {
      switch (_sortBy) {
        case 'score':
          final sa = (a['grand_total'] as num?) ?? 0;
          final sb = (b['grand_total'] as num?) ?? 0;
          return sb.compareTo(sa);
        case 'status':
          return (a['form_status'] ?? '')
              .toString()
              .compareTo((b['form_status'] ?? '').toString());
        case 'reg':
          return (a['register_number'] ?? '')
              .toString()
              .compareTo((b['register_number'] ?? '').toString());
        default:
          return (a['student_name'] ?? '')
              .toString()
              .compareTo((b['student_name'] ?? '').toString());
      }
    });
    return students;
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SummaryStrip(
                pending: pending.length,
                approved: _data?['approved_count'] ?? 0,
                total: _data?['total_students'] ?? 0,
              ),
              TabBar(
                controller: _tab,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(text: 'Pending (${pending.length})'),
                  Tab(text: 'Approved (${_data?['approved_count'] ?? 0})'),
                  Tab(text: 'Students (${_allStudents?.length ?? 0})'),
                ],
              ),
            ],
          ),
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
                    _PendingTab(pending: pending),
                    _ApprovedTab(approved: _approved),
                    _StudentsTab(
                      students: _filteredStudents(),
                      totalCount: _allStudents?.length ?? 0,
                      searchQuery: _searchQuery,
                      sortBy: _sortBy,
                      filterStatus: _filterStatus,
                      onSearch: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                      onSort: (v) => setState(() => _sortBy = v),
                      onFilter: (v) => setState(() => _filterStatus = v),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final int pending;
  final dynamic approved;
  final dynamic total;
  const _SummaryStrip(
      {required this.pending, required this.approved, required this.total});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StripStat(Icons.hourglass_empty_rounded, '$pending', 'Pending',
                Colors.amber),
            Container(width: 1, height: 28, color: Colors.white24),
            _StripStat(Icons.check_circle_rounded, '$approved', 'Approved',
                Colors.greenAccent),
            Container(width: 1, height: 28, color: Colors.white24),
            _StripStat(Icons.people_rounded, '$total', 'Total', Colors.white70),
          ],
        ),
      );
}

class _StripStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StripStat(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
        ],
      );
}

// ────────────────────────────────────────────────
// PENDING TAB
// ────────────────────────────────────────────────
class _PendingTab extends StatelessWidget {
  final List<dynamic> pending;
  const _PendingTab({required this.pending});

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 300,
          child: Center(
            child: Text('No pending approvals 🎉',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (_, i) => _HodPendingCard(form: pending[i]),
    );
  }
}

// ────────────────────────────────────────────────
// APPROVED TAB
// ────────────────────────────────────────────────
class _ApprovedTab extends StatelessWidget {
  final List<dynamic>? approved;
  const _ApprovedTab({required this.approved});

  @override
  Widget build(BuildContext context) {
    if (approved == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (approved!.isEmpty) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 300,
          child: Center(
            child: Text('No approved forms yet',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: approved!.length,
      itemBuilder: (_, i) => _ApprovedCard(form: approved![i]),
    );
  }
}

class _ApprovedCard extends StatelessWidget {
  final Map<String, dynamic> form;
  const _ApprovedCard({required this.form});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: form['form_id'] != null
              ? () => context.push('/hod/approval/${form['form_id']}')
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.approved.withOpacity(0.15),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.approved),
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
                      Text('AY ${form['academic_year'] ?? ''}',
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 11)),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (form['final_score'] != null || form['grand_total'] != null)
                  Text(
                    '${((form['final_score'] ?? form['grand_total']) as num).toStringAsFixed(0)} pts',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.approved,
                        fontSize: 14),
                  ),
                if (form['star_rating'] != null)
                  StarRating(stars: form['star_rating'] as int, size: 14),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.approved.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Approved',
                      style: TextStyle(
                          color: AppColors.approved,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          ),
        ),
      );
}

// ────────────────────────────────────────────────
// STUDENTS TAB
// ────────────────────────────────────────────────
class _StudentsTab extends StatelessWidget {
  final List<dynamic> students;
  final int totalCount;
  final String searchQuery;
  final String sortBy;
  final String filterStatus;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onFilter;

  const _StudentsTab({
    required this.students,
    required this.totalCount,
    required this.searchQuery,
    required this.sortBy,
    required this.filterStatus,
    required this.onSearch,
    required this.onSort,
    required this.onFilter,
  });

  PopupMenuItem<String> _menuItem(
      String value, String label, bool selected, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon,
            size: 18,
            color: selected ? AppColors.hodColor : AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? AppColors.hodColor : null)),
        if (selected) ...[
          const Spacer(),
          const Icon(Icons.check_rounded, size: 16, color: AppColors.hodColor),
        ]
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search name or reg no...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: onSearch,
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Filter',
                icon: Badge(
                  isLabelVisible: filterStatus != 'all',
                  child: const Icon(Icons.filter_list_rounded),
                ),
                onSelected: onFilter,
                itemBuilder: (_) => [
                  _menuItem('all', 'All Students', filterStatus == 'all',
                      Icons.people_rounded),
                  _menuItem('submitted', 'Submitted',
                      filterStatus == 'submitted', Icons.upload_file_rounded),
                  _menuItem('not_submitted', 'Not Submitted',
                      filterStatus == 'not_submitted', Icons.pending_outlined),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Sort',
                icon: const Icon(Icons.sort_rounded),
                onSelected: onSort,
                itemBuilder: (_) => [
                  _menuItem('name', 'Sort by Name', sortBy == 'name',
                      Icons.sort_by_alpha_rounded),
                  _menuItem('reg', 'Sort by Reg No', sortBy == 'reg',
                      Icons.numbers_rounded),
                  _menuItem('score', 'Sort by Score', sortBy == 'score',
                      Icons.star_rounded),
                  _menuItem('status', 'Sort by Status', sortBy == 'status',
                      Icons.pending_actions_rounded),
                ],
              ),
            ],
          ),
        ),

        // Active filter chips
        if (filterStatus != 'all' || searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(children: [
              Expanded(
                child: Wrap(spacing: 6, children: [
                  if (filterStatus != 'all')
                    _FilterChip(
                      label: filterStatus == 'submitted'
                          ? 'Submitted'
                          : 'Not Submitted',
                      color: filterStatus == 'submitted'
                          ? AppColors.approved
                          : AppColors.textSecondary,
                      onRemove: () => onFilter('all'),
                    ),
                  if (searchQuery.isNotEmpty)
                    _FilterChip(
                      label: '"$searchQuery"',
                      color: AppColors.hodColor,
                      onRemove: () => onSearch(''),
                    ),
                ]),
              ),
              Text('${students.length}/$totalCount',
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 12)),
            ]),
          ),

        Expanded(
          child: students.isEmpty
              ? const Center(
                  child: Text('No students found',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: students.length,
                  itemBuilder: (_, i) => _StudentCard(student: students[i]),
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onRemove;
  const _FilterChip(
      {required this.label, required this.color, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 3, bottom: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: Icon(Icons.close_rounded, size: 14, color: color),
          ),
        ]),
      );
}

// ────────────────────────────────────────────────
// STUDENT CARD
// ────────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  const _StudentCard({required this.student});

  Color get _statusColor {
    switch (student['form_status'] ?? '') {
      case 'approved':
        return AppColors.approved;
      case 'hod_review':
        return AppColors.hodColor;
      case 'mentor_review':
      case 'submitted':
        return AppColors.mentorColor; // both show as "With Mentor"
      case 'rejected':
        return Colors.red;
      case 'draft':
        return AppColors.draft;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (student['form_status'] ?? '') {
      case 'approved':
        return 'Approved';
      case 'hod_review':
        return 'Pending HOD ⏳';
      case 'mentor_review':
        return 'With Mentor';
      case 'submitted':
        return 'With Mentor';
      case 'rejected':
        return 'Rejected';
      case 'draft':
        return 'Draft';
      default:
        return 'Not Submitted';
    }
  }

  bool get _hasSubmitted {
    final status = (student['form_status'] ?? '').toString();
    return status.isNotEmpty && status != 'not_submitted';
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: student['form_id'] != null
              ? () => context.push('/hod/approval/${student['form_id']}')
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: _hasSubmitted
                    ? AppColors.hodColor.withOpacity(0.12)
                    : AppColors.textLight.withOpacity(0.15),
                radius: 22,
                child: Text(
                  (student['student_name'] ?? 'S')
                      .toString()
                      .substring(0, 1)
                      .toUpperCase(),
                  style: TextStyle(
                      color: _hasSubmitted
                          ? AppColors.hodColor
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student['student_name'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(student['register_number'] ?? '',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      if (student['batch'] != null ||
                          student['semester'] != null)
                        Text(
                          [
                            if (student['batch'] != null)
                              'Batch ${student['batch']}',
                            if (student['semester'] != null)
                              'Sem ${student['semester']}',
                          ].join(' · '),
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 11),
                        ),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (student['grand_total'] != null)
                  Text(
                    '${(student['grand_total'] as num).toStringAsFixed(0)} pts',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _hasSubmitted
                            ? AppColors.hodColor
                            : AppColors.textLight,
                        fontSize: 14),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (student['star_rating'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: StarRating(
                        stars: student['star_rating'] as int, size: 12),
                  ),
              ]),
            ]),
          ),
        ),
      );
}

// ────────────────────────────────────────────────
// PENDING CARD
// ────────────────────────────────────────────────
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
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.hodColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Review',
                      style: TextStyle(
                          color: AppColors.hodColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          ),
        ),
      );
}
