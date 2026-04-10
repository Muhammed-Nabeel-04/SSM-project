import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getStudentDashboard();
      setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _createForm() async {
    try {
      final res = await ApiService.createForm(AppStrings.academicYear);
      if (mounted) context.push('/student/form/${res['form_id']}');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final forms = (_data?['forms'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('My Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(_data?['student'] ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await auth.logout();
            },
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
                    // ── INFO HEADER ──────────────────────────────
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.person_rounded,
                                color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                              _data?['student'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${forms.length} form(s) submitted',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ]),
                        ]),
                      ),
                    ),

                    // ── FORMS LIST ───────────────────────────────
                    if (forms.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(children: [
                            Icon(Icons.assignment_outlined,
                                size: 64,
                                color: AppColors.textLight.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text('No SSM form yet',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16)),
                            const SizedBox(height: 8),
                            const Text(
                                'Create your first form for this academic year',
                                style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 13),
                                textAlign: TextAlign.center),
                          ]),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _FormCard(form: forms[i]),
                            childCount: forms.length,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createForm,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Form',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final Map<String, dynamic> form;
  const _FormCard({required this.form});

  @override
  Widget build(BuildContext context) {
    final score = form['score'];
    final status = form['status'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (status == 'approved') {
            context.push('/student/form/${form['form_id']}/score');
          } else {
            context.push('/student/form/${form['form_id']}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.assignment_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AY ${form['academic_year']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              StatusBadge(status),
            ]),
            if (score != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  '${score['grand_total']?.toStringAsFixed(0)} / 500',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.primary),
                ),
                StarRating(stars: score['star_rating'] as int),
              ]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              const Spacer(),
              Text(
                status == 'approved' ? 'View Score →' : 'Open Form →',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
