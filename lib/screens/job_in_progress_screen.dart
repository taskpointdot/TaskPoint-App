import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../models/job.dart';
import '../models/app_user.dart';
import '../services/jobs_service.dart';
import '../services/dialer.dart';
import 'job_completed_review_screen.dart';
import 'emergency_sos_countdown_screen.dart';

/// Maps to: job_in_progress_sos_safety/code.html — seeker's view of the
/// job they accepted a worker for.
class JobInProgressScreen extends StatelessWidget {
  final String jobId;
  const JobInProgressScreen({super.key, required this.jobId});

  String _startedLabel(DateTime? createdAt) {
    if (createdAt == null) return '';
    final mins = DateTime.now().difference(createdAt).inMinutes;
    if (mins < 1) return 'Started just now';
    if (mins < 60) return 'Started $mins mins ago';
    return 'Started ${(mins / 60).floor()} hrs ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Job Status'),
      body: SafeArea(
        child: StreamBuilder<Job>(
          stream: JobsService.instance.watchJob(jobId),
          builder: (context, snap) {
            final job = snap.data;
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              future: job?.acceptedWorkerId == null
                  ? null
                  : FirebaseFirestore.instance.collection('users').doc(job!.acceptedWorkerId).get(),
              builder: (context, workerSnap) {
                final worker = workerSnap.data != null && workerSnap.data!.exists ? AppUser.fromDoc(workerSnap.data!) : null;
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.onlineDot, shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Text('Kaam Jaari Hai / Job In Progress', style: AppTextStyles.labelLg),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(_startedLabel(job?.createdAt), style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant.withOpacity(0.8))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    const CircleAvatar(radius: 40, backgroundColor: AppColors.surfaceContainer, child: Icon(Symbols.person_rounded, size: 40, color: AppColors.onSurfaceVariant)),
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: Container(width: 14, height: 14, decoration: BoxDecoration(color: AppColors.onlineDot, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(job?.acceptedWorkerName ?? '...', style: AppTextStyles.headlineLgMobile),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Symbols.call_rounded, size: 16, color: AppColors.onSurfaceVariant),
                                    const SizedBox(width: 6),
                                    Text(worker?.phone ?? '', style: AppTextStyles.bodyMd),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.dflt), border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3))),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Agreed Rate', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                                      Text('Rs. ${(job?.acceptedPrice ?? 0).toStringAsFixed(0)}', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: (worker?.phone.isNotEmpty ?? false) ? () => callPhone(worker!.phone) : null,
                                    icon: const Icon(Symbols.call_rounded, fill: 1),
                                    label: const Text('Call'),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    onPressed: job?.status != JobStatus.completed
                                        ? null
                                        : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobCompletedReviewScreen(jobId: jobId))),
                                    icon: const Icon(Symbols.star_rounded, fill: 1),
                                    label: const Text('Provide Review'),
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Center(
                            child: Column(
                              children: [
                                Icon(Symbols.shield_person_rounded, size: 32, color: AppColors.outline.withOpacity(0.6)),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 250,
                                  child: Text(
                                    'TaskPoint secures all active jobs. Your safety is our priority.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.labelSm.copyWith(color: AppColors.outline.withOpacity(0.6)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // SOS panel
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EmergencySosCountdownScreen()),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: AppColors.error,
                        child: SafeArea(
                          top: false,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Symbols.warning_rounded, color: Colors.white, size: 28, fill: 1),
                                  const SizedBox(width: 8),
                                  Text('SOS EMERGENCY ALERT', style: AppTextStyles.headlineLgMobile.copyWith(color: Colors.white, fontSize: 18)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Slide or Tap to trigger immediate assistance', style: AppTextStyles.labelSm.copyWith(color: Colors.white.withOpacity(0.8))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
