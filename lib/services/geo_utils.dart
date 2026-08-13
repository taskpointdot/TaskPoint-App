import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Straight-line distance in kilometers between two points (Haversine
/// formula). Firestore has no native radius query, and at this app's scale
/// filtering a broad query client-side is simpler and cheaper than adding a
/// geo-indexing package or a Cloud Function.
double distanceKm(GeoPoint a, GeoPoint b) {
  const earthRadiusKm = 6371.0;
  final dLat = _deg2rad(b.latitude - a.latitude);
  final dLon = _deg2rad(b.longitude - a.longitude);
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(a.latitude)) * cos(_deg2rad(b.latitude)) * sin(dLon / 2) * sin(dLon / 2);
  return earthRadiusKm * 2 * atan2(sqrt(h), sqrt(1 - h));
}

double _deg2rad(double deg) => deg * (pi / 180);

/// Current device GPS position, requesting permission if needed. Returns
/// null if the user denies the permission or location services are off —
/// callers should fall back gracefully (e.g. show all jobs, not just
/// nearby ones) rather than crash.
Future<GeoPoint?> currentDevicePosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    return GeoPoint(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}

/// A live stream of device position updates, for the "track worker/customer
/// location" screens. Same fallback behavior as [currentDevicePosition].
Stream<GeoPoint> devicePositionStream() {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
  ).map((pos) => GeoPoint(pos.latitude, pos.longitude));
}
