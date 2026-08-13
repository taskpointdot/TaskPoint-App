import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/buttons.dart';
import '../services/jobs_service.dart';
import '../services/reviews_service.dart';
import '../services/session_controller.dart';
import 'home_dashboard_screen.dart';

/// Maps to: job_completed_review/code.html
class JobCompletedReviewScreen extends StatefulWidget {
  final String jobId;
  const JobCompletedReviewScreen({super.key, required this.jobId});

  @override
  State<JobCompletedReviewScreen> createState() => _JobCompletedReviewScreenState();
}

class _JobCompletedReviewScreenState extends State<JobCompletedReviewScreen> {
  int rating = 0;
  final feedbackController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (rating == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      final job = await JobsService.instance.getJob(widget.jobId);
      final me = SessionController.instance.user;
      if (job?.acceptedWorkerId != null && me != null) {
        await ReviewsService.instance.submitReview(
          jobId: widget.jobId,
          workerId: job!.acceptedWorkerId!,
          seekerId: me.uid,
          seekerName: me.name,
          rating: rating,
          comment: feedbackController.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Kaam Mukammal Ho Gaya'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: AppShadows.soft),
              child: Column(
                children: [
                  Text('Rate your experience', style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < rating;
                      return IconButton(
                        onPressed: () => setState(() => rating = i + 1),
                        icon: Icon(Symbols.star_rounded, size: 32, fill: filled ? 1.0 : 0.0, color: filled ? AppColors.starGold : AppColors.outlineVariant),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feedbackController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Apna tajarba likhain... (Write your experience)',
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: AppColors.outlineVariant)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.outlineVariant)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: AppShadows.soft),
                    child: const Icon(Symbols.payments_rounded, color: AppColors.primary, fill: 1),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Naqad adayigi worker ko barah-e-raast kar di gayi', style: AppTextStyles.labelLg),
                        Text('Cash handed over to worker directly', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _submitting ? 'Submitting...' : 'Review Jama Karwain',
              onPressed: (rating == 0 || _submitting) ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
