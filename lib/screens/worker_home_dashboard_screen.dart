import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer.dart';
import '../widgets/notification_bell.dart';
import '../main.dart' show AppRoutes;
import '../models/app_user.dart';
import '../models/job.dart';
import '../services/jobs_service.dart';
import '../services/wallet_service.dart';
import '../services/session_controller.dart';
import '../services/geo_utils.dart';
import 'job_alert_detail_screen.dart';
import 'job_notification_popup_screen.dart';

/// Maps to: worker_home_dashboard/code.html
/// The worker-facing home screen with an online/offline toggle and a
/// real-time incoming job-alerts feed (open jobs within 5km).
class WorkerHomeDashboardScreen extends StatefulWidget {
  const WorkerHomeDashboardScreen({super.key});

  @override
  State<WorkerHomeDashboardScreen> createState() => _WorkerHomeDashboardScreenState();
}

class _WorkerHomeDashboardScreenState extends State<WorkerHomeDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _dismissed = <String>{};
  GeoPoint? _myPosition;
  bool _togglingOnline = false;

  @override
  void initState() {
    super.initState();
    currentDevicePosition().then((pos) {
      if (mounted) setState(() => _myPosition = pos);
    });
  }

  Future<void> _toggleOnline(bool current) async {
    final uid = SessionController.instance.uid;
    if (uid == null || _togglingOnline) return;
    setState(() => _togglingOnline = true);
    try {
      final goingOnline = !current;
      // Take a fresh fix when going online rather than reusing whatever
      // position was read once at initState — a worker who opened the app at
      // home and went online after driving across town would otherwise be
      // pinned at the stale spot on every seeker's "Nearby Workers" map.
      final position = goingOnline ? (await currentDevicePosition() ?? _myPosition) : _myPosition;
      if (mounted && position != null) setState(() => _myPosition = position);
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isOnline': goingOnline,
        if (position != null) 'location': position,
      });
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // SessionController is a ChangeNotifier holding the live users/{uid}
    // doc, but this screen used to read `.user` straight out of build with
    // nothing subscribed to it. _toggleOnline wrote isOnline to Firestore
    // successfully and the screen never repainted, so the GO ONLINE /
    // GO OFFLINE switch and the ONLINE/OFFLINE pill in the app bar both
    // looked completely dead. Listening fixes all three at once.
    return ListenableBuilder(
      listenable: SessionController.instance,
      builder: (context, _) {
        final me = SessionController.instance.user;
        final online = me?.isOnline ?? false;
        final uid = SessionController.instance.uid;
        return _buildScaffold(context, online: online, uid: uid, me: me);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, {required bool online, required String? uid, required AppUser? me}) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(isWorker: true),
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        leading: IconButton(icon: const Icon(Symbols.menu_rounded, color: AppColors.primary), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        title: Text('TaskPoint', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Symbols.account_balance_wallet_rounded, color: AppColors.primary),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.earningsWallet),
          ),
          const NotificationBellButton(iconColor: AppColors.primary),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: online ? AppColors.onlineDot : AppColors.outline, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(online ? 'ONLINE' : 'OFFLINE', style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, AppSpacing.xl),
          children: [
            GestureDetector(
              onTap: _togglingOnline ? null : () => _toggleOnline(online),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                alignment: online ? Alignment.centerLeft : Alignment.centerRight,
                decoration: BoxDecoration(
                  color: online ? AppColors.primaryContainer : AppColors.surfaceDim,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  online ? 'GO OFFLINE' : 'GO ONLINE',
                  style: AppTextStyles.labelLg.copyWith(color: online ? Colors.white : AppColors.onSurfaceVariant, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.soft),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overview', style: AppTextStyles.headlineMd),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.earningsWallet),
                          child: StreamBuilder<double>(
                            stream: uid == null ? const Stream.empty() : WalletService.instance.watchBalance(uid),
                            builder: (context, snap) => _StatTile(
                              icon: Symbols.account_balance_wallet_rounded,
                              label: 'Wallet',
                              value: 'Rs. ${(snap.data ?? 0).toStringAsFixed(0)}',
                              filled: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FutureBuilder<double>(
                          future: uid == null ? Future.value(0) : WalletService.instance.todayEarnings(uid),
                          builder: (context, snap) => _StatTile(
                            icon: Symbols.payments_rounded,
                            label: 'Today',
                            value: 'Rs. ${(snap.data ?? 0).toStringAsFixed(0)}',
                            filled: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surfaceVariant))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Incoming Jobs', style: AppTextStyles.headlineMd),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Live', style: AppTextStyles.labelSm.copyWith(color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            StreamBuilder<List<Job>>(
              // Honours the worker's own "service radius" setting instead of
              // the hard-coded 5km default they had no way to influence.
              stream: JobsService.instance.watchNearbyOpenJobs(
                near: _myPosition,
                radiusKm: me?.serviceRadiusKm ?? 5,
              ),
              builder: (context, snap) {
                if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()));
                final jobs = snap.data!.where((j) => !_dismissed.contains(j.id)).toList();
                if (jobs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No open jobs nearby right now', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant))),
                  );
                }
                return Column(
                  children: [
                    for (final job in jobs) ...[
                      GestureDetector(
                        // Tapping the card body opens the full job detail —
                        // description, seeker, location, and the Counter-Offer
                        // path. JobAlertDetailScreen (and CounterOfferScreen
                        // behind it) had no caller anywhere in the app before
                        // this, so both were unreachable dead screens.
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => JobAlertDetailScreen(jobId: job.id)),
                        ),
                        child: _JobAlertCard(
                          job: job,
                          // The button stays on the fast path: the compact
                          // accept/counter popup.
                          onAccept: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobNotificationPopupScreen(jobId: job.id))),
                          onDecline: () => setState(() => _dismissed.add(job.id)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppTab.home,
        onTap: (t) {
          if (t == AppTab.jobs) {
            Navigator.of(context).pushNamed(AppRoutes.jobHistory);
          } else if (t == AppTab.profile) {
            Navigator.of(context).pushNamed(AppRoutes.workerProfileSettings);
          } else if (t == AppTab.messages) {
            Navigator.of(context).pushNamed(AppRoutes.notificationsInbox);
          }
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool filled;
  const _StatTile({required this.icon, required this.label, required this.value, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: filled ? AppColors.primaryContainer : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: filled ? null : Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: filled ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(label, style: AppTextStyles.labelSm.copyWith(color: filled ? AppColors.onPrimaryContainer.withOpacity(0.9) : AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.headlineLgMobile.copyWith(color: filled ? AppColors.onPrimaryContainer : AppColors.onSurface, fontWeight: filled ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _JobAlertCard extends StatelessWidget {
  final Job job;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _JobAlertCard({required this.job, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.soft),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(job.categoryIcon, size: 14, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(job.categoryName, style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(job.categoryName, style: AppTextStyles.headlineMd),
                  ],
                ),
              ),
              Text('Rs. ${job.budget.toStringAsFixed(0)}', style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(job.description, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                    icon: const Icon(Symbols.check_circle_rounded, size: 20),
                    label: Text('View & Accept', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 48,
                height: 48,
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  child: const Icon(Symbols.close_rounded, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
