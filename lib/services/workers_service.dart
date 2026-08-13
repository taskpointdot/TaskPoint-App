import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import 'geo_utils.dart';

/// Reads of the `users` collection from the seeker's point of view — i.e.
/// "which workers could take my job right now".
///
/// Split out from [SessionController] (which owns the *current* user's doc)
/// because this queries across other people's docs. Follows the same
/// pull-then-filter-client-side approach as
/// `JobsService.watchNearbyOpenJobs`: Firestore has no native radius query,
/// and at this app's data volume a bounded query plus Haversine is simpler
/// and cheaper than adding geo-indexing.
class WorkersService {
  WorkersService._();
  static final WorkersService instance = WorkersService._();

  final _db = FirebaseFirestore.instance;

  /// Providers who can do [categoryName], for the voice-search results
  /// screen.
  ///
  /// A worker's `skills` array is free text they typed themselves, so this
  /// matches loosely (case-insensitive substring, either direction) rather
  /// than demanding a string exactly equal to the category name — someone
  /// who wrote "AC repairing" should still surface for "AC Repair".
  ///
  /// [WorkerSearchResult.isFallback] tells the caller nothing matched the
  /// skill and it's showing all nearby providers instead, so the UI can say
  /// so honestly rather than implying these people do the requested job.
  Stream<WorkerSearchResult> watchWorkersForCategory({
    required String categoryName,
    GeoPoint? near,
    double radiusKm = 15,
    int limit = 100,
  }) {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .limit(limit)
        .snapshots()
        .map((snap) {
      var workers = snap.docs
          .map(AppUser.fromDoc)
          .where((w) => w.profileVisible && !w.suspended)
          .toList();

      if (near != null) {
        workers = workers
            .where((w) => w.location == null || distanceKm(near, w.location!) <= radiusKm)
            .toList();
      }

      final needle = categoryName.toLowerCase().trim();
      final matched = workers.where((w) => _hasSkill(w, needle)).toList();

      final isFallback = matched.isEmpty;
      final results = isFallback ? workers : matched;
      _rank(results, near);
      return WorkerSearchResult(workers: results, isFallback: isFallback);
    });
  }

  bool _hasSkill(AppUser worker, String needle) {
    for (final skill in worker.skills) {
      final s = skill.toLowerCase().trim();
      if (s.isEmpty) continue;
      if (s.contains(needle) || needle.contains(s)) return true;
    }
    return false;
  }

  /// Online first (they can start now), then nearest.
  void _rank(List<AppUser> workers, GeoPoint? near) {
    workers.sort((a, b) {
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      if (near == null) return 0;
      final da = a.location == null ? double.infinity : distanceKm(near, a.location!);
      final db = b.location == null ? double.infinity : distanceKm(near, b.location!);
      return da.compareTo(db);
    });
  }

  /// Workers currently marked online, nearest first, limited to those within
  /// [radiusKm] of [near]. Respects the `profileVisible` privacy toggle —
  /// a worker who turned themselves invisible on Privacy & Security is left
  /// out of the seeker's map entirely.
  ///
  /// When [near] is null (GPS denied or still resolving) the radius filter is
  /// skipped rather than returning nothing, matching how the worker-side
  /// nearby-jobs feed degrades.
  Stream<List<AppUser>> watchNearbyOnlineWorkers({
    GeoPoint? near,
    double radiusKm = 5,
    int limit = 50,
  }) {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('isOnline', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final workers = snap.docs
          .map(AppUser.fromDoc)
          .where((w) => w.profileVisible && w.location != null)
          .toList();
      if (near == null) return workers;
      final withinRadius = workers.where((w) => distanceKm(near, w.location!) <= radiusKm).toList()
        ..sort((a, b) => distanceKm(near, a.location!).compareTo(distanceKm(near, b.location!)));
      return withinRadius;
    });
  }
}

/// Outcome of a voice/category provider search.
class WorkerSearchResult {
  final List<AppUser> workers;

  /// True when no provider listed the requested skill, so [workers] is
  /// every nearby provider rather than a genuine skill match. The results
  /// screen shows a banner in this case — silently presenting unrelated
  /// providers as "your plumbers" would be worse than saying nothing matched.
  final bool isFallback;

  const WorkerSearchResult({required this.workers, required this.isFallback});

  bool get isEmpty => workers.isEmpty;
}
