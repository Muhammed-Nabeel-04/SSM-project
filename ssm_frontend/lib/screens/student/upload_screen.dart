import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../config/constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class UploadScreen extends StatefulWidget {
  final int formId;
  const UploadScreen({required this.formId, super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String _category = 'development';
  String _docType = 'nptel_certificate';
  File? _pickedFile;
  bool _uploading = false;
  String? _resultMessage;
  bool _success = false;

  final _docTypes = const [
    ('nptel_certificate', 'NPTEL Certificate'),
    ('online_cert', 'Online Course Certificate'),
    ('internship_letter', 'Internship Letter / Certificate'),
    ('competition_cert', 'Competition Certificate'),
    ('publication_proof', 'Publication Proof / Patent'),
    ('project_report', 'Project Report'),
    ('placement_offer', 'Placement Offer Letter'),
    ('leadership_proof', 'Leadership Appointment Letter'),
    ('other', 'Other Document'),
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _pickedFile = File(result.files.single.path!));
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a file first')));
      return;
    }

    setState(() { _uploading = true; _resultMessage = null; });

    try {
      final res = await ApiService.uploadDocument(
        formId: widget.formId,
        category: _category,
        documentType: _docType,
        file: _pickedFile!,
      );

      final status = res['verification_status'];
      final note = res['verification_note'] ?? '';
      setState(() {
        _uploading = false;
        _success = status == 'valid';
        _resultMessage = _statusMessage(status, note);
        _pickedFile = null;
      });
    } on ApiException catch (e) {
      setState(() { _uploading = false; _success = false; _resultMessage = e.message; });
    }
  }

  String _statusMessage(String status, String note) => switch (status) {
    'valid' => '✅ Certificate verified successfully!',
    'review' => '⚠️ Needs manual review by mentor. $note',
    'invalid' => '❌ Verification failed. $note — Mentor will check.',
    _ => 'Uploaded. $note',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Documents')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Upload supporting documents for your SSM activities.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          AppDropdown<String>(
            label: 'Category',
            value: _category,
            onChanged: (v) => setState(() => _category = v!),
            items: const [
              DropdownMenuItem(value: 'academic', child: Text('Academic Performance')),
              DropdownMenuItem(value: 'development', child: Text('Student Development')),
              DropdownMenuItem(value: 'skill', child: Text('Skill & Professional')),
              DropdownMenuItem(value: 'discipline', child: Text('Discipline & Contribution')),
              DropdownMenuItem(value: 'leadership', child: Text('Leadership')),
            ],
          ),

          AppDropdown<String>(
            label: 'Document Type',
            value: _docType,
            onChanged: (v) => setState(() => _docType = v!),
            items: _docTypes.map((t) =>
                DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
          ),

          const SizedBox(height: 8),

          // File picker area
          InkWell(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(
                    color: _pickedFile != null
                        ? AppColors.success
                        : AppColors.divider,
                    width: 2,
                    style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: _pickedFile != null
                    ? AppColors.success.withOpacity(0.05)
                    : AppColors.background,
              ),
              child: Column(children: [
                Icon(
                  _pickedFile != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  size: 40,
                  color: _pickedFile != null
                      ? AppColors.success
                      : AppColors.textLight,
                ),
                const SizedBox(height: 8),
                Text(
                  _pickedFile != null
                      ? _pickedFile!.path.split('/').last
                      : 'Tap to pick PDF, JPG or PNG',
                  style: TextStyle(
                      color: _pickedFile != null
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                if (_pickedFile == null)
                  const Text('Max 5 MB',
                      style: TextStyle(
                          color: AppColors.textLight, fontSize: 12)),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          if (_resultMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _success
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.mentorReview.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _success
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.mentorReview.withOpacity(0.3)),
              ),
              child: Text(_resultMessage!,
                  style: TextStyle(
                      color: _success
                          ? AppColors.success
                          : AppColors.textPrimary,
                      fontSize: 13)),
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_uploading ? 'Uploading...' : 'Upload Document'),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            '💡 Tip: Image files (JPG/PNG) go through automatic OCR verification. PDF documents are verified by your mentor.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ]),
      ),
    );
  }
}
