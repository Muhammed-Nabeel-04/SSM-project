import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';

/// The new student dashboard — shows live score + activity log.
/// Replaces the old monolithic SSMFormScreen.
class ActivityDashboard extends StatefulWidget {
  const ActivityDashboard({super.key});

  @override
  State<ActivityDashboard> createState() => _ActivityDashboardState();
}

class _ActivityDashboardState extends State<ActivityDashboard> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getMyActivities();
      setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final activities = (_data?['activities'] as List?) ?? [];
    final score      = _data?['live_score'] as Map?;

    final filtered = _filterCategory == 'all'
        ? activities
        : activities.where((a) {
            final type = a['activity_type'] as String? ?? '';
            return _categoryOf(type) == _filterCategory;
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('My Activities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(_data?['academic_year'] ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: ErrorBanner(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(slivers: [
                    // ── LIVE SCORE CARD ───────────────────────────────────
                    SliverToBoxAdapter(child: _ScoreCard(score: score)),

                    // ── CATEGORY FILTER ───────────────────────────────────
                    SliverToBoxAdapter(child: _CategoryFilter(
                      selected: _filterCategory,
                      onChanged: (v) => setState(() => _filterCategory = v),
                    )),

                    // ── ACTIVITY LIST ─────────────────────────────────────
                    if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                          child: Column(children: [
                            Icon(Icons.playlist_add_rounded,
                                size: 56, color: AppColors.textLight.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(
                              _filterCategory == 'all'
                                  ? 'No activities yet.\nTap + to add your first!'
                                  : 'No activities in this category yet.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 14),
                            ),
                          ]),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _ActivityCard(
                              activity: filtered[i],
                              onDelete: () => _deleteActivity(filtered[i]['id']),
                            ),
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                  ]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await context.push<bool>('/student/add-activity');
          if (added == true) _load();
        },
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Activity',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _deleteActivity(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: const Text('This activity and its document will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ApiService.deleteActivity(id);
      _load();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
  }

  String _categoryOf(String type) {
    const devTypes  = ['nptel','online_cert','internship','competition','publication','prof_program'];
    const skillTypes= ['placement','higher_study','industry_int','research'];
    const leadTypes = ['formal_role','event_org','community'];
    if (devTypes.contains(type))   return 'development';
    if (skillTypes.contains(type)) return 'skill';
    if (leadTypes.contains(type))  return 'leadership';
    return 'academic';
  }
}

// ─── SCORE CARD ───────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final Map? score;
  const _ScoreCard({this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: score == null
          ? const Center(
              child: Text('Submit activities to see your score',
                  style: TextStyle(color: Colors.white70, fontSize: 13)))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Live Score',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('${(score!['grand_total'] ?? 0).toStringAsFixed(0)} / 500',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                ]),
                StarRating(stars: (score!['star_rating'] ?? 0) as int,
                    size: 24),
              ]),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                _ScorePill('Academic',    score!['academic']    ?? 0, AppColors.academic),
                _ScorePill('Dev',         score!['development'] ?? 0, AppColors.development),
                _ScorePill('Skill',       score!['skill']       ?? 0, AppColors.skill),
                _ScorePill('Discipline',  score!['discipline']  ?? 0, AppColors.discipline),
                _ScorePill('Leadership',  score!['leadership']  ?? 0, AppColors.leadership),
              ]),
            ]),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final num score;
  final Color color;
  const _ScorePill(this.label, this.score, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(score.toStringAsFixed(0),
          style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700, fontSize: 16)),
      Text(label,
          style: const TextStyle(color: Colors.white60, fontSize: 9)),
    ]);
  }
}

// ─── CATEGORY FILTER ─────────────────────────────────────────────────────────

