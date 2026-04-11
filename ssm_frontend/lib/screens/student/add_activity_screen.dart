import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// 3-step flow: pick category → pick activity type → fill details + upload
class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  int _step = 0;         // 0 = category, 1 = type, 2 = details
  String? _category;
  String? _activityType;
  File?   _pickedFile;
  bool    _submitting = false;
  String? _resultMessage;
  bool    _success = false;

  // Form field controllers
  final _c = <String, TextEditingController>{};
  final Map<String, String?> _dropdowns = {};

  TextEditingController _ctrl(String key) =>
      _c.putIfAbsent(key, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _c.values) c.dispose();
    super.dispose();
  }

  // ─── CATEGORY DEFINITIONS ────────────────────────────────────────────────

  static const _categories = [
    _Cat('academic',    'Academic',         Icons.school_rounded,           AppColors.academic,    'GPA, attendance, project'),
    _Cat('development', 'Student Dev',      Icons.emoji_objects_rounded,    AppColors.development, 'NPTEL, internship, competitions'),
    _Cat('skill',       'Skill & Career',   Icons.trending_up_rounded,      AppColors.skill,       'Placement, higher studies, research'),
    _Cat('leadership',  'Leadership',       Icons.emoji_events_rounded,     AppColors.leadership,  'Roles, events, community service'),
  ];

  static const _typesByCategory = <String, List<_AType>>{
    'academic': [
      _AType('gpa_update', 'Update GPA / Attendance',   Icons.assessment_rounded,   false,
          'Update your internal GPA, university GPA, attendance %'),
      _AType('project',    'Project / Beyond Curriculum', Icons.code_rounded,       true,
          'Submit your project completion proof'),
    ],
    'development': [
      _AType('nptel',        'NPTEL / SWAYAM Cert',       Icons.workspace_premium_rounded, true,
          'Upload your NPTEL or SWAYAM completion certificate'),
      _AType('online_cert',  'Online Course Cert',        Icons.laptop_rounded,            true,
          'Coursera, Udemy, LinkedIn Learning etc.'),
      _AType('internship',   'Internship / In-plant',     Icons.work_outline_rounded,      true,
          'Internship offer/completion letter'),
      _AType('competition',  'Competition / Hackathon',   Icons.emoji_events_rounded,      true,
          'Certificate or proof of participation/winning'),
      _AType('publication',  'Publication / Patent',      Icons.article_rounded,           true,
          'Journal paper, conference paper, patent'),
      _AType('prof_program', 'Workshop / VAP / Add-on',   Icons.event_rounded,             true,
          'Professional skill program certificate'),
    ],
    'skill': [
      _AType('placement',    'Placement Offer',           Icons.business_center_rounded,   true,
          'Upload your placement offer letter'),
      _AType('higher_study', 'Higher Studies (GATE/GRE)', Icons.import_contacts_rounded,   true,
          'Score card or admission letter'),
      _AType('industry_int', 'Industry Interaction',      Icons.factory_rounded,           false,
          'Guest lecture, industry visit, workshop'),
      _AType('research',     'Research Paper',            Icons.biotech_rounded,           true,
          'Reviewed/published research paper'),
    ],
    'leadership': [
      _AType('formal_role', 'Formal Leadership Role',     Icons.star_rounded,              true,
          'CR, club president, dept coordinator etc.'),
      _AType('event_org',   'Event Organization',         Icons.celebration_rounded,       true,
          'Organized / led a college or external event'),
      _AType('community',   'Community / Social Service', Icons.group_rounded,             true,
          'NSS, NCC, social service with proof'),
    ],
  };

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_stepTitle(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _step == 0 ? () => Navigator.pop(context) : _goBack,
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _step == 0 ? _buildCategoryStep()
             : _step == 1 ? _buildTypeStep()
             : _buildDetailsStep(),
      ),
    );
  }

  String _stepTitle() => switch (_step) {
    0 => 'What did you do?',
    1 => _catLabel(_category!),
    _ => _typeLabel(_activityType!),
  };

  void _goBack() => setState(() {
    if (_step == 2) { _step = 1; _resultMessage = null; }
    else if (_step == 1) { _step = 0; _activityType = null; }
  });

  // ── STEP 0: CATEGORY ──────────────────────────────────────────────────────

  Widget _buildCategoryStep() {
    return GridView.count(
      key: const ValueKey('cat'),
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: _categories.map((cat) => _CatCard(
        cat: cat,
        onTap: () => setState(() { _category = cat.id; _step = 1; }),
      )).toList(),
    );
  }

  // ── STEP 1: ACTIVITY TYPE ─────────────────────────────────────────────────

  Widget _buildTypeStep() {
    final types = _typesByCategory[_category!] ?? [];
    return ListView(
      key: const ValueKey('type'),
      padding: const EdgeInsets.all(16),
      children: types.map((t) => _TypeTile(
        type: t,
        onTap: () {
          setState(() {
            _activityType = t.id;
            _dropdowns.clear();
            _step = 2;
          });
        },
      )).toList(),
    );
  }

  // ── STEP 2: DETAILS + UPLOAD ──────────────────────────────────────────────

  Widget _buildDetailsStep() {
    final atype = _typesByCategory[_category!]!
        .firstWhere((t) => t.id == _activityType!);

    return SingleChildScrollView(
      key: const ValueKey('details'),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Type description banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _catColor(_category!).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(atype.icon, color: _catColor(_category!), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(atype.description,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          ]),
        ),
        const SizedBox(height: 20),

        // Dynamic fields
        ..._buildFields(_activityType!),

        // File upload
        if (atype.requiresDoc) ...[
          const SizedBox(height: 16),
          const Text('Supporting Document',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _FilePicker(
            pickedFile: _pickedFile,
            onPick: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
              );
              if (result?.files.single.path != null) {
                setState(() => _pickedFile = File(result!.files.single.path!));
              }
            },
          ),
          const SizedBox(height: 4),
          const Text('PDF, JPG or PNG • Max 5 MB',
              style: TextStyle(color: AppColors.textLight, fontSize: 11)),
        ],

        const SizedBox(height: 24),

        // Result message
        if (_resultMessage != null) ...[
          _ResultBanner(message: _resultMessage!, success: _success),
          const SizedBox(height: 16),
        ],

        // Submit button
        if (!_success)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Activity'),
            ),
          ),

        if (_success)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
              label: const Text('Done — Back to Dashboard'),
            ),
          ),
      ]),
    );
  }

  // ── FIELD BUILDERS PER ACTIVITY TYPE ────────────────────────────────────

  List<Widget> _buildFields(String type) {
    return switch (type) {
      'gpa_update' => [
        _numField('internal_gpa',   'Internal GPA (e.g. 8.5)',    suffix: '/10'),
        _numField('university_gpa', 'University GPA (e.g. 7.8)',  suffix: '/10'),
        _numField('attendance_pct', 'Attendance %',               suffix: '%'),
        _boolField('has_arrear',    'I have an active arrear'),
      ],
      'project' => [
        _dropdown('project_status', 'Project Status', [
          ('concept',          'Concept / Idea (5 pts)'),
          ('partial',          'Partially Completed (10 pts)'),
          ('fully_completed',  'Fully Completed (15 pts)'),
        ]),
      ],
      'nptel' => [
        _dropdown('nptel_tier', 'Achievement Level', [
          ('participated',  'Participated'),
          ('completed',     'Completed'),
          ('elite',         'Elite'),
          ('elite_plus',    'Elite + Gold/Silver/Top 5%'),
        ]),
      ],
      'online_cert' => [
        _textField('platform_name', 'Platform (e.g. Coursera, Udemy)'),
        _textField('course_name',   'Course Name'),
      ],
      'internship' => [
        _textField('internship_company',  'Company / Organisation Name'),
        _dropdown('internship_duration', 'Duration', [
          ('participation',  'Participation only'),
          ('1to2weeks',      '1–2 Weeks + Report (10 pts)'),
          ('2to4weeks',      '2–4 Weeks + Report (15 pts)'),
          ('4weeks_plus',    '≥ 4 Weeks + Project (20 pts)'),
        ]),
      ],
      'competition' => [
        _textField('competition_name', 'Event / Competition Name'),
        _dropdown('competition_result', 'Your Result', [
          ('participated', 'Participated (5 pts)'),
          ('finalist',     'Finalist / Shortlisted (10 pts)'),
          ('winner',       'Winner / Top 3 (20 pts)'),
        ]),
      ],
      'publication' => [
        _textField('publication_title', 'Title of Paper / Patent'),
        _dropdown('publication_type', 'Type', [
          ('prototype',   'Prototype / Idea Validated (5 pts)'),
          ('conference',  'Conference / Journal Paper (10 pts)'),
          ('patent',      'Patent Filed / Product (15 pts)'),
        ]),
      ],
      'prof_program' => [
        _textField('program_name', 'Program Name (Workshop / VAP / Add-on)'),
      ],
      'placement' => [
        _textField('placement_company', 'Company Name'),
        _numField( 'placement_lpa',     'Package (LPA)', suffix: 'LPA'),
      ],
      'higher_study' => [
        _textField('higher_study_exam',  'Exam (e.g. GATE, GRE, CAT)'),
        _textField('higher_study_score', 'Score / Rank'),
      ],
      'industry_int' => [
        _textField('industry_org', 'Organisation / Company Name'),
      ],
      'research' => [
        _textField('research_title',   'Paper Title'),
        _textField('research_journal', 'Journal / Conference Name'),
      ],
      'formal_role' => [
        _textField('role_name', 'Role Title (e.g. Class Representative)'),
        _dropdown('role_level', 'Level', [
          ('class_level',   'Class Level (5 pts)'),
          ('dept_level',    'Department Level (10 pts)'),
          ('college_level', 'College Level (15 pts)'),
        ]),
      ],
      'event_org' => [
        _textField('event_name', 'Event Name'),
        _dropdown('event_level', 'Scope', [
          ('dept',          'Department Event'),
          ('college',       'College Event'),
          ('inter_college', 'Inter-College Event'),
          ('national',      'National / External Event'),
        ]),
      ],
      'community' => [
        _textField('community_org', 'Organisation (e.g. NSS, NCC, NGO)'),
        _dropdown('community_level', 'Level', [
          ('local',    'Local (5 pts)'),
          ('district', 'District Level'),
          ('state',    'State Level (15 pts)'),
          ('national', 'National (25 pts)'),
        ]),
      ],
      _ => [],
    };
  }

  Widget _textField(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _ctrl(key),
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _numField(String key, String label, {String? suffix}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _ctrl(key),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    ),
  );

  Widget _dropdown(String key, String label, List<(String, String)> options) {
    _dropdowns.putIfAbsent(key, () => null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: _dropdowns[key],
        decoration: InputDecoration(labelText: label),
        items: options.map((o) =>
            DropdownMenuItem(value: o.$1, child: Text(o.$2))).toList(),
        onChanged: (v) => setState(() => _dropdowns[key] = v),
      ),
    );
  }

  Widget _boolField(String key, String label) {
    _dropdowns.putIfAbsent(key, () => 'false');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Checkbox(
          value: _dropdowns[key] == 'true',
          onChanged: (v) => setState(() => _dropdowns[key] = (v ?? false).toString()),
        ),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  // ── SUBMIT ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final atype = _typesByCategory[_category!]!
        .firstWhere((t) => t.id == _activityType!);

    if (atype.requiresDoc && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please upload a supporting document')));
      return;
    }

    setState(() { _submitting = true; _resultMessage = null; });

    try {
      final fields = <String, String>{
        'category':      _category!,
        'activity_type': _activityType!,
      };

      // Add text fields
      for (final e in _c.entries) {
        if (e.value.text.trim().isNotEmpty) {
          fields[e.key] = e.value.text.trim();
        }
      }
      // Add dropdowns
      for (final e in _dropdowns.entries) {
        if (e.value != null) fields[e.key] = e.value!;
      }

      final res = await ApiService.submitActivity(
        fields: fields,
        file: _pickedFile,
      );

      final ocrStatus = res['ocr_status'] as String? ?? '';
      final msg       = res['message']    as String? ?? '';

      setState(() {
        _submitting    = false;
        _success       = ocrStatus != 'failed';
        _resultMessage = msg;
        if (_success) _pickedFile = null;
      });

    } on ApiException catch (e) {
      setState(() {
        _submitting    = false;
        _success       = false;
        _resultMessage = e.message;
      });
    }
  }

  // ── UTIL ──────────────────────────────────────────────────────────────────

  String _catLabel(String id) =>
      _categories.firstWhere((c) => c.id == id).label;

  String _typeLabel(String id) {
    for (final types in _typesByCategory.values) {
      for (final t in types) {
        if (t.id == id) return t.label;
      }
    }
    return id;
  }

  Color _catColor(String id) =>
      _categories.firstWhere((c) => c.id == id).color;
}

