import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer.dart';
import '../widgets/live_map.dart';
import '../widgets/notification_bell.dart';
import '../widgets/post_job_sheet.dart';
import '../models/app_user.dart';
import '../models/ui_models.dart';
import '../services/categories_service.dart';
import '../services/jobs_service.dart';
import '../services/session_controller.dart';
import '../services/workers_service.dart';
import '../services/geo_utils.dart';
import '../main.dart' show AppRoutes;
import 'my_jobs_tracking_screen.dart';
import 'profile_settings_screen.dart';
import 'all_services_screen.dart';
import 'request_success_screen.dart';

/// Maps to: home_dashboard_discovery/code.html
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  AppTab tab = AppTab.home;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  String _query = '';
  bool _posting = false;

  /// Seeker's own position, driving both the "Nearby Workers" map centre and
  /// the radius query behind it. Null until the first GPS fix lands (or
  /// permanently, if the user denies the permission — the map then just
  /// shows every online worker rather than nothing).
  GeoPoint? _myPosition;
  bool _locating = false;

  /// Mirrors the seeker's saved `serviceRadiusKm` so the "Radius" chip on the
  /// map and the query it labels can't drift apart.
  double get _radiusKm => SessionController.instance.user?.serviceRadiusKm ?? 5;

  @override
  void initState() {
    super.initState();
    _refreshMyLocation();
  }

  Future<void> _refreshMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final pos = await currentDevicePosition();
      if (!mounted) return;
      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on location to see workers near you')),
        );
        return;
      }
      setState(() => _myPosition = pos);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Categories to show in the grid: every category matching the current
  /// search text (by English or local/Roman-Urdu name), or — when the
  /// search box is empty — just the first few, with the rest reachable via
  /// "See All".
  List<ServiceCategory> _visibleCategories(List<ServiceCategory> all) {
    if (_query.trim().isEmpty) {
      return all.take(homeDashboardCategoryPreviewCount).toList();
    }
    final q = _query.trim().toLowerCase();
    return all.where((c) => c.name.toLowerCase().contains(q) || c.localName.toLowerCase().contains(q)).toList();
  }

  /// Tapping a category collects a budget and description, then posts the
  /// job and shows the "broadcasting" confirmation.
  Future<void> _quickPost(ServiceCategory category) async {
    if (_posting) return;
    final details = await showPostJobSheet(context, categoryName: category.name, categoryIcon: category.icon);
    if (details == null || !mounted) return;
    setState(() => _posting = true);
    try {
      final uid = SessionController.instance.uid;
      if (uid == null) return;
      // Reuse the fix the map already has rather than making the seeker wait
      // on a second GPS lock just to post.
      final position = _myPosition ?? await currentDevicePosition();
      final jobId = await JobsService.instance.postJob(
        seekerId: uid,
        categoryId: category.id.isEmpty ? null : category.id,
        categoryName: category.name,
        description: details.description,
        budget: details.budget,
        location: position,
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestSuccessScreen(jobId: jobId)));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _onTabTap(AppTab t) async {
    if (t == AppTab.home) return;
    if (t == AppTab.jobs) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyJobsTrackingScreen()));
    } else if (t == AppTab.profile) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()));
    } else if (t == AppTab.messages) {
      await Navigator.of(context).pushNamed(AppRoutes.aiAssistantChat);
    }
    // These tabs open a separate screen on top of Home rather than swapping
    // content in place, so once the user comes back here they're looking at
    // Home again — keep the bottom nav highlight in sync with that instead
    // of leaving it stuck on whichever tab they tapped to leave.
    if (!mounted) return;
    setState(() => tab = AppTab.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(isWorker: false),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            IconButton(icon: const Icon(Symbols.menu_rounded), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
            const SizedBox(width: 4),
            Text('TaskPoint', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          const NotificationBellButton(),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSettingsScreen())),
            child: const CircleAvatar(radius: 16, backgroundColor: AppColors.surfaceContainerHigh, child: Icon(Symbols.person_rounded, size: 18, color: AppColors.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Kaam dhoondain... (Search for work)',
                prefixIcon: const Icon(Symbols.search_rounded, color: AppColors.outline),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Symbols.close_rounded, color: AppColors.outline),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _query = '';
                        }),
                      ),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            // Categories header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Services', style: AppTextStyles.headlineMd),
                    const SizedBox(height: 4),
                    Text('What do you need help with?', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                if (_query.isEmpty)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllServicesScreen())),
                    child: Text('See All', style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<ServiceCategory>>(
              stream: CategoriesService.instance.watchAll(),
              builder: (context, snapshot) {
                final all = snapshot.data ?? const [];
                if (!snapshot.hasData) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()));
                }
                final visible = _visibleCategories(all);
                if (visible.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No services match "$_query"', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visible.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, i) {
                    final c = visible[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      onTap: _posting ? null : () => _quickPost(c),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle),
                              child: Icon(c.icon, color: AppColors.onSecondaryContainer, size: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(c.name, style: AppTextStyles.labelLg),
                            Text(c.localName, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant.withOpacity(0.7))),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            Text('Nearby Workers', style: AppTextStyles.headlineMd),
            const SizedBox(height: 16),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.soft,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Real map of online workers within the seeker's radius.
                  // The three hard-coded decorative pins that used to sit
                  // here were fixed pixel offsets, unrelated to any actual
                  // worker; these come from users/{uid}.location.
                  Positioned.fill(
                    child: StreamBuilder<List<AppUser>>(
                      stream: WorkersService.instance.watchNearbyOnlineWorkers(
                        near: _myPosition,
                        radiusKm: _radiusKm,
                      ),
                      builder: (context, snap) {
                        final workers = snap.data ?? const <AppUser>[];
                        return LiveMap(
                          showMyLocation: true,
                          singlePointZoom: 13,
                          emptyLabel: _myPosition == null
                              ? 'Finding your location…'
                              : 'No workers online nearby',
                          points: [
                            for (final w in workers)
                              if (w.location != null)
                                MapPoint(
                                  id: w.uid,
                                  position: w.location!,
                                  title: w.name.isEmpty ? 'Worker' : w.name,
                                  snippet: w.skills.isEmpty ? 'Available now' : w.skills.take(3).join(', '),
                                ),
                          ],
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Radius', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text('${_radiusKm.toStringAsFixed(0)} km', style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'locate',
                      backgroundColor: AppColors.primary,
                      // Was `onPressed: () {}` — now actually re-reads GPS,
                      // which re-centres the map and re-runs the nearby query.
                      onPressed: _locating ? null : _refreshMyLocation,
                      child: _locating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Symbols.my_location_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Straight into live voice search — the FAB is a microphone, so it
      // should start listening rather than open another screen that has its
      // own mic button to press.
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'voicePosting',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.voiceSearch),
        icon: const Icon(Symbols.mic_rounded, color: Colors.white),
        label: const Text('Speak'),
      ),
      bottomNavigationBar: AppBottomNav(current: tab, onTap: _onTabTap),
    );
  }
}