class _CategoryFilter extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _CategoryFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('all', 'All', Icons.apps_rounded),
      ('academic', 'Academic', Icons.school_rounded),
      ('development', 'Dev', Icons.emoji_objects_rounded),
      ('skill', 'Skill', Icons.trending_up_rounded),
      ('leadership', 'Lead', Icons.emoji_events_rounded),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: items.map((item) {
          final isSelected = selected == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(item.$3, size: 14,
                    color: isSelected ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(item.$2),
              ]),
              selected: isSelected,
              onSelected: (_) => onChanged(item.$1),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w500),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── ACTIVITY CARD ────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onDelete;
  const _ActivityCard({required this.activity, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type        = activity['activity_type'] as String? ?? '';
    final ocrStatus   = activity['ocr_status']   as String? ?? '';
    final mentorStatus= activity['mentor_status'] as String? ?? '';
    final data        = activity['data'] as Map? ?? {};
    final filename    = activity['filename'] as String?;
    final submittedAt = activity['submitted_at'] as String?;
    final mentorNote  = activity['mentor_note'] as String?;
    final ocrNote     = activity['ocr_note']    as String?;

    final (icon, color) = _typeInfo(type);
    final (statusColor, statusLabel) = _statusInfo(ocrStatus, mentorStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_typeLabel(type),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (submittedAt != null)
                  Text(_formatDate(submittedAt),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),

          // ── Activity details ───────────────────────────────────────────
          if (data.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4,
              children: data.entries.take(3).map((e) => _DataTag(
                  label: _fieldLabel(e.key),
                  value: e.value.toString())).toList(),
            ),
          ],

          if (filename != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.attach_file_rounded, size: 13,
                  color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(filename,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ],

          // ── OCR failed banner ──────────────────────────────────────────
          if (ocrStatus == 'failed') ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  ocrNote ?? 'Document verification failed. Please re-upload.',
                  style: const TextStyle(color: AppColors.error, fontSize: 11),
                )),
              ]),
            ),
          ],

          // ── Mentor note ────────────────────────────────────────────────
          if (mentorNote != null && mentorNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Mentor: $mentorNote',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
          ],

          // ── Delete button (only for non-approved) ─────────────────────
          if (mentorStatus != 'approved') ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.error),
                label: const Text('Delete',
                    style: TextStyle(color: AppColors.error, fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  (IconData, Color) _typeInfo(String type) => switch (type) {
    'gpa_update'   => (Icons.school_rounded,         AppColors.academic),
    'project'      => (Icons.code_rounded,            AppColors.academic),
    'nptel'        => (Icons.workspace_premium_rounded, AppColors.development),
    'online_cert'  => (Icons.laptop_rounded,          AppColors.development),
    'internship'   => (Icons.work_outline_rounded,    AppColors.development),
    'competition'  => (Icons.emoji_events_rounded,    AppColors.development),
    'publication'  => (Icons.article_rounded,         AppColors.development),
    'prof_program' => (Icons.event_rounded,           AppColors.development),
    'placement'    => (Icons.business_center_rounded, AppColors.skill),
    'higher_study' => (Icons.import_contacts_rounded, AppColors.skill),
    'industry_int' => (Icons.factory_rounded,         AppColors.skill),
    'research'     => (Icons.biotech_rounded,         AppColors.skill),
    'formal_role'  => (Icons.star_rounded,            AppColors.leadership),
    'event_org'    => (Icons.celebration_rounded,     AppColors.leadership),
    'community'    => (Icons.group_rounded,           AppColors.leadership),
    _              => (Icons.task_rounded,            AppColors.textSecondary),
  };

  (Color, String) _statusInfo(String ocr, String mentor) {
    if (ocr == 'failed')             return (AppColors.error,       'Re-upload needed');
    if (mentor == 'approved')        return (AppColors.success,     'Approved ✓');
    if (mentor == 'rejected')        return (AppColors.error,       'Rejected');
    if (mentor == 'not_required')    return (AppColors.success,     'Auto-verified ✓');
    if (ocr == 'valid')              return (AppColors.submitted,   'Sent to mentor');
    if (ocr == 'review')             return (AppColors.mentorReview,'Under review');
    return (AppColors.draft, 'Pending');
  }

  String _typeLabel(String type) => switch (type) {
    'gpa_update'   => 'Academic Update (GPA / Attendance)',
    'project'      => 'Project / Beyond Curriculum',
    'nptel'        => 'NPTEL / SWAYAM Certificate',
    'online_cert'  => 'Online Course Certificate',
    'internship'   => 'Internship / In-plant Training',
    'competition'  => 'Competition / Hackathon',
    'publication'  => 'Publication / Patent / Prototype',
    'prof_program' => 'Professional Skill Program',
    'placement'    => 'Placement Offer',
    'higher_study' => 'Higher Studies (GATE / GRE)',
    'industry_int' => 'Industry Interaction',
    'research'     => 'Research Paper',
    'formal_role'  => 'Formal Leadership Role',
    'event_org'    => 'Event Organization',
    'community'    => 'Community / Social Service',
    _              => type,
  };

  String _fieldLabel(String key) => switch (key) {
    'nptel_tier'          => 'Tier',
    'course_name'         => 'Course',
    'platform_name'       => 'Platform',
    'internship_company'  => 'Company',
    'internship_duration' => 'Duration',
    'competition_name'    => 'Event',
    'competition_result'  => 'Result',
    'publication_title'   => 'Title',
    'placement_company'   => 'Company',
    'placement_lpa'       => 'LPA',
    'role_level'          => 'Level',
    'event_level'         => 'Level',
    'internal_gpa'        => 'Int. GPA',
    'university_gpa'      => 'Univ. GPA',
    'attendance_pct'      => 'Attendance',
    _                     => key,
  };

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return iso; }
  }
}

class _DataTag extends StatelessWidget {
  final String label, value;
  const _DataTag({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value',
          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
    );
  }
}
