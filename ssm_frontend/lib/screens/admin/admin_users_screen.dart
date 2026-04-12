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
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String role;
  final VoidCallback onToggle;
  const _UserTile({required this.user, required this.role, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] as bool? ?? true;
    final color = isActive ? AppColors.success : AppColors.textLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
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
          if (user['department_id'] != null)
            Text('Dept ID: ${user['department_id']}',
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
          const SizedBox(width: 8),
          Switch(
            value: isActive,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.success,
          ),
        ]),
      ),
    );
  }
}
