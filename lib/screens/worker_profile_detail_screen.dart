import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../models/app_user.dart';
import '../models/job.dart';
import '../models/review.dart';
import '../services/worker_profile_actions_service.dart';
import '../services/reviews_service.dart';
import '../services/jobs_service.dart';
import 'job_in_progress_screen.dart';

/// Maps to: worker_profile_detail/code.html
///
/// [jobId]/[bid] are optional — when present (reached from a specific job's
/// offers inbox), the bottom bar shows that bid's price with an
/// Accept/Reject action. Without them this is a read-only profile view.
class WorkerProfileDetailScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  final String? jobId;
  final Bid? bid;
  const WorkerProfileDetailScreen({super.key, required this.workerId, required this.workerName, this.jobId, this.bid});

  @override
  State<WorkerProfileDetailScreen> createState() => _WorkerProfileDetailScreenState();
}

class _WorkerProfileDetailScreenState extends State<WorkerProfileDetailScreen> {
  final _service = WorkerProfileActionsService();
  late bool _isBlocked = _service.isBlocked(widget.workerId);
  late bool _hasReported = _service.hasReported(widget.workerId);
  bool _accepting = false;

  late final Future<AppUser?> _workerFuture = _service.fetchWorker(widget.workerId);
  late final Future<WorkerRatingSummary> _ratingFuture = ReviewsService.instance.fetchRatingSummary(widget.workerId);
  late final Future<int> _completedJobsFuture = JobsService.instance.countCompletedJobsForWorker(widget.workerId);

