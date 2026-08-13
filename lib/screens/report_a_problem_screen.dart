import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../services/reports_service.dart';
import '../services/session_controller.dart';

/// Maps to: report_a_problem_form/code.html
class ReportAProblemScreen extends StatefulWidget {
  const ReportAProblemScreen({super.key});

  @override
  State<ReportAProblemScreen> createState() => _ReportAProblemScreenState();
}

class _ReportAProblemScreenState extends State<ReportAProblemScreen> {
  static const _issues = ['Payment Issue', 'Job Quality', 'Safety Concern', 'App Technical Issue'];
  String? _issue;
  final _detailsController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _evidenceBytes;
  bool _picking = false;
  bool _submitting = false;

  Future<void> _submit() async {
    final uid = SessionController.instance.uid;
    if (_issue == null || uid == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ReportsService.instance.submit(
        reporterId: uid,
        issue: _issue!,
        details: _detailsController.text.trim(),
        evidenceBytes: _evidenceBytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute submitted. Our team will review shortly.')));
      Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  /// Opens the device's photo library / file picker so the user can attach
  /// a real photo from their phone as proof.
  Future<void> _pickEvidence() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final XFile? shot = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (shot == null) return; // user backed out of the picker
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() => _evidenceBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open storage: $e')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Report a Problem'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, AppSpacing.xl),
          children: [
            Text('What is the issue?', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _issue,
              hint: const Text('Select an option'),
              items: [for (final i in _issues) DropdownMenuItem(value: i, child: Text(i))],
              onChanged: (v) => setState(() => _issue = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Tell us more', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _detailsController,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'Describe what happened in detail...'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Evidence (Optional)', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: _pickEvidence,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.outlineVariant, style: BorderStyle.solid),
                ),
                child: _evidenceBytes != null
                    ? Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Image.memory(_evidenceBytes!, height: 120, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Symbols.check_circle_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 6),
                              Text('Photo attached · tap to change', style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _picking
                              ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Symbols.camera_alt_rounded, color: AppColors.primary, size: 28),
                          const SizedBox(height: 6),
                          Text('Upload Photo Evidence', style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_issue == null || _submitting) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.surfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                ),
                child: Text(_submitting ? 'Submitting...' : 'Submit Dispute', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
