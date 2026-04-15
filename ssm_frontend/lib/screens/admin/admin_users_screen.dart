import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _roles = ['student', 'mentor', 'hod', 'admin'];

  // Per-tab state
  final Map<String, List<dynamic>> _users = {};
  final Map<String, bool> _loading = {};
  final Map<String, String?> _error = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _roles.length, vsync: this);
    for (final r in _roles) _loadRole(r);
  }

  Future<void> _loadRole(String role) async {
    setState(() { _loading[role] = true; _error[role] = null; });
    try {
      final data = await ApiService.getUsers(role: role);
      setState(() { _users[role] = data['items'] ?? []; _loading[role] = false; });
    } on ApiException catch (e) {
      setState(() { _error[role] = e.message; _loading[role] = false; });
    }
  }

  Future<void> _toggle(String role, int userId, bool current) async {
    try {
      await ApiService.toggleUserActive(userId);
      _loadRole(role);
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.adminColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Bulk CSV Import',
            onPressed: () async {
              await context.push('/admin/import');
              for (final r in _roles) _loadRole(r);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add User',
            onPressed: () async {
              await context.push('/admin/create-user');
              for (final r in _roles) _loadRole(r);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: _roles.map((r) => Tab(text: r.toUpperCase())).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _roles.map((role) {
          if (_loading[role] == true) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error[role] != null) {
            return Center(child: ErrorBanner(_error[role]!));
          }
          final users = _users[role] ?? [];
          if (users.isEmpty) {
            return Center(
              child: Text('No $role accounts yet.',
                  style: const TextStyle(color: AppColors.textSecondary)));
          }
          return RefreshIndicator(
            onRefresh: () => _loadRole(role),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              itemBuilder: (_, i) => _UserTile(
                user: users[i],
                role: role,
                onToggle: () => _toggle(role, users[i]['id'], users[i]['is_active']),
                onTap: () => _showUserDetail(context, users[i], role),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showUserDetail(BuildContext context, Map<String, dynamic> user, String role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                    (user['name'] ?? '?').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    Text(role.toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (user['is_active'] == true
                            ? AppColors.success
                            : AppColors.textLight)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (user['is_active'] == true
                              ? AppColors.success
                              : AppColors.textLight)
                          .withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    user['is_active'] == true ? 'Active' : 'Inactive',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: user['is_active'] == true
                            ? AppColors.success
                            : AppColors.textLight),
                  ),
                ),
              ]),
              const Divider(height: 28),
              _DetailRow(Icons.badge_outlined, 'Register No.', user['register_number']),
              _DetailRow(Icons.email_outlined, 'Email', user['email']),
              _DetailRow(Icons.phone_outlined, 'Phone', user['phone']),
              _DetailRow(Icons.business_rounded, 'Department', user['department_name']),
              if (user['mentor_name'] != null)
                _DetailRow(Icons.supervisor_account_rounded, 'Mentor', user['mentor_name']),
              if (user['semester'] != null)
                _DetailRow(Icons.numbers_rounded, 'Semester', user['semester'].toString()),
              if (user['batch'] != null)
                _DetailRow(Icons.calendar_today_rounded, 'Batch', user['batch']),
              if (user['section'] != null)
                _DetailRow(Icons.group_rounded, 'Section', user['section']),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.toggle_on_rounded),
                  label: Text(user['is_active'] == true
                      ? 'Deactivate User'
                      : 'Activate User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: user['is_active'] == true
                        ? AppColors.error
                        : AppColors.success,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _toggle(role, user['id'], user['is_active']);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String role;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.role, required this.onToggle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] as bool? ?? true;
    final color = isActive ? AppColors.success : AppColors.textLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isActive
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.divider,
          child: Text(
            (user['name'] ?? '?').substring(0, 1).toUpperCase(),
            style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(user['name'] ?? '',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.textPrimary : AppColors.textSecondary)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user['register_number'] ?? user['email'] ?? '',
              style: const TextStyle(fontSize: 12)),
          if (user['department_name'] != null)
            Text(user['department_name'],
                style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(isActive ? 'Active' : 'Inactive',
                style: TextStyle(color: color, fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textLight, size: 20),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        Expanded(
          child: Text(value!,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary)),
        ),
      ]),
    );
  }
}