// ─── STEP WIDGETS ─────────────────────────────────────────────────────────────

class _CatCard extends StatelessWidget {
  final _Cat cat;
  final VoidCallback onTap;
  const _CatCard({required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cat.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cat.icon, color: cat.color, size: 24),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cat.label, style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(cat.subtitle, style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ]),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final _AType type;
  final VoidCallback onTap;
  const _TypeTile({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(type.icon, color: AppColors.primary, size: 22),
        ),
        title: Text(type.label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(type.description,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (type.requiresDoc)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.attach_file_rounded,
                  size: 14, color: AppColors.textSecondary),
            ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ]),
        onTap: onTap,
      ),
    );
  }
}

class _FilePicker extends StatelessWidget {
  final File? pickedFile;
  final VoidCallback onPick;
  const _FilePicker({this.pickedFile, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(
            color: pickedFile != null ? AppColors.success : AppColors.divider,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: pickedFile != null
              ? AppColors.success.withOpacity(0.05)
              : AppColors.background,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            pickedFile != null
                ? Icons.check_circle_rounded
                : Icons.upload_file_rounded,
            color: pickedFile != null ? AppColors.success : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(
            pickedFile != null
                ? pickedFile!.path.split('/').last
                : 'Tap to pick PDF, JPG or PNG',
            style: TextStyle(
              color: pickedFile != null
                  ? AppColors.success : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          )),
        ]),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final String message;
  final bool success;
  const _ResultBanner({required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(success ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}

// ─── DATA CLASSES ─────────────────────────────────────────────────────────────

class _Cat {
  final String id, label, subtitle;
  final IconData icon;
  final Color color;
  const _Cat(this.id, this.label, this.icon, this.color, this.subtitle);
}

class _AType {
  final String id, label, description;
  final IconData icon;
  final bool requiresDoc;
  const _AType(this.id, this.label, this.icon, this.requiresDoc, this.description);
}
