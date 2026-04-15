import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class FirstSetupScreen extends StatefulWidget {
  const FirstSetupScreen({super.key});

  @override
  State<FirstSetupScreen> createState() => _FirstSetupScreenState();
}

class _FirstSetupScreenState extends State<FirstSetupScreen> {
  final _depts = <Map<String, String>>[]; // pending to save
  final _existing = <Map<String, dynamic>>[]; // already in DB
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _saving = false;
  bool _loadingExisting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final depts = await ApiService.getDepartments();
      setState(() {
        _existing.addAll(depts.cast<Map<String, dynamic>>());
        _loadingExisting = false;
      });
    } catch (_) {
      setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _addToList() {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) return;
    setState(() {
      _depts.add({'name': name, 'code': code});
      _nameCtrl.clear();
      _codeCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (_depts.isEmpty && _existing.isEmpty) {
      setState(() => _error = 'Add at least one department.');
      return;
    }
    if (_depts.isEmpty) {
      // Already has departments — just go to dashboard
      // Clear mustChangePassword so admin isn't redirected here again
      if (mounted) {
        context.read<AuthProvider>().clearMustChangePassword();
        context.go('/admin/dashboard');
      }
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      for (final d in _depts) {
        await ApiService.createDepartment(d['name']!, d['code']!);
      }
      if (mounted) {
        // Clear mustChangePassword so admin isn't bounced back here
        context.read<AuthProvider>().clearMustChangePassword();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Departments saved!'),
          backgroundColor: AppColors.success,
        ));
        context.go('/admin/dashboard');
      }
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.adminColor,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text('Department Setup',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            color: AppColors.adminColor,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.apartment_rounded,
                  color: Colors.white, size: 36),
              const SizedBox(height: 12),
              const Text('Department Setup',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Add your college departments here.\n'
                'You can always come back to add more.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ]),
          ),

          Expanded(
            child: _loadingExisting
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Existing departments from DB ─────────────────
                          if (_existing.isNotEmpty) ...[
                            const Text('Existing Departments',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            ..._existing.map((d) => Card(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          AppColors.success.withOpacity(0.1),
                                      child: const Icon(Icons.check_rounded,
                                          color: AppColors.success, size: 14),
                                    ),
                                    title: Text(d['name'] as String,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    subtitle: Text('Code: ${d['code']}',
                                        style: const TextStyle(fontSize: 11)),
                                  ),
                                )),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                          ],

                          // ── Add new department ───────────────────────────
                          const Text('Add New Department',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 12),

                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _nameCtrl,
                                    decoration: const InputDecoration(
                                        labelText: 'Department Name',
                                        hintText: 'e.g. Computer Science'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _codeCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                        labelText: 'Code',
                                        hintText: 'e.g. CSE'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: IconButton.filled(
                                    onPressed: _addToList,
                                    icon: const Icon(Icons.add_rounded),
                                    style: IconButton.styleFrom(
                                        backgroundColor: AppColors.adminColor),
                                  ),
                                ),
                              ]),
                          const SizedBox(height: 16),

                          // ── Pending list ─────────────────────────────────
                          if (_depts.isEmpty && _existing.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.divider.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: const Text(
                                  'No departments yet. Add one above.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                            )
                          else
                            ...(_depts.asMap().entries.map((e) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          AppColors.adminColor.withOpacity(0.1),
                                      child: Text(
                                          e.value['code']!.substring(0, 1),
                                          style: const TextStyle(
                                              color: AppColors.adminColor,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    title: Text(e.value['name']!,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text('Code: ${e.value['code']}',
                                        style: const TextStyle(fontSize: 12)),
                                    trailing: IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppColors.error,
                                          size: 20),
                                      onPressed: () => setState(
                                          () => _depts.removeAt(e.key)),
                                    ),
                                  ),
                                ))),

                          const SizedBox(height: 20),

                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: ErrorBanner(_error!),
                            ),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.adminColor),
                              child: _saving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Text(_depts.isEmpty
                                      ? 'Continue to Dashboard'
                                      : 'Save ${_depts.length} Department(s) & Continue'),
                            ),
                          ),
                        ]),
                  ),
          ),
        ]),
      ),
    );
  }
}
