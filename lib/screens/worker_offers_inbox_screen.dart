import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../services/jobs_service.dart';
import '../widgets/notification_bell.dart';
import 'track_worker_location_screen.dart';
import 'worker_profile_detail_screen.dart';

enum _SortOption { category, rating, alphabetic }

/// Maps to: worker_offers_inbox/code.html
/// Real-time bids for [jobId], streamed from `jobs/{jobId}/bids`.
class WorkerOffersInboxScreen extends StatefulWidget {
  final String jobId;
  const WorkerOffersInboxScreen({super.key, required this.jobId});

  @override
  State<WorkerOffersInboxScreen> createState() => _WorkerOffersInboxScreenState();
}

class _WorkerOffersInboxScreenState extends State<WorkerOffersInboxScreen> {
  _SortOption? _activeSort;
  bool _accepting = false;

  static const _sortLabels = {
    _SortOption.category: 'Category',
    _SortOption.rating: 'Rating',
    _SortOption.alphabetic: 'Alphabetic',
  };

  List<Bid> _sorted(List<Bid> bids) {
    final list = List.of(bids);
    switch (_activeSort) {
      case _SortOption.category:
        list.sort((a, b) => a.workerName.compareTo(b.workerName));
      case _SortOption.rating:
        list.sort((a, b) => b.workerRating.compareTo(a.workerRating));
      case _SortOption.alphabetic:
        list.sort((a, b) => a.workerName.compareTo(b.workerName));
      case null:
        break;
    }
    return list;
  }

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<_SortOption>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Sort Workers By', style: AppTextStyles.headlineMd),
            const SizedBox(height: 8),
            for (final option in _SortOption.values)
              ListTile(
                leading: Icon(
                  option == _SortOption.category
                      ? Symbols.category_rounded
                      : option == _SortOption.rating
                          ? Symbols.star_rounded
                          : Symbols.sort_by_alpha_rounded,
                  color: AppColors.primary,
                ),
                title: Text(_sortLabels[option]!),
                trailing: _activeSort == option ? const Icon(Symbols.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _activeSort = selected);
  }

  Future<void> _accept(Bid bid) async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await JobsService.instance.acceptBid(jobId: widget.jobId, bid: bid);
      if (!mounted) return;
      // acceptBid sets the job to 'accepted', not 'in_progress' — the worker
      // still has to travel there. Landing on JobInProgressScreen claimed the
      // job was already underway and skipped the live tracking map entirely;
      // the worker only flips it to in_progress when they tap Mark Arrived.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TrackWorkerLocationScreen(jobId: widget.jobId)),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('Worker Offers'),
        actions: const [NotificationBellButton()],
      ),
      body: SafeArea(
        child: StreamBuilder<Job>(
          stream: JobsService.instance.watchJob(widget.jobId),
          builder: (context, jobSnap) {
            final job = jobSnap.data;
            return StreamBuilder<List<Bid>>(
              stream: JobsService.instance.watchBids(widget.jobId),
              builder: (context, bidSnap) {
                if (!bidSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final bids = _sorted(bidSnap.data!);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${bids.length} bid${bids.length == 1 ? '' : 's'} for',
                                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                            Text(job?.categoryName ?? '...', style: AppTextStyles.labelLg),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _openSortSheet,
                          icon: const Icon(Symbols.filter_list_rounded, size: 16, color: AppColors.primary),
                          label: Text(_activeSort == null ? 'Sort' : 'Sort: ${_sortLabels[_activeSort]}',
                              style: AppTextStyles.labelSm.copyWith(color: AppColors.primary)),
                          style: TextButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainerLow,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (bids.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('No bids yet — nearby workers will show up here.',
                              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                        ),
                      )
                    else
                      ...bids.map((bid) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _BidCard(
                              bid: bid,
                              accepting: _accepting,
                              onAccept: () => _accept(bid),
                              onViewProfile: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => WorkerProfileDetailScreen(workerId: bid.workerId, workerName: bid.workerName, jobId: widget.jobId, bid: bid)),
                              ),
                            ),
                          )),
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

class _BidCard extends StatelessWidget {
  final Bid bid;
  final bool accepting;
  final VoidCallback onAccept;
  final VoidCallback onViewProfile;
  const _BidCard({required this.bid, required this.accepting, required this.onAccept, required this.onViewProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  const CircleAvatar(radius: 28, backgroundColor: AppColors.surfaceContainerHighest, child: Icon(Symbols.person_rounded, color: AppColors.onSurfaceVariant)),
                  if (bid.workerOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(width: 14, height: 14, decoration: BoxDecoration(color: AppColors.onlineDot, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(bid.workerName, style: AppTextStyles.labelLg, overflow: TextOverflow.ellipsis)),
                        Text('Rs. ${bid.price.toStringAsFixed(0)}', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Symbols.star_rounded, size: 14, color: AppColors.starGold, fill: 1),
                        const SizedBox(width: 4),
                        Text('${bid.workerRating.toStringAsFixed(1)} (${bid.workerRatingCount} reviews)', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                    if (bid.message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(bid.message, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (bid.workerCnicVerified) _Badge(icon: Symbols.verified_user_rounded, label: 'CNIC Verified', color: AppColors.primary),
                        _Badge(icon: null, label: bid.status.name, color: AppColors.onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onViewProfile, child: const Text('View Profile')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: (bid.status == BidStatus.accepted || accepting) ? null : onAccept,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  child: Text(bid.status == BidStatus.accepted ? 'Accepted' : 'Accept Bid', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.surfaceContainerHigh)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: AppTextStyles.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}
