import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../models/app_user.dart';
import '../services/job_navigation.dart';
import '../services/jobs_service.dart';
import '../services/session_controller.dart';

/// Maps to: job_history_list/code.html
/// The worker's own jobs (accepted, in progress, completed, cancelled) —
/// also reachable as the worker-side "My Jobs" equivalent from the drawer
/// and bottom nav.
class JobHistoryListScreen extends StatefulWidget {
  const JobHistoryListScreen({super.key});

  @override
  State<JobHistoryListScreen> createState() => _JobHistoryListScreenState();
}

class _JobHistoryListScreenState extends State<JobHistoryListScreen> {
  int _filter = 0; // 0: This Week, 1: This Month, 2: All Time
  static const _labels = ['This Week', 'This Month', 'All Time'];

  bool _withinFilter(DateTime? createdAt) {
    if (createdAt == null) return true;
    final now = DateTime.now();
    return switch (_filter) {
      0 => now.difference(createdAt).inDays <= 7,
      1 => now.difference(createdAt).inDays <= 30,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final uid = SessionController.instance.uid;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('Job History'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.sm, AppSpacing.marginMobile, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _labels.length; i++) ...[
                    Expanded(
                      child: ChoiceChip(
                        label: Text(_labels[i]),
                        selected: _filter == i,
                        onSelected: (_) => setState(() => _filter = i),
                        selectedColor: AppColors.primaryContainer,
                        labelStyle: AppTextStyles.labelSm.copyWith(color: _filter == i ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant),
                      ),
                    ),
                    if (i != _labels.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: uid == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<Job>>(
                      stream: JobsService.instance.watchJobsByWorker(uid),
                      builder: (context, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        final jobs = snap.data!.where((j) => _withinFilter(j.createdAt)).toList();
                        if (jobs.isEmpty) {
                          return Center(child: Text('No jobs here yet', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)));
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.marginMobile),
                          itemCount: jobs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) => _HistoryCard(
                            job: jobs[i],
                            // The rows were plain Containers with no gesture
                            // handling, so a worker could see their job list
                            // but never open anything from it.
                            onTap: () {
                              final screen = screenForJob(jobs[i], role: SessionController.instance.user?.role);
                              if (screen == null) return;
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const _HistoryCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final completed = job.status == JobStatus.completed;
    final cancelled = job.status == JobStatus.cancelled;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(job.categoryIcon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(job.categoryName, style: AppTextStyles.labelLg),
                    const SizedBox(width: 6),
                    if (job.createdAt != null) Text('${job.createdAt}'.split(' ').first, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(completed ? Symbols.check_circle_rounded : (cancelled ? Symbols.cancel_rounded : Symbols.schedule_rounded),
                        size: 14, color: completed ? AppColors.statusGreenFg : (cancelled ? AppColors.error : AppColors.statusAmberFg)),
                    const SizedBox(width: 4),
                    Text(completed ? 'Completed' : (cancelled ? 'Cancelled' : 'In Progress'),
                        style: AppTextStyles.labelSm.copyWith(color: completed ? AppColors.statusGreenFg : (cancelled ? AppColors.error : AppColors.statusAmberFg))),
                  ],
                ),
                const SizedBox(height: 2),
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('users').doc(job.seekerId).get(),
                  builder: (context, snap) {
                    final seeker = (snap.data?.exists ?? false) ? AppUser.fromDoc(snap.data!) : null;
                    return Text(seeker?.name.isNotEmpty == true ? seeker!.name : 'Seeker', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant));
                  },
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(completed ? 'Final Earnings' : 'Estimated', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
              Text('Rs. ${(job.acceptedPrice ?? job.budget).toStringAsFixed(0)}', style: AppTextStyles.labelLg.copyWith(color: completed ? AppColors.primary : AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