  Future<void> _shareProfile() async {
    Navigator.of(context).pop(); // close the "⋮" menu first
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating share link...')));
    try {
      final link = await _service.generateShareLink(widget.workerId);
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Profile link copied: $link')));
    } on WorkerProfileActionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openReportSheet() async {
    Navigator.of(context).pop(); // close the "⋮" menu first
    if (_hasReported) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already reported this worker')));
      return;
    }
    ReportReason selectedReason = ReportReason.inappropriateBehavior;
    final detailsController = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(AppRadius.full)))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, 0),
                  child: Text('Report ${widget.workerName}', style: AppTextStyles.headlineMd),
                ),
                for (final reason in ReportReason.values)
                  RadioListTile<ReportReason>(
                    value: reason,
                    groupValue: selectedReason,
                    activeColor: AppColors.primary,
                    title: Text(reason.label),
                    onChanged: submitting ? null : (v) => setSheetState(() => selectedReason = v!),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
                  child: TextField(
                    controller: detailsController,
                    enabled: !submitting,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Additional details (optional)'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, AppSpacing.lg),
                  child: ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            setSheetState(() => submitting = true);
                            try {
                              await _service.reportWorker(widget.workerId, reason: selectedReason, details: detailsController.text.trim());
                              if (!mounted) return;
                              setState(() => _hasReported = true);
                              Navigator.of(sheetContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted — our team will review it')));
                            } on WorkerProfileActionException catch (e) {
                              setSheetState(() => submitting = false);
                              ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(e.message)));
                            }
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                    child: submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmToggleBlock() async {
    Navigator.of(context).pop(); // close the "⋮" menu first
    final blocking = !_isBlocked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(blocking ? 'Block ${widget.workerName}?' : 'Unblock ${widget.workerName}?'),
        content: Text(
          blocking
              ? 'You will no longer see bids from this worker, and they will not be able to message or be booked by you.'
              : 'You will start seeing bids and messages from this worker again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(blocking ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      if (blocking) {
        await _service.blockWorker(widget.workerId);
      } else {
        await _service.unblockWorker(widget.workerId);
      }
      if (!mounted) return;
      setState(() => _isBlocked = blocking);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocking ? '${widget.workerName} has been blocked' : '${widget.workerName} has been unblocked')),
      );
    } on WorkerProfileActionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _acceptBid() async {
    final jobId = widget.jobId;
    final bid = widget.bid;
    if (jobId == null || bid == null || _accepting) return;
    setState(() => _accepting = true);
    try {
      await JobsService.instance.acceptBid(jobId: jobId, bid: bid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => JobInProgressScreen(jobId: jobId)));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(AppRadius.full))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Symbols.share_rounded, color: AppColors.primary),
              title: const Text('Share Profile'),
              onTap: _shareProfile,
            ),
            ListTile(
              leading: Icon(_hasReported ? Symbols.flag_circle_rounded : Symbols.flag_rounded, color: AppColors.primary),
              title: Text(_hasReported ? 'Already Reported' : 'Report Worker'),
              onTap: _openReportSheet,
            ),
            ListTile(
              leading: Icon(_isBlocked ? Symbols.lock_open_rounded : Symbols.block_rounded, color: AppColors.error),
              title: Text(_isBlocked ? 'Unblock Worker' : 'Block Worker', style: const TextStyle(color: AppColors.error)),
              onTap: _confirmToggleBlock,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAllReviews(BuildContext context, List<Review> reviews) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(AppRadius.full))),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('All Reviews', style: AppTextStyles.headlineMd),
                ),
                Expanded(
                  child: reviews.isEmpty
                      ? Center(child: Text('No reviews yet', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)))
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 0, AppSpacing.marginMobile, AppSpacing.xl),
                          itemCount: reviews.length,
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, i) => _ReviewTile(review: reviews[i]),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'Worker Profile',
        leadingIcon: Symbols.arrow_back_rounded,
        trailing: IconButton(
          icon: const Icon(Symbols.more_vert_rounded),
          onPressed: () => _showOptionsMenu(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            StreamBuilder<List<Review>>(
              stream: ReviewsService.instance.watchForWorker(widget.workerId),
              builder: (context, reviewSnap) {
                final reviews = reviewSnap.data ?? const [];
                return ListView(
                  padding: EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, widget.bid != null ? 140 : AppSpacing.xl),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.surface, width: 4),
                                  color: AppColors.surfaceContainerHighest,
                                  boxShadow: AppShadows.soft,
                                ),
                                child: const Icon(Symbols.person_rounded, size: 64, color: AppColors.onSurfaceVariant),
                              ),
                              FutureBuilder<AppUser?>(
                                future: _workerFuture,
                                builder: (context, snap) {
                                  final verified = snap.data?.cnicStatus == CnicStatus.verified;
                                  if (!verified) return const SizedBox.shrink();
                                  return Positioned(
                                    bottom: -14,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: OverflowBox(
                                        maxWidth: double.infinity,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryContainer,
                                            borderRadius: BorderRadius.circular(AppRadius.full),
                                            border: Border.all(color: AppColors.surface, width: 2),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Symbols.verified_user_rounded, size: 16, color: AppColors.onPrimaryContainer),
                                              const SizedBox(width: 4),
                                              Text('CNIC Verified', style: AppTextStyles.labelSm.copyWith(color: AppColors.onPrimaryContainer, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md + 6),
                          Text(widget.workerName, style: AppTextStyles.headlineLgMobile),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: FutureBuilder<int>(
                            future: _completedJobsFuture,
                            builder: (context, snap) => _StatCard(icon: Symbols.work_history_rounded, iconColor: AppColors.primary, value: '${snap.data ?? '...'}', label: 'Jobs Done'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FutureBuilder<WorkerRatingSummary>(
                            future: _ratingFuture,
                            builder: (context, snap) => _StatCard(
                              icon: Symbols.star_rounded,
                              iconColor: AppColors.tertiary,
                              value: snap.data == null ? '...' : snap.data!.average.toStringAsFixed(1),
                              label: 'Rating (${snap.data?.count ?? 0})',
                              filled: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.bid != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.surfaceContainerLow),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Column(
                          children: [
                            Text('BID PRICE', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('Rs. ', style: AppTextStyles.bodyLg.copyWith(color: AppColors.primary.withOpacity(0.8))),
                                Text(widget.bid!.price.toStringAsFixed(0), style: AppTextStyles.headlineLg.copyWith(color: AppColors.primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Reviews', style: AppTextStyles.labelLg),
                        TextButton(
                          onPressed: () => _showAllReviews(context, reviews),
                          child: Row(
                            children: [
                              Text('See all', style: AppTextStyles.labelSm.copyWith(color: AppColors.primary)),
                              const Icon(Symbols.chevron_right_rounded, size: 16, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (reviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('No reviews yet', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                      )
                    else
                      _ReviewTile(review: reviews.first),
                  ],
                );
              },
            ),
            if (widget.bid != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.95),
                    border: Border(top: BorderSide(color: AppColors.outlineVariant)),
                  ),
                  child: _isBlocked
                      ? Row(
                          children: [
                            const Icon(Symbols.block_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'You have blocked this worker. Unblock them from the "⋮" menu to book them again.',
                                style: AppTextStyles.bodyMd.copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).maybePop(),
                                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                                  child: Text('Back', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurface)),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _accepting ? null : _acceptBid,
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                                  child: Text(_accepting ? 'Accepting...' : 'Accept Offer & Book', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final initials = review.seekerName.isEmpty ? '?' : review.seekerName.trim().split(RegExp(r'\s+')).map((s) => s[0]).take(2).join().toUpperCase();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 20, backgroundColor: AppColors.secondaryContainer, child: Text(initials, style: AppTextStyles.labelLg.copyWith(color: AppColors.onSecondaryContainer))),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.seekerName.isEmpty ? 'Anonymous' : review.seekerName, style: AppTextStyles.labelLg),
                      if (review.createdAt != null)
                        Text('${review.createdAt}'.split(' ').first, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              Row(children: List.generate(5, (i) => Icon(Symbols.star_rounded, size: 16, color: AppColors.starGold, fill: i < review.rating ? 1 : 0))),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(review.comment, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool filled;
  const _StatCard({required this.icon, required this.iconColor, required this.value, required this.label, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: Column(
        children: [
          Icon(icon, color: iconColor, fill: filled ? 1 : 0),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.headlineMd),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
