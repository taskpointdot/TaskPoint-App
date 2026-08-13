import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../models/job.dart';
import '../models/app_user.dart';
import '../models/review.dart';
import '../services/jobs_service.dart';
import '../services/reviews_service.dart';
import 'worker_home_dashboard_screen.dart';
import 'report_a_problem_screen.dart';

/// Maps to: job_completion_receipt/code.html
class JobCompletionReceiptScreen extends StatelessWidget {
  final String jobId;
  const JobCompletionReceiptScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Receipt'),
      body: SafeArea(
        child: StreamBuilder<Job>(
          stream: JobsService.instance.watchJob(jobId),
          builder: (context, jobSnap) {
            final job = jobSnap.data;
            if (job == null) return const Center(child: CircularProgressIndicator());
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('users').doc(job.seekerId).get(),
              builder: (context, seekerSnap) {
                final seeker = (seekerSnap.data?.exists ?? false) ? AppUser.fromDoc(seekerSnap.data!) : null;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.soft),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.only(bottom: 16),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surfaceVariant))),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle),
                                  child: const Icon(Symbols.check_circle_rounded, color: AppColors.onSecondaryContainer, size: 36, fill: 1),
                                ),
                                const SizedBox(height: 12),
                                Text('Job Completed', style: AppTextStyles.headlineLgMobile),
                                const SizedBox(height: 4),
                                Text('ID: ${job.id}', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                                if (job.completedAt != null)
                                  Text('${job.completedAt}'.split('.').first, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('CUSTOMER DETAILS', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1)),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.surfaceVariant.withOpacity(0.5))),
                            child: Row(
                              children: [
                                const CircleAvatar(radius: 24, backgroundColor: AppColors.surfaceContainerHighest, child: Icon(Symbols.person_rounded, color: AppColors.onSurfaceVariant)),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(seeker?.name.isNotEmpty == true ? seeker!.name : 'Seeker', style: AppTextStyles.headlineMd),
                                    Row(
                                      children: [
                                        const Icon(Symbols.call_rounded, size: 16, color: AppColors.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Text(seeker?.phone ?? '', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (job.address != null) ...[
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('LOCATION', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppRadius.lg)),
                              child: Row(
                                children: [
                                  const Icon(Symbols.location_on_rounded, size: 18, color: AppColors.primary, fill: 1),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(job.address!, style: AppTextStyles.bodyMd)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('REVIEW', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1)),
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<Review?>(
                            stream: ReviewsService.instance.watchForJob(jobId),
                            builder: (context, reviewSnap) {
                              final review = reviewSnap.data;
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3))),
                                child: review == null
                                    ? Text('Awaiting the seeker\'s review', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic))
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: List.generate(5, (i) => Icon(Symbols.star_rounded, size: 20, color: AppColors.starGold, fill: i < review.rating ? 1 : 0))),
                                          if (review.comment.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text('"${review.comment}"', style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic)),
                                          ],
                                        ],
                                      ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.only(top: 16),
                            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.surfaceVariant))),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Total Earnings', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                                Text('Rs. ${(job.acceptedPrice ?? job.budget).toStringAsFixed(0)}', style: AppTextStyles.headlineLgMobile.copyWith(color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportAProblemScreen())),
                        icon: const Icon(Symbols.flag_rounded, size: 18, color: AppColors.onSurfaceVariant),
                        label: Text('Report a Problem', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withOpacity(0.95), border: Border(top: BorderSide(color: AppColors.surfaceVariant))),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WorkerHomeDashboardScreen()), (route) => false),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
              child: const Text('Back to Dashboard'),
            ),
          ),
        ),
      ),
    );
  }
}
