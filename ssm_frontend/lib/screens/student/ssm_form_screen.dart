import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class SSMFormScreen extends StatefulWidget {
  final int formId;
  const SSMFormScreen({required this.formId, super.key});

  @override
  State<SSMFormScreen> createState() => _SSMFormScreenState();
}

class _SSMFormScreenState extends State<SSMFormScreen> {
  Map<String, dynamic>? _formData;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Controllers
  final _internalGpaCtrl = TextEditingController();
  final _universityGpaCtrl = TextEditingController();
  final _attendanceCtrl = TextEditingController();
  final _placementPctCtrl = TextEditingController();
  final _placementLpaCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _researchCtrl = TextEditingController();
  final _onlineCertCtrl = TextEditingController();
  final _profProgramsCtrl = TextEditingController();

  // Dropdown values
  String _projectStatus = 'none';
  String _nptelTier = 'none';
  String _internshipDuration = 'none';
  String _competitionResult = 'none';
  String _publicationType = 'none';
  String _innovationLevel = 'none';
  String _formalRole = 'none';
  String _eventLeadership = 'none';
  String _communityLeadership = 'none';
  bool _hasArrear = false;
  bool _higherStudies = false;

  // Preview score
  Map<String, dynamic>? _previewScore;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _loadForm() async {
    try {
      final data = await ApiService.getForm(widget.formId);
      setState(() {
        _formData = data;
        _loading = false;
        _prefill(data);
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  void _prefill(Map<String, dynamic> data) {
    final a = data['academic'] ?? {};
    final d = data['development'] ?? {};
    final s = data['skill'] ?? {};
    final l = data['leadership'] ?? {};

    _internalGpaCtrl.text = (a['internal_gpa'] ?? '').toString();
    _universityGpaCtrl.text = (a['university_gpa'] ?? '').toString();
    _attendanceCtrl.text = (a['attendance_pct'] ?? '').toString();
    _hasArrear = a['has_arrear'] ?? false;
    _projectStatus = a['project_status'] ?? 'none';

    _nptelTier = d['nptel_tier'] ?? 'none';
    _onlineCertCtrl.text = (d['online_cert_count'] ?? 0).toString();
    _internshipDuration = d['internship_duration'] ?? 'none';
    _competitionResult = d['competition_result'] ?? 'none';
    _publicationType = d['publication_type'] ?? 'none';
    _profProgramsCtrl.text = (d['professional_programs_count'] ?? 0).toString();

    _placementPctCtrl.text = (s['placement_training_pct'] ?? 0).toString();
    _placementLpaCtrl.text = (s['placement_lpa'] ?? 0).toString();
    _higherStudies = s['higher_studies'] ?? false;
    _industryCtrl.text = (s['industry_interactions'] ?? 0).toString();
    _researchCtrl.text = (s['research_papers_count'] ?? 0).toString();
    _innovationLevel = s['innovation_level'] ?? 'none';

    _formalRole = l['formal_role'] ?? 'none';
    _eventLeadership = l['event_leadership'] ?? 'none';
    _communityLeadership = l['community_leadership'] ?? 'none';
  }

  Map<String, dynamic> _buildPayload() => {
    'academic': {
      'internal_gpa': double.tryParse(_internalGpaCtrl.text),
      'university_gpa': double.tryParse(_universityGpaCtrl.text),
      'has_arrear': _hasArrear,
      'attendance_pct': double.tryParse(_attendanceCtrl.text),
      'project_status': _projectStatus,
    },
    'development': {
      'nptel_tier': _nptelTier,
      'online_cert_count': int.tryParse(_onlineCertCtrl.text) ?? 0,
      'internship_duration': _internshipDuration,
      'competition_result': _competitionResult,
      'publication_type': _publicationType,
      'professional_programs_count': int.tryParse(_profProgramsCtrl.text) ?? 0,
    },
    'skill': {
      'placement_training_pct': double.tryParse(_placementPctCtrl.text) ?? 0,
      'placement_lpa': double.tryParse(_placementLpaCtrl.text) ?? 0,
      'higher_studies': _higherStudies,
      'industry_interactions': int.tryParse(_industryCtrl.text) ?? 0,
      'research_papers_count': int.tryParse(_researchCtrl.text) ?? 0,
      'innovation_level': _innovationLevel,
    },
    'leadership': {
      'formal_role': _formalRole,
      'event_leadership': _eventLeadership,
      'community_leadership': _communityLeadership,
    },
  };

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final res = await ApiService.saveForm(widget.formId, _buildPayload());
      setState(() { _previewScore = res['preview_score']; _saving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Saved! Preview score updated.'),
              backgroundColor: AppColors.success));
      }
    } on ApiException catch (e) {
      setState(() { _error = e.message; _saving = false; });
    }
  }

  Future<void> _submit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit for Review?'),
        content: const Text(
            'Once submitted, your form goes to your mentor for review. Make sure everything is correct.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.submitForm(widget.formId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✓ Submitted for mentor review!'),
              backgroundColor: AppColors.success));
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
      }
    }
  }

  bool get _isEditable {
    final status = _formData?['status'];
    return status == 'draft' || status == 'rejected';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SSM Form — AY ${_formData?['academic_year'] ?? ''}'),
        actions: [
          if (_formData != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: StatusBadge(_formData!['status']),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LoadingOverlay(
              loading: _saving,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  if (_error != null) ...[
                    ErrorBanner(_error!),
                    const SizedBox(height: 12),
                  ],

                  // ── PREVIEW SCORE ────────────────────────────
                  if (_previewScore != null)
                    _PreviewScore(score: _previewScore!),

                  const SizedBox(height: 8),

                  // ── UPLOAD BUTTON ────────────────────────────
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/student/form/${widget.formId}/upload'),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload Documents'),
                  ),

                  const SizedBox(height: 16),

                  // ── CATEGORY 1 ───────────────────────────────
                  _buildCat1(),
                  const SizedBox(height: 16),

                  // ── CATEGORY 2 ───────────────────────────────
                  _buildCat2(),
                  const SizedBox(height: 16),

                  // ── CATEGORY 3 ───────────────────────────────
                  _buildCat3(),
                  const SizedBox(height: 16),

                  // ── CATEGORY 5 (student fills) ────────────────
                  _buildCat5(),
                  const SizedBox(height: 24),

                  // ── NOTE ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.accent, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Category 4 (Discipline) and mentor/HOD ratings are filled by your mentor after submission.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // ── BUTTONS ──────────────────────────────────
                  if (_isEditable) ...[
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _save,
                          child: const Text('Save Draft'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Submit for Review'),
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 32),
                ]),
              ),
            ),
    );
  }

  Widget _buildCat1() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(
                title: '1. Academic Performance',
                icon: Icons.school_rounded,
                color: AppColors.academic,
                maxPoints: 100),
            const SizedBox(height: 16),
            AppNumberField(
                label: 'Internal Assessment GPA (IAT I, II & Model)',
                hint: 'e.g. 8.5',
                controller: _internalGpaCtrl,
                suffix: '/ 10',
                enabled: _isEditable),
            AppNumberField(
                label: 'University Examination GPA',
                hint: 'e.g. 7.8',
                controller: _universityGpaCtrl,
                suffix: '/ 10',
                enabled: _isEditable),
            Row(children: [
              Checkbox(
                  value: _hasArrear,
                  onChanged: _isEditable
                      ? (v) => setState(() => _hasArrear = v!)
                      : null),
              const Text('Has Arrear (reduces university GPA score to 0)',
                  style: TextStyle(fontSize: 13, color: AppColors.error)),
            ]),
            AppNumberField(
                label: 'Attendance %',
                hint: 'e.g. 92',
                controller: _attendanceCtrl,
                suffix: '%',
                enabled: _isEditable),
            AppDropdown<String>(
              label: 'Project Beyond Curriculum',
              value: _projectStatus,
              enabled: _isEditable,
              onChanged: (v) => setState(() => _projectStatus = v!),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No Project')),
                DropdownMenuItem(value: 'concept', child: Text('Concept / Idea Submission (5 pts)')),
                DropdownMenuItem(value: 'partial', child: Text('Partial Implementation (10 pts)')),
                DropdownMenuItem(value: 'fully_completed', child: Text('Fully Completed (15 pts)')),
              ],
            ),
          ]),
        ),
      );

  Widget _buildCat2() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(
                title: '2. Student Development Activities',
                icon: Icons.workspace_premium_rounded,
                color: AppColors.development,
                maxPoints: 100),
            const SizedBox(height: 16),
            AppDropdown<String>(
              label: 'NPTEL / SWAYAM Certification',
              value: _nptelTier,
              enabled: _isEditable,
              onChanged: (v) => setState(() => _nptelTier = v!),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'participated', child: Text('Participated, No Certificate (5 pts)')),
                DropdownMenuItem(value: 'completed', child: Text('Successfully Completed (10 pts)')),
                DropdownMenuItem(value: 'elite', child: Text('Elite Certificate (15 pts)')),
                DropdownMenuItem(value: 'elite_plus', child: Text('Elite + Silver/Gold/Top 5% (20 pts)')),
              ],
            ),
            AppNumberField(
                label: 'Industry Online Certifications (Coursera/Udemy etc. ≥ 20hrs each)',
                hint: 'e.g. 2',
                controller: _onlineCertCtrl,
                enabled: _isEditable),
            AppDropdown<String>(
              label: 'Internship / In-plant Training',
              value: _internshipDuration,
              enabled: _isEditable,
              onChanged: (v) => setState(() => _internshipDuration = v!),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'participation', child: Text('Participation Only (5 pts)')),
                DropdownMenuItem(value: '1to2weeks', child: Text('1-2 Weeks + Report (10 pts)')),
                DropdownMenuItem(value: '2to4weeks', child: Text('2-4 Weeks + Report (15 pts)')),
                DropdownMenuItem(value: '4weeks_plus', child: Text('≥ 4 Weeks + Project (20 pts)')),
              ],
            ),
            AppDropdown<String>(
              label: 'Technical Competitions / Hackathons',
              value: _competitionResult,
              enabled: _isEditable,
              onChanged: (v) => setState(() => _competitionResult = v!),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'participated', child: Text('Participated (5 pts)')),
                DropdownMenuItem(value: 'finalist', child: Text('Finalist / Shortlisted (10 pts)')),
                DropdownMenuItem(value: 'winner', child: Text('Winner / Top 3 (20 pts)')),
              ],
            ),
            AppDropdown<String>(
              label: 'Publications / Patents / Product',
              value: _publicationType,
              enabled: _isEditable,
              onChanged: (v) => setState(() => _publicationType = v!),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'prototype', child: Text('Prototype / Idea Validated (5 pts)')),
                DropdownMenuItem(value: 'conference', child: Text('Conference / Journal Paper (10 pts)')),
                DropdownMenuItem(value: 'patent', child: Text('Patent Filed / Product (15 pts)')),
              ],
            ),
            AppNumberField(
                label: 'Professional Skill Programs (Workshops, VAP, Add-on)',
                hint: 'Count of programs attended',
                controller: _profProgramsCtrl,
                enabled: _isEditable),
          ]),
        ),
      );

  Widget _buildCat3() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(
                title: '3. Skill & Professional Readiness',
                icon: Icons.trending_up_rounded,
                color: AppColors.skill,
                maxPoints: 100),
            const SizedBox(height: 16),
            const Text('Mentor will rate: Technical Skills, Soft Skills, Team Management',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 14),
            AppNumberField(
                label: 'Placement Training Participation %',
                hint: 'e.g. 90',
                controller: _placementPctCtrl,
                suffix: '%',
                enabled: _isEditable),
            AppNumberField(
                label: 'Placement Package (LPA) — 0 if not placed',
                hint: 'e.g. 12.5',
                controller: _placementLpaCtrl,
                suffix: 'LPA',
                enabled: _isEditable),
            Row(children: [
              Checkbox(
                  value: _higherStudies,
                  onChanged: _isEditable
                      ? (v) => setState(() => _higherStudies = v!)
                      : null),
              const Expanded(
                child: Text(
                    'Higher Studies (GATE / Top University) — counts as equivalent score',
                    style: TextStyle(fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 8),
            AppNumberField(
                label: 'Industry Interactions (Guest Lectures / Visits / Workshops)',
                hint: 'e.g. 3',
                controller: _industryCtrl,
                enabled: _isEditable),
            AppNumberField(
                label: 'Research Papers Reviewed (with presentation)',
                hint: 'e.g. 2',
                controller: _researchCtrl,
                enabled: _isEditable),
            AppDropdown<String>(
              label: 'Innovation / Idea Contribution',
              value: _innovationLevel,
              enabled: _isEditable,
              onChanged: (v) => setState(() => _innovationLevel = v!),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'minor', child: Text('Minor Idea')),
                DropdownMenuItem(value: 'proposed', child: Text('Idea Proposed (5 pts)')),
                DropdownMenuItem(value: 'implemented', child: Text('Innovative Idea Implemented (10 pts)')),
              ],
            ),
          ]),
        ),
      );

  Widget _buildCat5() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(
                title: '5. Leadership Roles & Initiatives',
                icon: Icons.emoji_events_rounded,
                color: AppColors.leadership,
                maxPoints: 100),
            const SizedBox(height: 16),
            AppDropdown<String>(
              label: 'Formal Leadership Role',
              value: _formalRole,
              enabled: _isEditable,
              onChanged: (v) => setState(() => _formalRole = v!),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'class_level', child: Text('Class-Level (CR etc.) (5 pts)')),
                DropdownMenuItem(value: 'dept_level', child: Text('Department-Level (10 pts)')),
                DropdownMenuItem(value: 'college_level', child: Text('College-Level (Club Pres. etc.) (15 pts)')),
              ],
            ),
            AppDropdown<String>(
              label: 'Event Leadership & Coordination',
              value: _eventLeadership,
              enabled: _isEditable,
              onChanged: (v) => setState(() => _eventLeadership = v!),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'assisted', child: Text('Assisted Leadership (5 pts)')),
                DropdownMenuItem(value: 'led_1', child: Text('Led 1 Event (10 pts)')),
                DropdownMenuItem(value: 'led_2plus', child: Text('Led 2+ Events (15 pts)')),
              ],
            ),
            AppDropdown<String>(
              label: 'Social / Community Leadership',
              value: _communityLeadership,
              enabled: _isEditable,
              onChanged: (v) => setState(() => _communityLeadership = v!),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'minimal', child: Text('Minimal Involvement (5 pts)')),
                DropdownMenuItem(value: 'active', child: Text('Active Participant (15 pts)')),
                DropdownMenuItem(value: 'led_project', child: Text('Led Community Project (25 pts)')),
              ],
            ),
          ]),
        ),
      );
}

class _PreviewScore extends StatelessWidget {
  final Map<String, dynamic> score;
  const _PreviewScore({required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Preview Score',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _ScoreChip('Academic', score['academic'] ?? 0, AppColors.academic),
            _ScoreChip('Dev', score['development'] ?? 0, AppColors.development),
            _ScoreChip('Skill', score['skill'] ?? 0, AppColors.skill),
            _ScoreChip('Total', score['grand_total'] ?? 0, AppColors.primary),
          ]),
          const SizedBox(height: 8),
          StarRating(stars: score['star_rating'] ?? 0),
        ]),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final num score;
  final Color color;
  const _ScoreChip(this.label, this.score, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(score.toStringAsFixed(0),
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
      Text(label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    ]);
  }
}
