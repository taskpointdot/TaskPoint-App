import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../services/jobs_service.dart';
import '../services/session_controller.dart';
import 'negotiate_price_screen.dart';
import 'track_customer_location_screen.dart';

/// Maps to: job_notification_pop_up/code.html
/// Full-screen "incoming job" alert for [jobId], shown to a worker before
/// the job is actually accepted.
class JobNotificationPopupScreen extends StatefulWidget {
  final String jobId;
  const JobNotificationPopupScreen({super.key, required this.jobId});

  @override
  State<JobNotificationPopupScreen> createState() => _JobNotificationPopupScreenState();
}

class _JobNotificationPopupScreenState extends State<JobNotificationPopupScreen> {
  bool _accepting = false;

  Future<void> _acceptPrice(Job job) async {
    final me = SessionController.instance.user;
    if (me == null || _accepting) return;
    setState(() => _accepting = true);
    try {
      await JobsService.instance.placeBid(jobId: widget.jobId, workerId: me.uid, workerName: me.name, price: job.budget);
      final bids = await JobsService.instance.watchBids(widget.jobId).first;
      final myBid = bids.firstWhere((b) => b.workerId == me.uid);
      await JobsService.instance.acceptBid(jobId: widget.jobId, bid: myBid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TrackCustomerLocationScreen(jobId: widget.jobId)));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inverseSurface.withOpacity(0.55),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: StreamBuilder<Job>(
              stream: JobsService.instance.watchJob(widget.jobId),
              builder: (context, snap) {
                final job = snap.data;
                if (job == null) {
                  return const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator());
                }
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: AppShadows.active),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(AppRadius.full)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(job.categoryIcon, size: 16, color: AppColors.onSecondaryContainer),
                                const SizedBox(width: 4),
                                Text(job.categoryName.toUpperCase(), style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700, color: AppColors.onSecondaryContainer)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(job.description, textAlign: TextAlign.center, style: AppTextStyles.headlineMd),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Column(
                          children: [
                            Text('Budget', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text('Rs. ${job.budget.toStringAsFixed(0)}', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _accepting ? null : () => _acceptPrice(job),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
                          icon: const Icon(Symbols.check_circle_rounded, size: 20),
                          label: Text(_accepting ? 'Accepting...' : 'Accept Price', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _accepting
                              ? null
                              : () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => NegotiatePriceScreen(jobId: widget.jobId, jobTitle: job.categoryName, categoryIcon: job.categoryIcon, estimatedRange: 'Rs. ${job.budget.toStringAsFixed(0)}'),
                                    ),
                                  ),
                          icon: const Icon(Symbols.avg_time_rounded, size: 18),
                          label: const Text('Counter-Offer'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text('Skip', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
