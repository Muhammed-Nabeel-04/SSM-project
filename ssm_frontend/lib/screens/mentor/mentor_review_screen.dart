import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../shared/document_viewer_screen.dart';

class MentorReviewScreen extends StatefulWidget {
  final int formId;
  const MentorReviewScreen({required this.formId, super.key});

  @override
  State<MentorReviewScreen> createState() => _MentorReviewScreenState();
}

class _MentorReviewScreenState extends State<MentorReviewScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _submitting = false;

  // Mentor-rated fields
  String _mentorFeedback = 'good';
  String _technicalSkill = 'good';
  String _softSkill = 'good';
  String _disciplineLevel = 'no_violations';
  String _dressCode = 'consistent';
  String _deptContrib = 'none';
  String _socialMedia = 'none';
  String _innovationInit = 'none';
  String _teamManagement = 'good';
  bool _lateEntries = false;
  final _remarksCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getMentorFormDetails(widget.formId);
      setState(() {
        _data = d;
        _loading = false;
      });
    } on ApiException catch (_) {
      setState(() => _loading = false);
    }
  }

  // --- NEW METHOD ADDED HERE ---
  void _showActivitySheet(BuildContext context, Map<String, dynamic> a) {
    if (a['mentor_status'] != 'pending') return;
    final noteCtrl = TextEditingController();
    final type =
        (a['activity_type'] as String).replaceAll('_', ' ').toUpperCase();
    final data = a['data'] as Map? ?? {};
    final fileUrl = a['file_url'] as String?;
    final filename = a['filename'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                if (data.isNotEmpty) ...[
                  ...data.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${e.key}: ${e.value}',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      )),
                  const SizedBox(height: 10),
                ],
                if (fileUrl != null) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocumentViewerScreen(
                              url: fileUrl,
                              title: filename ?? 'Document',
                            ),
                          ));
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('View Document'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (required for rejection)',
                    hintText: 'e.g. Certificate looks valid / Name mismatch',
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (noteCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Note required for rejection'),
                                  backgroundColor: AppColors.error));
                          return;
                        }
                        Navigator.pop(ctx);
                        await ApiService.rejectActivity(
                            a['id'], noteCtrl.text.trim());
                        _load();
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ApiService.approveActivity(a['id'],
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim());
                        _load();
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success),
                    ),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }

  Map<String, dynamic> _buildPayload() => {
        'mentor_feedback': _mentorFeedback,
        'technical_skill': _technicalSkill,
        'soft_skill': _softSkill,
        'discipline_level': _disciplineLevel,
        'dress_code_level': _dressCode,
        'dept_contribution': _deptContrib,
        'social_media_level': _socialMedia,
        'late_entries': _lateEntries,
        'innovation_initiative': _innovationInit,
        'team_management_leadership': _teamManagement,
        'remarks': _remarksCtrl.text.trim(),
      };

  Future<void> _submitReview() async {
    setState(() => _submitting = true);
    try {
      final res =
          await ApiService.submitMentorReview(widget.formId, _buildPayload());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ Review submitted. Final score: ${res['updated_score']?['grand_total']?.toStringAsFixed(0)} pts'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } on ApiException catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _rejectForm() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Form'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason for rejection'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.rejected),
            onPressed: () => Navigator.pop(context, reasonCtrl.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await ApiService.rejectForm(widget.formId, reason);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Form rejected'), backgroundColor: AppColors.rejected));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final student = _data?['student'];
    final currentScore = _data?['current_score'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Review: ${student?['name'] ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: LoadingOverlay(
        loading: _submitting,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person_rounded, color: Colors.white)),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student?['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(student?['register_number'] ?? '',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ]),
                  const Spacer(),
                  if (currentScore != null)
                    Column(children: [
                      Text(
                          (currentScore['grand_total'] as num).toStringAsFixed(0),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: AppColors.primary)),
                      const Text('Auto Score',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textSecondary)),
                    ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Submitted Activities
            if ((_data?['activities'] as List? ?? []).isNotEmpty) ...[
              const Text('Submitted Activities',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              ...(_data!['activities'] as List).map((a) {
                final type = (a['activity_type'] as String)
                    .replaceAll('_', ' ')
                    .toUpperCase();
                final status = a['mentor_status'] as String;
                final data = a['data'] as Map? ?? {};
                final color = status == 'approved'
                    ? AppColors.success
                    : status == 'rejected'
                        ? AppColors.error
                        : AppColors.mentorReview;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _showActivitySheet(context, a),
                    title: Text(type,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: data.isNotEmpty
                        ? Text(
                            data.entries
                                .take(2)
                                .map((e) => '${e.key}: ${e.value}')
                                .join(' • '),
                            style: const TextStyle(fontSize: 11))
                        : null,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(status.toUpperCase(),
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (status == 'pending')
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textLight, size: 18),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Academic Feedback
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const SectionHeader(
                      title: '1. Academic Feedback',
                      icon: Icons.school_rounded,
                      color: AppColors.academic),
                  const SizedBox(height: 14),
                  AppDropdown<String>(
                    label: 'Mentor Feedback (1.4)',
                    value: _mentorFeedback,
                    onChanged: (v) => setState(() => _mentorFeedback = v!),
                    items: const [
                      DropdownMenuItem(
                          value: 'average', child: Text('Average (5 pts)')),
                      DropdownMenuItem(
                          value: 'good', child: Text('Good (10 pts)')),
                      DropdownMenuItem(
                          value: 'excellent',
                          child: Text('Excellent (15 pts)')),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Skill Ratings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const SectionHeader(
                      title: '3. Skill Assessment',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.skill),
                  const SizedBox(height: 14),
                  AppDropdown<String>(
                    label: 'Technical Skill Competency (3.1)',
                    value: _technicalSkill,
                    onChanged: (v) => setState(() => _technicalSkill = v!),
                    items: const [
                      DropdownMenuItem(
                          value: 'basic',
                          child: Text('Basic — Limited application (5 pts)')),
                      DropdownMenuItem(
                          value: 'good',
                          child: Text('Good — Applies with guidance (10 pts)')),
                      DropdownMenuItem(
                          value: 'excellent',
                          child: Text(
                              'Excellent — Independent problem solver (20 pts)')),
                    ],
                  ),
                  AppDropdown<String>(
                    label: 'Soft Skills & Communication (3.2)',
                    value: _softSkill,
                    onChanged: (v) => setState(() => _softSkill = v!),
                    items: const [
                      DropdownMenuItem(
                          value: 'average', child: Text('Average (5 pts)')),
                      DropdownMenuItem(
                          value: 'good', child: Text('Good (10 pts)')),
                      DropdownMenuItem(
                          value: 'excellent',
                          child: Text('Excellent (20 pts)')),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Discipline
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const SectionHeader(
                      title: '4. Discipline & Contribution',
                      icon: Icons.verified_rounded,
                      color: AppColors.discipline),
                  const SizedBox(height: 14),
                  AppDropdown<String>(
                    label: 'Discipline & Code of Conduct (4.1)',
                    value: _disciplineLevel,
                    onChanged: (v) => setState(() => _disciplineLevel = v!),
                    items: const [
                      DropdownMenuItem(
                          value: 'major',
                          child: Text('Major Violations (0 pts)')),
                      DropdownMenuItem(
                          value: 'minor', child: Text('Minor Issues (10 pts)')),
                      DropdownMenuItem(
                          value: 'no_violations',
                          child: Text('No Violations — Exemplary (20 pts)')),
                    ],
                  ),
                  Row(children: [
                    Checkbox(
                        value: _lateEntries,
                        onChanged: (v) => setState(() => _lateEntries = v!)),
                    const Text(
                        'Frequent late entries (reduces punctuality score)',
                        style: TextStyle(fontSize: 13)),
                  ]),
                  const SizedBox(height: 6),
                  AppDropdown<String>(
                    label: 'Dress Code (4.3)',
                    value: _dressCode,
                    onChanged: (v) => setState(() => _dressCode = v!),
                    items: const [
                      DropdownMenuItem(
                          value: 'generally_follows',
                          child: Text('Generally Follows (5 pts)')),
                      DropdownMenuItem(
                          value: 'highly_regular',
                          child: Text('Highly Regular (10 pts)')),
                      DropdownMenuItem(
                          value: 'consistent',
                          child: Text('100% Consistent (15 pts)')),
                    ],
                  ),
                  AppDropdown<String>(
                    label: 'Contribution to Department Events (4.4)',
                    value: _deptContrib,
                    onChanged: (v) => setState(() => _deptContrib = v!),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None')),
                      DropdownMenuItem(
                          value: 'minor_idea',
                          child: Text('Minor Idea (5 pts)')),
                      DropdownMenuItem(
                          value: 'proposed_useful',
                          child: Text('Proposed Useful Idea (15 pts)')),
                      DropdownMenuItem(
                          value: 'implemented_impactful',
                          child: Text(
                              'Implemented Impactful Initiative (25 pts)')),
                    ],
                  ),
                  AppDropdown<String>(
                    label: 'Social Media & Promotional Activities (4.5)',
                    value: _socialMedia,
                    onChanged: (v) => setState(() => _socialMedia = v!),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None')),
                      DropdownMenuItem(
                          value: 'minimal', child: Text('Minimal (5 pts)')),
                      DropdownMenuItem(
                          value: 'occasional',
                          child: Text('Occasional (10 pts)')),
                      DropdownMenuItem(
                          value: 'participates_shares',
                          child: Text('Participates & Shares (15 pts)')),
                      DropdownMenuItem(
                          value: 'regularly_contributes',
                          child: Text('Regularly Contributes (20 pts)')),
                      DropdownMenuItem(
                          value: 'active_creates',
                          child: Text('Actively Creates & Manages (25 pts)')),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Leadership
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const SectionHeader(
                      title: '5. Leadership Ratings',
                      icon: Icons.emoji_events_rounded,
                      color: AppColors.leadership),
                  const SizedBox(height: 14),
                  AppDropdown<String>(
                    label: 'Team Management & Collaboration (5.3)',
                    value: _teamManagement,
                    onChanged: (v) => setState(() => _teamManagement = v!),
                    items: const [
                      DropdownMenuItem(
                          value: 'limited',
                          child: Text('Limited Teamwork (5 pts)')),
                      DropdownMenuItem(
                          value: 'good',
                          child: Text('Good Team Player (10 pts)')),
                      DropdownMenuItem(
                          value: 'excellent',
                          child: Text('Excellent Team Leader (15 pts)')),
                    ],
                  ),
                  AppDropdown<String>(
                    label: 'Innovation & Initiative (5.4)',
                    value: _innovationInit,
                    onChanged: (v) => setState(() => _innovationInit = v!),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None')),
                      DropdownMenuItem(
                          value: 'minor', child: Text('Minor Idea (5 pts)')),
                      DropdownMenuItem(
                          value: 'proposed',
                          child: Text('Proposed Useful Idea (15 pts)')),
                      DropdownMenuItem(
                          value: 'implemented',
                          child: Text(
                              'Implemented Impactful Initiative (25 pts)')),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Remarks
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mentor Remarks',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _remarksCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            hintText:
                                'Optional remarks for the student and HOD...'),
                      ),
                    ]),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons — only show if form is still reviewable
            if ((_data?['status'] as String?)?.toLowerCase() != 'hod_review' &&
                (_data?['status'] as String?)?.toLowerCase() != 'approved')
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _rejectForm,
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.rejected),
                    label: const Text('Reject',
                        style: TextStyle(color: AppColors.rejected)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.rejected)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _submitReview,
                    icon: const Icon(Icons.forward_rounded, size: 18),
                    label: const Text('Submit & Forward to HOD'),
                  ),
                ),
              ])
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.hodColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.hodColor.withValues(alpha: 0.3)),
                ),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 16, color: AppColors.hodColor),
                  const SizedBox(width: 8),
                  Text(
                    (_data?['status'] as String?)?.toLowerCase() == 'approved'
                        ? 'Approved by HOD'
                        : 'Forwarded to HOD — awaiting approval',
                    style: const TextStyle(
                        color: AppColors.hodColor, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}
