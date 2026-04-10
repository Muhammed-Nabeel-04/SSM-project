// ═══════════════════════════════════════════════════════════════
// score_screen.dart
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class ScoreScreen extends StatefulWidget {
  final int formId;
  const ScoreScreen({required this.formId, super.key});
  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getScore(widget.formId);
      setState(() { _data = d; _loading = false; });
    } on ApiException catch (_) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scores = _data?['scores'];

    return Scaffold(
      appBar: AppBar(title: const Text('My SSM Score')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : scores == null
              ? const Center(child: Text('Score not available yet'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    GrandTotalCard(
                      total: (scores['grand_total'] as num).toDouble(),
                      stars: scores['star_rating'] as int,
                    ),
                    const SizedBox(height: 20),

                    // Category score grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.9,
                      children: [
                        ScoreRingCard(score: (scores['academic'] as num).toDouble(), maxScore: 100, label: 'Academic', color: AppColors.academic, icon: Icons.school_rounded),
                        ScoreRingCard(score: (scores['development'] as num).toDouble(), maxScore: 100, label: 'Development', color: AppColors.development, icon: Icons.workspace_premium_rounded),
                        ScoreRingCard(score: (scores['skill'] as num).toDouble(), maxScore: 100, label: 'Skill & Professional', color: AppColors.skill, icon: Icons.trending_up_rounded),
                        ScoreRingCard(score: (scores['discipline'] as num).toDouble(), maxScore: 100, label: 'Discipline', color: AppColors.discipline, icon: Icons.verified_rounded),
                        ScoreRingCard(score: (scores['leadership'] as num).toDouble(), maxScore: 100, label: 'Leadership', color: AppColors.leadership, icon: Icons.emoji_events_rounded),
                      ],
                    ),

                    if (_data?['mentor_remarks'] != null) ...[
                      const SizedBox(height: 16),
                      _RemarkCard('Mentor Remarks', _data!['mentor_remarks'], AppColors.mentorColor),
                    ],
                    if (_data?['hod_remarks'] != null) ...[
                      const SizedBox(height: 8),
                      _RemarkCard('HOD Remarks', _data!['hod_remarks'], AppColors.hodColor),
                    ],
                    const SizedBox(height: 32),
                  ]),
                ),
    );
  }
}

class _RemarkCard extends StatelessWidget {
  final String title;
  final String remark;
  final Color color;
  const _RemarkCard(this.title, this.remark, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
        const SizedBox(height: 6),
        Text(remark, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
      ]),
    );
  }
}
