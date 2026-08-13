import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/notification_bell.dart';
import '../main.dart' show AppRoutes;
import '../services/wallet_service.dart';
import '../services/jobs_service.dart';
import '../services/reviews_service.dart';
import '../services/session_controller.dart';

/// Maps to: performance_insights_dashboard/code.html
class PerformanceInsightsScreen extends StatelessWidget {
  const PerformanceInsightsScreen({super.key});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final uid = SessionController.instance.uid;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('Performance Insights'),
        actions: const [NotificationBellButton()],
      ),
      body: SafeArea(
        child: uid == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, AppSpacing.xl),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.soft),
                    child: FutureBuilder<List<double>>(
                      future: WalletService.instance.weeklyEarningsByDay(uid),
                      builder: (context, snap) {
                        final bars = snap.data ?? List.filled(7, 0.0);
                        final total = bars.fold<double>(0, (a, b) => a + b);
                        final maxVal = bars.fold<double>(1, (a, b) => b > a ? b : a);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Weekly Earnings', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                            Text('Rs. ${total.toStringAsFixed(0)}', style: AppTextStyles.headlineLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              height: 100,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (var i = 0; i < _days.length; i++)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              height: 70 * (bars[i] / maxVal).clamp(0.02, 1.0),
                                              decoration: BoxDecoration(
                                                color: bars[i] == maxVal && maxVal > 0 ? AppColors.primary : AppColors.primaryContainer.withOpacity(0.25),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(_days[i], style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<int>(
                          future: JobsService.instance.countCompletedJobsForWorker(uid),
                          builder: (context, snap) => _StatCard(icon: Symbols.task_alt_rounded, label: 'Jobs Completed', value: '${snap.data ?? '...'}'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FutureBuilder<WorkerRatingSummary>(
                          future: ReviewsService.instance.fetchRatingSummary(uid),
                          builder: (context, snap) => _StatCard(
                            icon: Symbols.star_rounded,
                            label: 'Avg Rating (${snap.data?.count ?? 0})',
                            value: snap.data == null ? '...' : snap.data!.average.toStringAsFixed(1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppTab.profile,
        onTap: (t) {
          if (t == AppTab.home) {
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.workerHome, (r) => r.isFirst);
          } else if (t == AppTab.jobs) {
            Navigator.of(context).pushNamed(AppRoutes.jobHistory);
          } else if (t == AppTab.messages) {
            Navigator.of(context).pushNamed(AppRoutes.notificationsInbox);
          }
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTextStyles.headlineLgMobile.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
