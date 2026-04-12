import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Shows the timeline of a form's status progression.
/// Accessible from student dashboard by tapping a submitted form.
class FormTimelineScreen extends StatefulWidget {
  final int formId;
  const FormTimelineScreen({required this.formId, super.key});

  @override
  State<FormTimelineScreen> createState() => _FormTimelineScreenState();
}

class _FormTimelineScreenState extends State<FormTimelineScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final data = await ApiService.getFormTimeline(widget.formId);
      setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Form #${widget.formId} Status',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: ErrorBanner(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    // ── Current status banner ──────────────────────────────
                    _StatusBanner(_data!),
                    const SizedBox(height: 24),

                    // ── Timeline ───────────────────────────────────────────
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Progress Timeline',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    const SizedBox(height: 16),
                    _Timeline(_data!),

                    // ── Remarks section ────────────────────────────────────
                    if (_data!['mentor_remarks'] != null ||
                        _data!['hod_remarks'] != null ||
                        _data!['rejection_reason'] != null) ...[
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Feedback',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      const SizedBox(height: 12),
                      if (_data!['mentor_remarks'] != null)
                        _RemarkCard('Mentor Remarks',
                            _data!['mentor_remarks'], AppColors.mentorColor,
                            Icons.supervisor_account_rounded),
                      if (_data!['hod_remarks'] != null)
                        _RemarkCard('HOD Remarks',
                            _data!['hod_remarks'], AppColors.hodColor,
                            Icons.admin_panel_settings_rounded),
                      if (_data!['rejection_reason'] != null)
                        _RemarkCard('Rejection Reason',
                            _data!['rejection_reason'], AppColors.error,
                            Icons.cancel_rounded),
                    ],
                  ]),
                ),
    );
  }
}

// ─── STATUS BANNER ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatusBanner(this.data);

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? '';
    final (color, icon, label) = _statusInfo(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 40),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(color: color, fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Academic Year ${data['academic_year'] ?? ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        if (data['score'] != null) ...[
          const SizedBox(height: 12),
          Text(
            '${(data['score']['grand_total'] ?? 0).toStringAsFixed(0)} / 500',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                color: AppColors.primary),
          ),
          StarRating(stars: data['score']['star_rating'] ?? 0, size: 24),
        ],
      ]),
    );
  }

  (Color, IconData, String) _statusInfo(String s) => switch (s) {
    'draft'         => (AppColors.draft,        Icons.edit_outlined,             'Draft'),
    'submitted'     => (AppColors.submitted,    Icons.send_rounded,              'Submitted for Review'),
    'mentor_review' => (AppColors.mentorReview, Icons.supervisor_account_rounded,'Under Mentor Review'),
    'hod_review'    => (AppColors.hodReview,    Icons.admin_panel_settings_rounded,'Under HOD Review'),
    'approved'      => (AppColors.approved,     Icons.check_circle_rounded,      'Approved ✓'),
    'rejected'      => (AppColors.error,        Icons.cancel_rounded,            'Rejected'),
    _               => (AppColors.textSecondary,Icons.help_outline_rounded,      s),
  };
}

// ─── TIMELINE ─────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  final Map<String, dynamic> data;
  const _Timeline(this.data);

  static const _stages = [
    ('draft',         'Form Created',          'Student creates the form'),
    ('submitted',     'Submitted',             'Student submits for review'),
    ('mentor_review', 'Mentor Review',         'Mentor is verifying'),
    ('hod_review',    'HOD Review',            'HOD is reviewing'),
    ('approved',      'Approved',              'Form fully approved'),
  ];

  @override
  Widget build(BuildContext context) {
    final status  = data['status'] as String? ?? 'draft';
    final isRej   = status == 'rejected';
    final stageIds = _stages.map((s) => s.$1).toList();
    final currIdx  = stageIds.indexOf(isRej ? 'submitted' : status);

    return Column(
      children: List.generate(_stages.length, (i) {
        final (id, title, subtitle) = _stages[i];
        final isDone    = i < currIdx || (i == currIdx && !isRej);
        final isCurrent = i == currIdx && !isRej;
        final isLast    = i == _stages.length - 1;

        Color dotColor;
        if (isRej && i == 1) {
          dotColor = AppColors.error;
        } else if (isDone) {
          dotColor = AppColors.success;
        } else if (isCurrent) {
          dotColor = AppColors.submitted;
        } else {
          dotColor = AppColors.divider;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dot + line ────────────────────────────────────────────────
            Column(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(color: dotColor.withOpacity(0.3), width: 4)
                      : null,
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : (isCurrent ? Icons.circle : Icons.circle_outlined),
                  color: Colors.white,
                  size: 14,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2, height: 44,
                  color: i < currIdx ? AppColors.success : AppColors.divider,
                ),
            ]),
            const SizedBox(width: 14),
            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 2),
                  Text(title, style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14,
                      color: isDone || isCurrent
                          ? AppColors.textPrimary : AppColors.textLight)),
                  Text(
                    isRej && i == 1
                        ? 'Rejected at this stage'
                        : subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: isRej && i == 1
                            ? AppColors.error : AppColors.textSecondary),
                  ),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─── REMARK CARD ──────────────────────────────────────────────────────────────

class _RemarkCard extends StatelessWidget {
  final String title, remark;
  final Color color;
  final IconData icon;
  const _RemarkCard(this.title, this.remark, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700,
              fontSize: 13, color: color)),
          const SizedBox(height: 4),
          Text(remark, style: const TextStyle(fontSize: 13,
              color: AppColors.textPrimary)),
        ]),
      ),
    ]),
  );
}
