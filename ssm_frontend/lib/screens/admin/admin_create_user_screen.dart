import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class AdminCreateUserScreen extends StatefulWidget {
  const AdminCreateUserScreen({super.key});

  @override
  State<AdminCreateUserScreen> createState() => _AdminCreateUserScreenState();
}

class _AdminCreateUserScreenState extends State<AdminCreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _regCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _role = 'student';
  int? _deptId;
  int? _mentorId;
  int? _semester;
  final _batchCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  bool _saving = false;
  String? _message;
  bool _success = false;

  // Loaded from API
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _mentors = [];
  bool _loadingDepts = true;
  bool _loadingMentors = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await ApiService.getDepartments();
      setState(() {
        _departments = depts.cast<Map<String, dynamic>>();
        _loadingDepts = false;
      });
    } catch (_) {
      setState(() => _loadingDepts = false);
    }
  }

  Future<void> _loadMentors(int deptId) async {
    setState(() {
      _loadingMentors = true;
      _mentorId = null;
    });
    try {
      final mentors = await ApiService.getMentors(departmentId: deptId);
      setState(() {
        _mentors = mentors.cast<Map<String, dynamic>>();
        _loadingMentors = false;
      });
    } catch (_) {
      setState(() => _loadingMentors = false);
    }
  }

  @override
  void dispose() {
    _regCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _batchCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role != 'admin' && _deptId == null) {
      setState(() {
        _success = false;
        _message = 'Please select a department.';
      });
      return;
    }
    if (_role == 'student' && _mentorId == null) {
      setState(() {
        _success = false;
        _message = 'Please select a mentor.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    final phone = _phoneCtrl.text.trim();
    // Calculate year_of_study from semester
    final yearOfStudy = _semester != null ? ((_semester! + 1) ~/ 2) : null;

    try {
      await ApiService.createUser({
        'register_number': _regCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': phone, // phone = default password
        'role': _role,
        'phone': phone,
        if (_deptId != null) 'department_id': _deptId,
        if (_mentorId != null) 'mentor_id': _mentorId,
        // Student-only academic fields
        if (_role == 'student' && _semester != null) 'semester': _semester,
        if (_role == 'student' && yearOfStudy != null) 'year_of_study': yearOfStudy,
        if (_role == 'student' && _batchCtrl.text.trim().isNotEmpty)
          'batch': _batchCtrl.text.trim(),
        if (_role == 'student' && _sectionCtrl.text.trim().isNotEmpty)
          'section': _sectionCtrl.text.trim().toUpperCase(),
      });

      // Clear for next entry
      _regCtrl.clear();
      _nameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _batchCtrl.clear();
      _sectionCtrl.clear();
      setState(() {
        _saving = false;
        _success = true;
        _message = 'User created! Default password = phone number.';
        _mentorId = null;
        _semester = null;
      });
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _success = false;
        _message = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create User',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.adminColor,
      ),
      body: _loadingDepts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Role selector ────────────────────────────────────────
                      const Text('Role',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                          children:
                              ['student', 'mentor', 'hod', 'admin'].map((r) {
                        final selected = r == _role;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _role = r;
                                _deptId = null;
                                _mentorId = null;
                                _mentors = [];
                                _semester = null;
                                _batchCtrl.clear();
                                _sectionCtrl.clear();
                              }),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.adminColor
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: selected
                                          ? AppColors.adminColor
                                          : AppColors.divider),
                                ),
                                child: Text(r.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.textSecondary)),
                              ),
                            ),
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 20),

                      // ── Fields ───────────────────────────────────────────────
                      _required(
                          'Register Number', _regCtrl, Icons.badge_outlined,
                          caps: TextCapitalization.characters),
                      _required(
                          'Full Name', _nameCtrl, Icons.person_outline_rounded),
                      _required('Email', _emailCtrl, Icons.email_outlined,
                          keyboard: TextInputType.emailAddress),
                      _required(
                          'Phone Number', _phoneCtrl, Icons.phone_outlined,
                          keyboard: TextInputType.phone,
                          hint: 'Used as default password'),

                      // ── Department dropdown (all except admin) ────────────────
                      if (_role != 'admin') ...[
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: _deptId,
                          decoration: const InputDecoration(
                            labelText: 'Department *',
                            prefixIcon: Icon(Icons.business_rounded, size: 20),
                          ),
                          hint: const Text('Select department'),
                          items: _departments
                              .map((d) => DropdownMenuItem<int>(
                                    value: d['id'] as int,
                                    child: Text(d['name'] as String),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _deptId = val;
                              _mentorId = null;
                            });
                            if (val != null && _role == 'student') {
                              _loadMentors(val);
                            }
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Mentor dropdown (students only) ───────────────────────
                      if (_role == 'student') ...[
                        _loadingMentors
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Row(children: [
                                  SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  SizedBox(width: 10),
                                  Text('Loading mentors...',
                                      style: TextStyle(
                                          color: AppColors.textSecondary)),
                                ]),
                              )
                            : DropdownButtonFormField<int>(
                                value: _mentorId,
                                decoration: const InputDecoration(
                                  labelText: 'Mentor *',
                                  prefixIcon: Icon(
                                      Icons.supervisor_account_rounded,
                                      size: 20),
                                ),
                                hint: Text(_deptId == null
                                    ? 'Select department first'
                                    : _mentors.isEmpty
                                        ? 'No mentors in this department'
                                        : 'Select mentor'),
                                items: _mentors
                                    .map((m) => DropdownMenuItem<int>(
                                          value: m['id'] as int,
                                          child: Text(m['name'] as String),
                                        ))
                                    .toList(),
                                onChanged: _deptId == null || _mentors.isEmpty
                                    ? null
                                    : (val) => setState(() => _mentorId = val),
                                validator: (v) =>
                                    _role == 'student' && v == null
                                        ? 'Required'
                                        : null,
                              ),
                        const SizedBox(height: 14),
                      ],

                      // ── Student academic fields ───────────────────────────────
                      if (_role == 'student') ...[
                        const Text('Academic Info',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 8),

                        // Semester dropdown
                        DropdownButtonFormField<int>(
                          value: _semester,
                          decoration: const InputDecoration(
                            labelText: 'Semester *',
                            prefixIcon: Icon(Icons.numbers_rounded, size: 20),
                          ),
                          hint: const Text('Select semester'),
                          items: List.generate(8, (i) => i + 1)
                              .map((s) => DropdownMenuItem<int>(
                                    value: s,
                                    child: Text(
                                        'Semester $s  (Year ${(s + 1) ~/ 2})'),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _semester = val),
                          validator: (v) => _role == 'student' && v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Batch
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TextFormField(
                            controller: _batchCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Batch *',
                              hintText: 'e.g. 2022-2026',
                              prefixIcon:
                                  Icon(Icons.calendar_today_rounded, size: 20),
                            ),
                            validator: (v) => _role == 'student' && (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),

                        // Section
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TextFormField(
                            controller: _sectionCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Section *',
                              hintText: 'e.g. A',
                              prefixIcon: Icon(Icons.group_rounded, size: 20),
                            ),
                            validator: (v) => _role == 'student' && (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],

                      // ── Info banner ───────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.primary, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Default password = phone number. '
                              'User can change it after first login.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      // ── Result message ────────────────────────────────────────
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (_success
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: (_success
                                          ? AppColors.success
                                          : AppColors.error)
                                      .withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              Icon(
                                  _success
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_rounded,
                                  color: _success
                                      ? AppColors.success
                                      : AppColors.error,
                                  size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(_message!,
                                      style: TextStyle(
                                          color: _success
                                              ? AppColors.success
                                              : AppColors.error,
                                          fontSize: 13))),
                            ]),
                          ),
                        ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _create,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.adminColor),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Create User'),
                        ),
                      ),
                    ]),
              ),
            ),
    );
  }

  Widget _required(String label, TextEditingController ctrl, IconData icon,
          {TextInputType keyboard = TextInputType.text,
          TextCapitalization caps = TextCapitalization.none,
          String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          textCapitalization: caps,
          decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon, size: 20)),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
      );
}
