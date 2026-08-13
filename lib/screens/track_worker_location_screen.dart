import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show BitmapDescriptor;
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../models/job.dart';
import '../models/app_user.dart';
import '../services/jobs_service.dart';
import '../services/geo_utils.dart';
import '../services/dialer.dart';
import '../services/reviews_service.dart';
import '../widgets/live_map.dart';

/// Maps to: track_worker_location/code.html
///
/// Shows a live Google Map of the accepted worker moving toward the job
/// address, plus their name/phone/distance underneath. Both pins are
/// streamed: the worker's from their `users/{uid}.location` (which their own
/// app republishes every ~10m via LocationSharingService — see
/// `track_customer_location_screen.dart`), the destination from the job doc.
class TrackWorkerLocationScreen extends StatelessWidget {
  final String jobId;
  const TrackWorkerLocationScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Job>(
        stream: JobsService.instance.watchJob(jobId),
        builder: (context, jobSnap) {
          final mapJob = jobSnap.data;
          final mapWorkerId = mapJob?.acceptedWorkerId;
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: mapWorkerId == null
                ? const Stream.empty()
                : FirebaseFirestore.instance.collection('users').doc(mapWorkerId).snapshots(),
            builder: (context, mapWorkerSnap) {
              final mapWorker = (mapWorkerSnap.data?.exists ?? false) ? AppUser.fromDoc(mapWorkerSnap.data!) : null;
              return _buildBody(
                context,
                workerPosition: mapWorker?.location,
                workerName: mapJob?.acceptedWorkerName ?? 'Worker',
                jobPosition: mapJob?.location,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required GeoPoint? workerPosition,
    required String workerName,
    required GeoPoint? jobPosition,
  }) {
    return Stack(
        children: [
          Positioned.fill(
            child: LiveMap(
              bottomPadding: 260,
              emptyLabel: 'Waiting for worker location…',
              points: [
                if (workerPosition != null)
                  MapPoint(
                    id: 'worker',
                    position: workerPosition,
                    title: workerName,
                    snippet: 'On the way to you',
                    hue: BitmapDescriptor.hueAzure,
                  ),
                if (jobPosition != null)
                  MapPoint(
                    id: 'destination',
                    position: jobPosition,
                    title: 'Your location',
                    snippet: 'Where the job is',
                    hue: BitmapDescriptor.hueRed,
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                height: 56,
                decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.85), borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
                    Expanded(child: Text('Track Service', textAlign: TextAlign.center, style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary))),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: StreamBuilder<Job>(
              stream: JobsService.instance.watchJob(jobId),
              builder: (context, jobSnap) {
                final job = jobSnap.data;
                final workerId = job?.acceptedWorkerId;
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: workerId == null
                      ? const Stream.empty()
                      : FirebaseFirestore.instance.collection('users').doc(workerId).snapshots(),
                  builder: (context, workerSnap) {
                    final worker = (workerSnap.data?.exists ?? false) ? AppUser.fromDoc(workerSnap.data!) : null;
                    final distance = (job?.location != null && worker?.location != null) ? distanceKm(job!.location!, worker!.location!) : null;
                    return Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: AppShadows.soft,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 48, height: 6, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(3))),
                          const SizedBox(height: 16),
                          Text('STATUS', style: AppTextStyles.labelSm.copyWith(color: AppColors.primary, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(
                            distance == null ? 'Waiting for location...' : '${distance.toStringAsFixed(1)} km away',
                            style: AppTextStyles.headlineLgMobile,
                          ),
                          const SizedBox(height: 8),
                          Text('${job?.acceptedWorkerName ?? 'Your worker'} is on the way to your location.', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.surfaceVariant), boxShadow: AppShadows.soft),
                            child: Row(
                              children: [
                                const CircleAvatar(radius: 28, backgroundColor: AppColors.surfaceContainerHighest, child: Icon(Symbols.person_rounded, color: AppColors.onSurfaceVariant)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(job?.acceptedWorkerName ?? '...', style: AppTextStyles.labelLg),
                                      if (workerId != null)
                                        FutureBuilder(
                                          future: ReviewsService.instance.fetchRatingSummary(workerId),
                                          builder: (context, snap) => Row(
                                            children: [
                                              const Icon(Symbols.star_rounded, size: 16, color: AppColors.starGold, fill: 1),
                                              const SizedBox(width: 4),
                                              Text(
                                                snap.data == null ? '...' : '${snap.data!.average.toStringAsFixed(1)} (${snap.data!.count} jobs)',
                                                style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (worker?.cnicStatus == CnicStatus.verified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(AppRadius.full)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Symbols.verified_rounded, size: 14, color: AppColors.onSecondaryContainer, fill: 1),
                                        const SizedBox(width: 4),
                                        Text('Pro', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSecondaryContainer)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: (worker?.phone.isNotEmpty ?? false) ? () => callPhone(worker!.phone) : null,
                              icon: const Icon(Symbols.call_rounded),
                              label: const Text('Call Worker'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
    );
  }
}
