import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/notification_bell.dart';
import '../models/job.dart';
import '../models/app_user.dart';
import '../services/jobs_service.dart';
import '../services/session_controller.dart';
import 'counter_offer_screen.dart';
import 'track_customer_location_screen.dart';

/// Maps to: job_alert_detail/code.html — a worker viewing an open job
/// posted by a seeker, with the option to accept it outright or negotiate.
class JobAlertDetailScreen extends StatefulWidget {
  final String jobId;
  const JobAlertDetailScreen({super.key, required this.jobId});

  @override
  State<JobAlertDetailScreen> createState() => _JobAlertDetailScreenState();
}

class _JobAlertDetailScreenState extends State<JobAlertDetailScreen> {
  bool _accepting = false;

  /// "Accept" with no negotiation: the worker's bid at the asking price is
  /// placed and immediately accepted in one step, since there's nothing to
  /// choose between when a single worker takes the job as posted.
  Future<void> _acceptAsking(Job job) async {
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
      appBar: AppTopBar(title: 'TaskPoint', trailing: const NotificationBellButton()),
      body: SafeArea(
        child: StreamBuilder<Job>(
          stream: JobsService.instance.watchJob(widget.jobId),
          builder: (context, snap) {
            final job = snap.data;
            if (job == null) return const Center(child: CircularProgressIndicator());
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('users').doc(job.seekerId).get(),
              builder: (context, seekerSnap) {
                final seeker = (seekerSnap.data?.exists ?? false) ? AppUser.fromDoc(seekerSnap.data!) : null;
                return Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            boxShadow: AppShadows.soft,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _Chip(label: job.categoryName),
                                            const SizedBox(width: 8),
                                            Icon(Symbols.schedule_rounded, size: 16, color: AppColors.onSurfaceVariant),
                                            const SizedBox(width: 2),
                                            Text(_timeAgo(job.createdAt), style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(job.description, style: AppTextStyles.headlineMd),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Rs. ${job.budget.toStringAsFixed(0)}', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary)),
                                      Text('Budget', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              Text('Description', style: AppTextStyles.labelLg),
                              const SizedBox(height: 8),
                              Text(job.description, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant, height: 1.5)),
                              const SizedBox(height: 16),
                              Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                                ),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(AppRadius.dflt),
                                      boxShadow: AppShadows.soft,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Symbols.location_on_rounded, color: AppColors.primary, fill: 1),
                                        Text(job.address ?? 'Location shared on accept', style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2))),
                                child: Row(
                                  children: [
                                    const CircleAvatar(radius: 24, backgroundColor: AppColors.surfaceContainerHighest, child: Icon(Symbols.person_rounded, color: AppColors.onSurfaceVariant)),
                                    const SizedBox(width: 12),
                                    Text(seeker?.name.isNotEmpty == true ? seeker!.name : 'Seeker', style: AppTextStyles.labelLg),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest.withOpacity(0.95),
                          border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.2))),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _accepting
                                    ? null
                                    : () => Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => CounterOfferScreen(jobId: widget.jobId, jobTitle: job.categoryName, currentPrice: job.budget)),
                                        ),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                                child: Text('Counter-Offer', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _accepting ? null : () => _acceptAsking(job),
                                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                                child: Text(_accepting ? 'Accepting...' : 'Accept Rs. ${job.budget.toStringAsFixed(0)}', style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
                              ),
                            ),
                          ],
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

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final mins = DateTime.now().difference(dt).inMinutes;
    if (mins < 1) return 'Just now';
    if (mins < 60) return '$mins min ago';
    return '${(mins / 60).floor()} hr ago';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSecondaryContainer)),
    );
  }
}
