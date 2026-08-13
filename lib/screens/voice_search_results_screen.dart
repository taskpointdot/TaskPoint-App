import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/app_user.dart';
import '../models/ui_models.dart';
import '../theme/app_theme.dart';
import '../services/geo_utils.dart';
import '../services/reviews_service.dart';
import '../services/workers_service.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/post_job_sheet.dart';
import '../services/jobs_service.dart';
import '../services/session_controller.dart';
import 'request_success_screen.dart';
import 'worker_profile_detail_screen.dart';

/// Provider profiles matching what the seeker just said out loud.
///
/// This is the payoff for the mic button: rather than dumping the transcript
/// into a chat and stopping there, the spoken request is resolved to a
/// service category and the people who can actually do that work are listed,
/// nearest and available first.
class VoiceSearchResultsScreen extends StatelessWidget {
  final ServiceCategory category;

  /// What the seeker actually said, echoed at the top so a mis-heard phrase
  /// is obvious rather than silently returning the wrong trade.
  final String transcript;

  /// Rupee amount heard in the request, used to pre-fill the post-job sheet.
  final double? spokenBudget;

  /// Seeker's position, for the distance readout and radius filter.
  final GeoPoint? origin;

  const VoiceSearchResultsScreen({
    super.key,
    required this.category,
    required this.transcript,
    this.spokenBudget,
    this.origin,
  });

  Future<void> _postToAll(BuildContext context) async {
    final details = await showPostJobSheet(
      context,
      categoryName: category.name,
      categoryIcon: category.icon,
      initialDescription: transcript.trim().isEmpty ? null : transcript.trim(),
      initialBudget: spokenBudget,
    );
    if (details == null || !context.mounted) return;
    final uid = SessionController.instance.uid;
    if (uid == null) return;
    final jobId = await JobsService.instance.postJob(
      seekerId: uid,
      categoryId: category.id.isEmpty ? null : category.id,
      categoryName: category.name,
      description: details.description,
      budget: details.budget,
      location: origin,
    );
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestSuccessScreen(jobId: jobId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: category.name),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Symbols.graphic_eq_rounded, color: AppColors.onSecondaryContainer, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('You said', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSecondaryContainer)),
                        Text('"$transcript"',
                            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSecondaryContainer)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<WorkerSearchResult>(
                stream: WorkersService.instance.watchWorkersForCategory(
                  categoryName: category.name,
                  near: origin,
                ),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final result = snap.data!;
                  if (result.isEmpty) {
                    return _EmptyState(category: category, onPost: () => _postToAll(context));
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      if (result.isFallback)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.statusAmberBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Icon(Symbols.info_rounded, size: 18, color: AppColors.statusAmberFg),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No one nearby lists "${category.name}" as a skill yet. '
                                  'Showing all providers near you instead.',
                                  style: AppTextStyles.labelSm.copyWith(color: AppColors.statusAmberFg),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${result.workers.length} ${result.workers.length == 1 ? 'provider' : 'providers'} available',
                            style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      for (final worker in result.workers) ...[
                        _WorkerResultCard(worker: worker, origin: origin),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _postToAll(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                  ),
                  icon: const Icon(Symbols.campaign_rounded),
                  label: const Text('Broadcast to all of them'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onPost;
  const _EmptyState({required this.category, required this.onPost});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(category.icon, size: 48, color: AppColors.outlineVariant),
            const SizedBox(height: 12),
            Text('No providers near you yet', style: AppTextStyles.headlineMd, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Post the job anyway — it will reach any ${category.name.toLowerCase()} '
              'who comes online nearby.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerResultCard extends StatelessWidget {
  final AppUser worker;
  final GeoPoint? origin;
  const _WorkerResultCard({required this.worker, required this.origin});

  @override
  Widget build(BuildContext context) {
    final distance = (origin != null && worker.location != null)
        ? distanceKm(origin!, worker.location!)
        : null;
    final name = worker.name.trim().isEmpty ? 'Provider' : worker.name.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkerProfileDetailScreen(workerId: worker.uid, workerName: name),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  child: Text(name[0].toUpperCase(), style: AppTextStyles.headlineMd),
                ),
                if (worker.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.onlineDot,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(name, style: AppTextStyles.labelLg, overflow: TextOverflow.ellipsis)),
                      if (worker.cnicStatus == CnicStatus.verified) ...[
                        const SizedBox(width: 6),
                        const Icon(Symbols.verified_rounded, size: 16, color: AppColors.primary, fill: 1),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  FutureBuilder<WorkerRatingSummary>(
                    future: ReviewsService.instance.fetchRatingSummary(worker.uid),
                    builder: (context, snap) {
                      final summary = snap.data;
                      return Row(
                        children: [
                          const Icon(Symbols.star_rounded, size: 14, color: AppColors.starGold, fill: 1),
                          const SizedBox(width: 3),
                          Text(
                            summary == null
                                ? '…'
                                : summary.count == 0
                                    ? 'New provider'
                                    : '${summary.average.toStringAsFixed(1)} (${summary.count})',
                            style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                          if (distance != null) ...[
                            const SizedBox(width: 10),
                            const Icon(Symbols.location_on_rounded, size: 14, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 2),
                            Text('${distance.toStringAsFixed(1)} km',
                                style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          ],
                        ],
                      );
                    },
                  ),
                  if (worker.skills.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final skill in worker.skills.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(skill, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Symbols.chevron_right_rounded, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}
