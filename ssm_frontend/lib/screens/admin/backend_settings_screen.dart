import 'package:flutter/material.dart';
import '../../core/app_config.dart';
import '../../config/constants.dart';

class BackendSettingsScreen extends StatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  State<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends State<BackendSettingsScreen> {
  late TextEditingController _urlController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppConfig.backendUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _saving = true);
    await AppConfig.setBackendUrl(url);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend URL saved. Restart the app to apply.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _reset() async {
    await AppConfig.reset();
    _urlController.text = AppConfig.backendUrl;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reset to default URL')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backend Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend Server URL',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set the URL of your FastAPI backend. Use 10.0.2.2:8000 for Android emulator.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'http://10.0.2.2:8000',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save URL'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: 32),
            _UrlPreset(
              label: 'Android Emulator',
              url: AppConfig.urlEmulator,
              onTap: () => _urlController.text = AppConfig.urlEmulator,
            ),
            _UrlPreset(
              label: 'Localhost / iOS Sim',
              url: AppConfig.urlLocalhost,
              onTap: () => _urlController.text = AppConfig.urlLocalhost,
            ),
          ],
        ),
      ),
    );
  }
}

class _UrlPreset extends StatelessWidget {
  final String label;
  final String url;
  final VoidCallback onTap;

  const _UrlPreset({
    required this.label,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.dns_rounded, color: AppColors.primary),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Text(
        url,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: TextButton(onPressed: onTap, child: const Text('Use')),
    );
  }
}
