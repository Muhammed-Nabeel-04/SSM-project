import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class MentorActivityDetailScreen extends StatefulWidget {
  final String activityId;
  const MentorActivityDetailScreen({super.key, required this.activityId});

  @override
  State<MentorActivityDetailScreen> createState() =>
      _MentorActivityDetailScreenState();
}

class _MentorActivityDetailScreenState
    extends State<MentorActivityDetailScreen> {
  Map<String, dynamic>? _activity;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getMentorActivityDetail(
          int.parse(widget.activityId));
      setState(() {
        _activity = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
      }
    }
  }

  Future<void> _openFile() async {
    final url = _activity?['file_url'];
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open file')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity Details')),
        body: const Center(child: Text('Activity not found')),
      );
    }

    final status = (_activity!['status'] ?? 'pending').toLowerCase();
    final data = _activity!['data'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Details'),
        actions: [
          if (_activity!['file_url'] != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Open Certificate',
              onPressed: _openFile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Card ──────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _activity!['activity_name'] ?? 'Activity',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.person_rounded,
                      label: 'Student',
                      value: _activity!['student_name'] ?? '',
                    ),
                    _InfoRow(
                      icon: Icons.badge_rounded,
                      label: 'Register No',
                      value: _activity!['register_number'] ?? '',
                    ),
                    if (_activity!['submitted_date'] != null)
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Submitted',
                        value: _activity!['submitted_date'],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Certificate/File ─────────────────────────────────────────
            if (_activity!['file_url'] != null) ...[
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.attach_file_rounded,
                        color: Colors.white, size: 20),
                  ),
                  title: Text(_activity!['filename'] ?? 'Certificate'),
                  subtitle: const Text('Tap to view'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: _openFile,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Rejection Reason ─────────────────────────────────────────
            if (status == 'rejected' &&
                _activity!['rejection_reason'] != null) ...[
              Card(
                color: AppColors.rejected.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.rejected, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Rejection Reason',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.rejected,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activity!['rejection_reason'],
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Activity Data ────────────────────────────────────────────
            if (data.isNotEmpty) ...[
              const Text(
                'Activity Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: data.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _InfoRow(
                                icon: Icons.circle,
                                iconSize: 8,
                                label: _formatKey(e.key),
                                value: e.value.toString(),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final double? iconSize;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    this.iconSize,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: iconSize ?? 16, color: AppColors.textLight),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
