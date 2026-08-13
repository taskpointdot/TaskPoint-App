import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'geo_utils.dart';
import 'session_controller.dart';

/// Publishes this device's GPS position to `users/{uid}.location` for as
/// long as a job is active, so the other side of that job can watch it move
/// on a real map.
///
/// The `users/{uid}.location` field and who reads it are unchanged — the
/// track-worker screen already read exactly this field. What was missing was
/// anything *keeping it fresh*: the worker's screen wrote a single fix in
/// `initState` and never updated it, so the seeker's "x km away" froze at
/// whatever the distance was the moment the worker opened the screen.
///
/// Sharing is opt-out via the existing `shareLiveLocation` privacy toggle on
/// Privacy & Security — [start] refuses to publish anything when that's off.
class LocationSharingService {
  LocationSharingService._();
  static final LocationSharingService instance = LocationSharingService._();

  StreamSubscription<GeoPoint>? _sub;

  bool get isSharing => _sub != null;

  /// Begins streaming position updates. Safe to call repeatedly — a second
  /// call replaces the first subscription rather than stacking a duplicate
  /// writer on the same document.
  ///
  /// Returns false when nothing will be published (signed out, permission
  /// denied, or the user turned live location off), so callers can show the
  /// "location unavailable" state instead of a map that will never move.
  Future<bool> start() async {
    final uid = SessionController.instance.uid;
    if (uid == null) return false;
    if (SessionController.instance.user?.shareLiveLocation == false) return false;

    // One immediate fix so the far end sees something without waiting for
    // the stream's 10-metre distance filter to trip.
    final initial = await currentDevicePosition();
    if (initial == null) return false;
    await _publish(uid, initial);

    await _sub?.cancel();
    _sub = devicePositionStream().listen(
      (pos) => _publish(uid, pos),
      onError: (_) {},
      cancelOnError: false,
    );
    return true;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Fire-and-forget: a dropped location write is not worth interrupting an
  /// in-progress job over, and the next position update overwrites it anyway.
  Future<void> _publish(String uid, GeoPoint position) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'location': position,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
