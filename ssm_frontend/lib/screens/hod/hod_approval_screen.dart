import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class HodApprovalScreen extends StatefulWidget {
  final int formId;
  const HodApprovalScreen({required this.formId, super.key});

  @override
  State<HodApprovalScreen> createState() => _HodApprovalScreenState();
}

class _HodApprovalScreenState extends State<HodApprovalScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _submitting = false;
  String _hodFeedback = 'good';
  final _remarksCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getHodFormDetails(widget.formId);
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.approved;
      case 'rejected':
        return AppColors.rejected;
      case 'mentor_review':
      case 'submitted':
        return AppColors.mentorColor;
      case 'draft':
        return AppColors.draft;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'mentor_review':
      case 'submitted':
        return Icons.hourglass_top_rounded;
      case 'draft':
        return Icons.edit_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'approved':
        return 'Already approved — score is locked';
      case 'rejected':
        return 'This form was rejected';
      case 'mentor_review':
        return 'Awaiting mentor review';
      case 'submitted':
        return 'Awaiting mentor review';
      case 'draft':
        return 'Student has not submitted yet';
      default:
        return 'Not available for HOD action';
    }
  }

  Future<void> _decide(bool approve) async {
    setState(() => _submitting = true);
    try {
      final res = await ApiService.hodApproveForm(widget.formId, {
        'hod_feedback': _hodFeedback,
        'remarks': _remarksCtrl.text.trim(),
        'approve': approve,
      });
      if (mounted) {
        final msg = approve
            ? '✓ Approved! Final score: ${res['final_score']?['grand_total']?.toStringAsFixed(0)} pts'
            : '✗ Rejected — student will be notified';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: approve ? AppColors.approved : AppColors.rejected,
        ));
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final student = _data?['student'];
    final scores = _data?['current_scores'];
    final formStatus = _data?['status'] ?? '';
    final canApprove = formStatus == 'hod_review';

    return Scaffold(
      appBar: AppBar(title: Text('Approve: ${student?['name'] ?? ''}')),
      body: LoadingOverlay(
        loading: _submitting,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Score summary
            if (scores != null)
              GrandTotalCard(
                total: (scores['grand_total'] as num).toDouble(),
                stars: scores['star_rating'] as int,
              ),
            const SizedBox(height: 16),

            // Score grid
            if (scores != null) ...[
              Row(children: [
                Expanded(
                    child: ScoreRingCard(
                        score: (scores['academic'] as num).toDouble(),
                        maxScore: 100,
                        label: 'Academic',
                        color: AppColors.academic,
                        icon: Icons.school_rounded)),
                const SizedBox(width: 8),
                Expanded(
                    child: ScoreRingCard(
                        score: (scores['development'] as num).toDouble(),
                        maxScore: 100,
                        label: 'Dev',
                        color: AppColors.development,
                        icon: Icons.workspace_premium_rounded)),
                const SizedBox(width: 8),
                Expanded(
                    child: ScoreRingCard(
                        score: (scores['skill'] as num).toDouble(),
                        maxScore: 100,
                        label: 'Skill',
                        color: AppColors.skill,
                        icon: Icons.trending_up_rounded)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: ScoreRingCard(
                        score: (scores['discipline'] as num).toDouble(),
                        maxScore: 100,
                        label: 'Discipline',
                        color: AppColors.discipline,
                        icon: Icons.verified_rounded)),
                const SizedBox(width: 8),
                Expanded(
                    child: ScoreRingCard(
                        score: (scores['leadership'] as num).toDouble(),
                        maxScore: 100,
                        label: 'Leadership',
                        color: AppColors.leadership,
                        icon: Icons.emoji_events_rounded)),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
              ]),
            ],

            const SizedBox(height: 16),

            if (_data?['mentor_remarks'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mentorColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.mentorColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mentor Remarks',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.mentorColor,
                              fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(_data!['mentor_remarks'],
                          style: const TextStyle(fontSize: 13)),
                    ]),
              ),

            const SizedBox(height: 16),

            // HOD feedback
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const SectionHeader(
                      title: 'HOD Feedback',
                      icon: Icons.rate_review_rounded,
                      color: AppColors.hodColor),
                  const SizedBox(height: 14),
                  AppDropdown<String>(
                    label: 'HOD Academic Feedback (1.5)',
                    value: _hodFeedback,
                    onChanged: (v) => setState(() => _hodFeedback = v!),
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
                  TextFormField(
                    controller: _remarksCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        hintText:
                            'HOD remarks (visible to student and mentor)...'),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            if (canApprove) ...[
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : () => _decide(false),
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
                    onPressed: _submitting ? null : () => _decide(true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.approved),
                    icon: const Icon(Icons.lock_rounded, size: 18),
                    label: const Text('Approve & Lock Score'),
                  ),
                ),
              ]),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _statusColor(formStatus).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _statusColor(formStatus).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_statusIcon(formStatus),
                        color: _statusColor(formStatus), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _statusMessage(formStatus),
                      style: TextStyle(
                          color: _statusColor(formStatus),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}
