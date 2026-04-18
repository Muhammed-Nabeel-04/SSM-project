import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Mentor screen to approve/reject student activity submissions.
/// Accessible from MentorDashboard via new "Activities" tab.
class MentorActivityScreen extends StatefulWidget {
  const MentorActivityScreen({super.key});

  @override
  State<MentorActivityScreen> createState() => _MentorActivityScreenState();
}

class _MentorActivityScreenState extends State<MentorActivityScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getMentorPendingActivities();
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = (_data?['items'] as List?) ?? [];
    final total = _data?['total'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Activity Reviews',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          Text('$total pending',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: ErrorBanner(_error!))
              : items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 64,
                              color: AppColors.success.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          const Text('No pending activities 🎉',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _ActivityReviewCard(
                          activity: items[i],
                          onDone: _load,
                        ),
                      ),
                    ),
    );
  }
}

// ─── ACTIVITY REVIEW CARD ─────────────────────────────────────────────────────

class _ActivityReviewCard extends StatefulWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onDone;
  const _ActivityReviewCard({required this.activity, required this.onDone});

  @override
  State<_ActivityReviewCard> createState() => _ActivityReviewCardState();
}

class _ActivityReviewCardState extends State<_ActivityReviewCard> {
  bool _expanded = false;
  bool _acting = false;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _acting = true);
    try {
      final res = await ApiService.approveActivity(
        widget.activity['id'],
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Approved! New total: ${(res['grand_total'] ?? 0).toStringAsFixed(0)} pts'),
          backgroundColor: AppColors.success,
        ));
        widget.onDone();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject() async {
    if (_noteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please provide a rejection reason.'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _acting = true);
    try {
      await ApiService.rejectActivity(
          widget.activity['id'], _noteCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Activity rejected. Student notified.'),
            backgroundColor: AppColors.mentorReview));
        widget.onDone();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final act = widget.activity;
    final type = act['activity_type'] as String? ?? '';
    final student = act['student'] as Map? ?? {};
    final data = act['data'] as Map? ?? {};
    final ocrStatus = act['ocr_status'] as String? ?? '';
    final ocrNote = act['ocr_note'] as String?;
    final hasFile = act['has_file'] as bool? ?? false;
    final filename = act['filename'] as String?;
    final submittedAt = act['submitted_at'] as String?;

    final (icon, color) = _typeInfo(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        // ── Header ────────────────────────────────────────────────────────
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_typeLabel(type),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        '${student['name'] ?? ''} · ${student['register_number'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (submittedAt != null)
                        Text(_formatDate(submittedAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textLight)),
                    ]),
              ),
              // OCR status chip
              _OcrChip(ocrStatus),
              const SizedBox(width: 6),
              Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary),
            ]),
          ),
        ),

        // ── Expanded detail ───────────────────────────────────────────────
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Activity data fields
              if (data.isNotEmpty) ...[
                const Text('Activity Details',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: data.entries
                      .map((e) => _DetailChip(
                            label: _fieldLabel(e.key),
                            value: e.value.toString(),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              // OCR note
              if (ocrNote != null) ...[
                _InfoRow(
                  icon: Icons.document_scanner_rounded,
                  label: 'OCR Result',
                  value: ocrNote,
                  color: ocrStatus == 'valid'
                      ? AppColors.success
                      : AppColors.mentorReview,
                ),
                const SizedBox(height: 10),
              ],

              // Document
              if (hasFile) ...[
                _InfoRow(
                  icon: Icons.attach_file_rounded,
                  label: 'Document',
                  value: filename ?? 'attached',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () async {
                    final fileUrl = act['file_url'] as String?;
                    if (fileUrl != null) {
                      await launchUrl(Uri.parse(fileUrl),
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('View Document',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.primary),
                ),
                const SizedBox(height: 12),
              ],

              // Note field
              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText:
                      'Note (required for rejection, optional for approval)',
                  hintText: 'e.g. Certificate looks valid / Name mismatch',
                ),
              ),
              const SizedBox(height: 14),

              // Action buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _acting ? null : _reject,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _acting ? null : _approve,
                    icon: _acting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  (IconData, Color) _typeInfo(String type) => switch (type) {
        'gpa_update' => (Icons.school_rounded, AppColors.academic),
        'project' => (Icons.code_rounded, AppColors.academic),
        'nptel' => (Icons.workspace_premium_rounded, AppColors.development),
        'online_cert' => (Icons.laptop_rounded, AppColors.development),
        'internship' => (Icons.work_outline_rounded, AppColors.development),
        'competition' => (Icons.emoji_events_rounded, AppColors.development),
        'publication' => (Icons.article_rounded, AppColors.development),
        'prof_program' => (Icons.event_rounded, AppColors.development),
        'placement' => (Icons.business_center_rounded, AppColors.skill),
        'higher_study' => (Icons.import_contacts_rounded, AppColors.skill),
        'industry_int' => (Icons.factory_rounded, AppColors.skill),
        'research' => (Icons.biotech_rounded, AppColors.skill),
        'formal_role' => (Icons.star_rounded, AppColors.leadership),
        'event_org' => (Icons.celebration_rounded, AppColors.leadership),
        'community' => (Icons.group_rounded, AppColors.leadership),
        _ => (Icons.task_rounded, AppColors.textSecondary),
      };

  String _typeLabel(String type) => switch (type) {
        'gpa_update' => 'Academic Update',
        'project' => 'Project / Beyond Curriculum',
        'nptel' => 'NPTEL / SWAYAM Certificate',
        'online_cert' => 'Online Course Certificate',
        'internship' => 'Internship / In-plant Training',
        'competition' => 'Competition / Hackathon',
        'publication' => 'Publication / Patent',
        'prof_program' => 'Professional Skill Program',
        'placement' => 'Placement Offer',
        'higher_study' => 'Higher Studies',
        'industry_int' => 'Industry Interaction',
        'research' => 'Research Paper',
        'formal_role' => 'Formal Leadership Role',
        'event_org' => 'Event Organization',
        'community' => 'Community Service',
        _ => type,
      };

  String _fieldLabel(String key) => switch (key) {
        'nptel_tier' => 'Tier',
        'course_name' => 'Course',
        'platform_name' => 'Platform',
        'internship_company' => 'Company',
        'internship_duration' => 'Duration',
        'competition_name' => 'Event',
        'competition_result' => 'Result',
        'publication_title' => 'Title',
        'publication_type' => 'Type',
        'placement_company' => 'Company',
        'placement_lpa' => 'LPA',
        'role_level' => 'Level',
        'role_name' => 'Role',
        'event_name' => 'Event',
        'event_level' => 'Level',
        'internal_gpa' => 'Int. GPA',
        'university_gpa' => 'Univ. GPA',
        'attendance_pct' => 'Attendance %',
        'has_arrear' => 'Has Arrear',
        'project_status' => 'Status',
        'higher_study_exam' => 'Exam',
        'higher_study_score' => 'Score',
        'industry_org' => 'Organisation',
        'research_title' => 'Title',
        'community_org' => 'Organisation',
        'community_level' => 'Level',
        _ => key,
      };

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── SMALL WIDGETS ────────────────────────────────────────────────────────────

class _OcrChip extends StatelessWidget {
  final String status;
  const _OcrChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'valid' => (AppColors.success, 'OCR ✓'),
      'review' => (AppColors.mentorReview, 'OCR ~'),
      'failed' => (AppColors.error, 'OCR ✗'),
      _ => (AppColors.textSecondary, '—'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label, value;
  const _DetailChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text('$label: $value',
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: RichText(
                  text: TextSpan(
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: TextStyle(fontWeight: FontWeight.w600, color: color)),
              TextSpan(text: value),
            ],
          ))),
        ],
      );
}
