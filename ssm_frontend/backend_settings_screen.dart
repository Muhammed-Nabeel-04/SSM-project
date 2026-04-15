// File: lib/screens/admin/backend_settings_screen.dart
// Utility screen for developers/principals to configure the API endpoint URL

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/app_config.dart';

class BackendSettingsScreen extends StatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  State<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends State<BackendSettingsScreen> {
  final _customUrlController = TextEditingController();
  String _currentUrl = '';
  bool _isTestingConnection = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _currentUrl = AppConfig.backendUrl;
    _customUrlController.text = _currentUrl;
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$_currentUrl/'))
          .timeout(const Duration(seconds: 5));

      setState(() {
        _isTestingConnection = false;
        _connectionStatus = response.statusCode == 200
            ? 'Connected successfully! ✅'
            : 'Server reachable, but returned error ${response.statusCode}';
      });
    } catch (e) {
      setState(() {
        _isTestingConnection = false;
        _connectionStatus = 'Cannot connect to server ❌';
      });
    }
  }

  Future<void> _saveAndApply() async {
    // Save current URL to local storage/config
    await AppConfig.setBackendUrl(_currentUrl);

    // Re-verify connection after saving
    await _testConnection();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend endpoint updated'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetToDefault() async {
    await AppConfig.reset();
    setState(() {
      _currentUrl = AppConfig.backendUrl;
      _customUrlController.text = _currentUrl;
      _connectionStatus = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset to factory default'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _setPreset(String preset) {
    setState(() {
      if (preset == 'emulator') {
        _currentUrl = AppConfig.urlEmulator;
      } else if (preset == 'localhost') {
        _currentUrl = AppConfig.urlLocalhost;
      }
      _customUrlController.text = _currentUrl;
      _connectionStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BACKEND CONFIGURATION',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active URL Display
            _buildSectionTitle('ACTIVE ENDPOINT', cs),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lan_outlined, color: cs.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentUrl,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Quick Presets
            _buildSectionTitle('QUICK PRESETS', cs),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPresetButton(
                    'Android Emulator',
                    'emulator',
                    _currentUrl == AppConfig.urlEmulator,
                    cs,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPresetButton(
                    'Localhost (Web)',
                    'localhost',
                    _currentUrl == AppConfig.urlLocalhost,
                    cs,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Custom URL Input
            _buildSectionTitle('MANUAL URL OVERRIDE', cs),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.onSurface.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _customUrlController,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'http://192.168.x.x:8000',
                  hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.3)),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.link, size: 20),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                ),
                onChanged: (val) => setState(() {
                  _currentUrl = val.trim();
                  _connectionStatus = null;
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Network Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'For real devices, use your computer\'s IPv4 address. Ensure both devices are on the same WiFi network.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Connection Status Feedback
            if (_connectionStatus != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _connectionStatus!.contains('✅')
                      ? Colors.green.withOpacity(0.1)
                      : cs.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _connectionStatus!.contains('✅')
                        ? Colors.green
                        : cs.error,
                  ),
                ),
                child: Text(
                  _connectionStatus!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _connectionStatus!.contains('✅')
                        ? Colors.green
                        : cs.error,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isTestingConnection ? null : _saveAndApply,
                icon: _isTestingConnection
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isTestingConnection ? 'TESTING...' : 'SAVE & APPLY',
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Factory Reset
            Center(
              child: TextButton.icon(
                onPressed: _resetToDefault,
                icon: const Icon(Icons.settings_backup_restore, size: 18),
                label: const Text('RESET TO FACTORY DEFAULT'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurface.withOpacity(0.5),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme cs) {
    return Text(
      title,
      style: TextStyle(
        color: cs.onSurface.withOpacity(0.5),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPresetButton(
    String label,
    String preset,
    bool isSelected,
    ColorScheme cs,
  ) {
    return InkWell(
      onTap: () => _setPreset(preset),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withOpacity(0.1) : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.7),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
