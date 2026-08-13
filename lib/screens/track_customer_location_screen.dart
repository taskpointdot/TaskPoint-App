import 'dart:async';

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
import '../services/location_sharing_service.dart';
import '../widgets/live_map.dart';
import 'complete_job_photo_capture_screen.dart';
import 'worker_customer_chat_screen.dart';

/// Maps to: track_customer_location/code.html
/// Worker-side "en route to customer" screen — the mirror of
/// track_worker_location_screen (seeker side). Publishes this worker's
/// position continuously to their own `users/{uid}.location` for as long as
/// the screen is open, which is what the seeker's track-worker screen reads
/// to draw them on its map and compute the remaining distance.
class TrackCustomerLocationScreen extends StatefulWidget {
  final String jobId;
  const TrackCustomerLocationScreen({super.key, required this.jobId});

  @override
  State<TrackCustomerLocationScreen> createState() => _TrackCustomerLocationScreenState();
}

class _TrackCustomerLocationScreenState extends State<TrackCustomerLocationScreen> {
  bool _marking = false;

  /// This worker's own live position, used for the "x km away" readout. The
  /// map draws it from the OS blue dot rather than this, so a denied
  /// permission degrades to "no distance shown" instead of a broken map.
  GeoPoint? _myPosition;
  StreamSubscription<GeoPoint>? _positionSub;

  @override
  void initState() {
    super.initState();
    // Publishes to Firestore for the seeker's side of the map.
    LocationSharingService.instance.start();
    // Separate local subscription purely for this screen's own distance
    // readout — reading it back from Firestore would round-trip our own write.
    currentDevicePosition().then((pos) {
      if (mounted && pos != null) setState(() => _myPosition = pos);
    });
    _positionSub = devicePositionStream().listen((pos) {
      if (mounted) setState(() => _myPosition = pos);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    // Stop broadcasting once the worker leaves the en-route screen; the job
    // is either in progress (they've arrived) or they backed out.
    LocationSharingService.instance.stop();
    super.dispose();
  }

  Future<void> _markArrived() async {
    if (_marking) return;
    setState(() => _marking = true);
    try {
      await JobsService.instance.updateStatus(widget.jobId, JobStatus.inProgress);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => CompleteJobPhotoCaptureScreen(jobId: widget.jobId)));
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Job>(
        stream: JobsService.instance.watchJob(widget.jobId),
        builder: (context, jobSnap) {
          final job = jobSnap.data;
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
            future: job == null ? null : FirebaseFirestore.instance.collection('users').doc(job.seekerId).get(),
            builder: (context, seekerSnap) {
              final seeker = (seekerSnap.data?.exists ?? false) ? AppUser.fromDoc(seekerSnap.data!) : null;
              final seekerName = seeker?.name.isNotEmpty == true ? seeker!.name : 'Seeker';
              return Stack(
                children: [
                  Positioned.fill(
                    child: LiveMap(
                      showMyLocation: true,
                      bottomPadding: 220,
                      emptyLabel: 'Locating the job address…',
                      points: [
                        if (job?.location != null)
                          MapPoint(
                            id: 'destination',
                            position: job!.location!,
                            title: seekerName,
                            snippet: job.address ?? 'Job location',
                            hue: BitmapDescriptor.hueRed,
                          ),
                        if (_myPosition != null)
                          MapPoint(
                            id: 'me',
                            position: _myPosition!,
                            title: 'You',
                            snippet: 'En route',
                            hue: BitmapDescriptor.hueAzure,
                          ),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          _RoundIconButton(icon: Symbols.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.full), boxShadow: AppShadows.soft),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Symbols.drive_eta_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  // Counts down live as the worker drives, since
                                  // _myPosition is refreshed off the GPS stream.
                                  (_myPosition != null && job?.location != null)
                                      ? '${distanceKm(_myPosition!, job!.location!).toStringAsFixed(1)} km away'
                                      : 'En Route',
                                  style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        margin: const EdgeInsets.all(AppSpacing.marginMobile),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.active),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(job?.address ?? 'Location shared by seeker', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                            const Divider(height: AppSpacing.lg),
                            Row(
                              children: [
                                CircleAvatar(radius: 22, backgroundColor: AppColors.surfaceVariant, child: Text(seekerName[0], style: AppTextStyles.headlineMd)),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(seekerName, style: AppTextStyles.labelLg),
                                      Text(job?.categoryName ?? '', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                _RoundIconButton(icon: Symbols.call_rounded, onTap: (seeker?.phone.isNotEmpty ?? false) ? () => callPhone(seeker!.phone) : null, filled: true),
                                const SizedBox(width: 8),
                                _RoundIconButton(
                                  icon: Symbols.chat_rounded,
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerCustomerChatScreen(jobId: widget.jobId, contactName: seekerName, contactPhone: seeker?.phone))),
                                  filled: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _marking ? null : _markArrived,
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                                child: Text(_marking ? 'Updating...' : 'Mark Arrived', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                              ),
                            ),
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
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  const _RoundIconButton({required this.icon, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primaryContainer.withOpacity(0.12) : Colors.white,
      shape: const CircleBorder(),
      elevation: filled ? 0 : 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }
}
