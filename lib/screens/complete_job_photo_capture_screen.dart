import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../models/job.dart';
import '../services/jobs_service.dart';
import '../services/wallet_service.dart';
import '../services/session_controller.dart';
import 'job_completion_receipt_screen.dart';

/// Maps to: complete_job_photo_capture/code.html
/// Real gallery photo capture (same `image_picker` pattern as the CNIC
/// screens) uploaded to Storage, then marks the job complete and credits
/// the worker's wallet.
class CompleteJobPhotoCaptureScreen extends StatefulWidget {
  final String jobId;
  const CompleteJobPhotoCaptureScreen({super.key, required this.jobId});

  @override
  State<CompleteJobPhotoCaptureScreen> createState() => _CompleteJobPhotoCaptureScreenState();
}

class _CompleteJobPhotoCaptureScreenState extends State<CompleteJobPhotoCaptureScreen> {
  final _picker = ImagePicker();
  Uint8List? _before;
  Uint8List? _after;
  bool _submitting = false;

  Future<void> _pick(bool isBefore) async {
    final shot = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    setState(() {
      if (isBefore) {
        _before = bytes;
      } else {
        _after = bytes;
      }
    });
  }

  Future<void> _submit(Job job) async {
    if (_before == null || _after == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final beforeUrl = await JobsService.instance.uploadJobPhoto(jobId: widget.jobId, side: 'before', bytes: _before!);
      final afterUrl = await JobsService.instance.uploadJobPhoto(jobId: widget.jobId, side: 'after', bytes: _after!);
      await JobsService.instance.markCompleted(widget.jobId, beforePhotoUrls: [beforeUrl], afterPhotoUrls: [afterUrl]);
      final uid = SessionController.instance.uid;
      if (uid != null) {
        await WalletService.instance.recordEarning(uid: uid, jobId: widget.jobId, amount: job.acceptedPrice ?? job.budget, label: job.categoryName);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => JobCompletionReceiptScreen(jobId: widget.jobId)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Complete Job'),
      body: SafeArea(
        child: StreamBuilder<Job>(
          stream: JobsService.instance.watchJob(widget.jobId),
          builder: (context, snap) {
            final job = snap.data;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Job Photos', textAlign: TextAlign.center, style: AppTextStyles.headlineLgMobile),
                  const SizedBox(height: 4),
                  Text('Please upload clear photos before and after the work.', textAlign: TextAlign.center, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _PhotoCard(label: 'Before', localLabel: '(Pehle)', bytes: _before, onTap: () => _pick(true))),
                      const SizedBox(width: 16),
                      Expanded(child: _PhotoCard(label: 'After', localLabel: '(Baad Mein)', bytes: _after, onTap: () => _pick(false))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.surfaceVariant), boxShadow: AppShadows.soft),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Service', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                            Text(job?.categoryName ?? '...', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Payout', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                            Text('Rs. ${(job?.acceptedPrice ?? job?.budget ?? 0).toStringAsFixed(0)}', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_before != null && _after != null && !_submitting && job != null) ? () => _submit(job) : null,
                      icon: const Icon(Symbols.check_circle_rounded),
                      label: Text(_submitting ? 'Submitting...' : 'Collect Cash & Mark Complete'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandTeal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Cash Jama Karain aur Kaam Khatam', textAlign: TextAlign.center, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String label;
  final String localLabel;
  final Uint8List? bytes;
  final VoidCallback onTap;
  const _PhotoCard({required this.label, required this.localLabel, required this.bytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final taken = bytes != null;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: taken ? AppColors.primary : Colors.transparent, width: 2),
            boxShadow: AppShadows.soft,
          ),
          child: taken
              ? Image.memory(bytes!, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                      child: Icon(Symbols.photo_camera_rounded, size: 32, color: AppColors.primary, fill: 1),
                    ),
                    const SizedBox(height: 16),
                    Text(label, style: AppTextStyles.labelLg),
                    Text(localLabel, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
        ),
      ),
    );
  }
}
