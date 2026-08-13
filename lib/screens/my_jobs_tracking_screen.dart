import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../main.dart' show AppRoutes;
import '../models/job.dart';
import '../services/job_navigation.dart';
import '../services/jobs_service.dart';
import '../services/session_controller.dart';

enum _Filter { active, completed, cancelled }

/// Maps to: my_jobs_tracking/code.html
class MyJobsTrackingScreen extends StatefulWidget {
  const MyJobsTrackingScreen({super.key});

  @override
  State<MyJobsTrackingScreen> createState() => _MyJobsTrackingScreenState();
}

class _MyJobsTrackingScreenState extends State<MyJobsTrackingScreen> {
  _Filter filter = _Filter.active;

  bool _matches(Job j) => switch (filter) {
        _Filter.active => j.isActive,
        _Filter.completed => j.status == JobStatus.completed,
        _Filter.cancelled => j.status == JobStatus.cancelled,
      };

  /// Opens whichever screen actually matches where the job has got to.
  ///
  /// This used to send `accepted` jobs to JobInProgressScreen and
  /// `posted`/`negotiating` ones to TrackWorkerLocationScreen — exactly
  /// backwards. A job with no worker assigned yet went to a tracking map
  /// that could only ever say "Waiting for location…", while a job whose
  /// worker was en route skipped the tracking screen entirely.
  void _openJob(Job j) {
    final screen = screenForJob(j, role: SessionController.instance.user?.role);
    if (screen == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final uid = SessionController.instance.uid;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('My Jobs'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Row(
                  children: _Filter.values.map((s) {
                    final active = s == filter;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => filter = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? AppColors.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            boxShadow: active ? AppShadows.soft : null,
                          ),
                          child: Text(
                            switch (s) { _Filter.active => 'Active', _Filter.completed => 'Completed', _Filter.cancelled => 'Cancelled' },
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelLg.copyWith(color: active ? AppColors.primary : AppColors.onSurfaceVariant),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: uid == null
                    ? const SizedBox.shrink()
                    : StreamBuilder<List<Job>>(
                        stream: JobsService.instance.watchJobsBySeeker(uid),
                        builder: (context, snap) {
                          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                          final jobs = snap.data!.where(_matches).toList();
                          if (jobs.isEmpty) {
                            return Center(child: Text('No jobs here yet', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)));
                          }
                          return ListView.separated(
                            itemCount: jobs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 16),
                            itemBuilder: (context, i) => _JobCard(
                              job: jobs[i],
                              onTap: () => _openJob(jobs[i]),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      // Every tab used to just pop back to Home, so Messages and Profile
      // were unreachable from here. Only the already-selected Jobs tab is a
      // no-op now; the rest actually navigate.
      bottomNavigationBar: AppBottomNav(
        current: AppTab.jobs,
        onTap: (t) {
          switch (t) {
            case AppTab.jobs:
              break;
            case AppTab.home:
              Navigator.of(context).maybePop();
            case AppTab.messages:
              Navigator.of(context).pushNamed(AppRoutes.aiAssistantChat);
            case AppTab.profile:
              Navigator.of(context).pushNamed(AppRoutes.profileSettings);
          }
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const _JobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (job.status) {
      JobStatus.completed => (AppColors.statusGreenBg, AppColors.statusGreenFg, 'Completed'),
      JobStatus.cancelled => (AppColors.errorContainer, AppColors.onErrorContainer, 'Cancelled'),
      _ => (AppColors.statusAmberBg, AppColors.statusAmberFg, 'Active'),
    };
    final cancelled = job.status == JobStatus.cancelled;

    return Opacity(
      opacity: cancelled ? 0.8 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: job.isActive ? AppColors.secondaryContainer : AppColors.surfaceContainerHigh, shape: BoxShape.circle),
                child: Icon(job.categoryIcon, color: job.isActive ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.categoryName, style: AppTextStyles.headlineMd),
                    Text(job.createdAt == null ? '' : '${job.createdAt}'.split(' ').first, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${(job.acceptedPrice ?? job.budget).toStringAsFixed(0)}',
                    style: AppTextStyles.labelLg.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cancelled ? AppColors.onSurfaceVariant : AppColors.onSurface,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text(label, style: AppTextStyles.labelSm.copyWith(color: fg)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
