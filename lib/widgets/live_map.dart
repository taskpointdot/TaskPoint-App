import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';

/// One pin on a [LiveMap].
///
/// Deliberately framed in terms of Firestore's [GeoPoint] rather than
/// Google's [LatLng], because every position in this app arrives as a
/// `GeoPoint` from a `users/{uid}.location` or `jobs/{id}.location` field —
/// callers shouldn't have to convert before they can draw.
class MapPoint {
  final String id;
  final GeoPoint position;
  final String title;
  final String? snippet;

  /// One of the `BitmapDescriptor.hue*` constants. Workers are drawn in the
  /// brand teal-ish hue and seekers/destinations in red so the two ends of a
  /// job are distinguishable at a glance.
  final double hue;

  const MapPoint({
    required this.id,
    required this.position,
    required this.title,
    this.snippet,
    this.hue = BitmapDescriptor.hueAzure,
  });
}

/// A real Google Map that re-fits itself whenever its [points] move.
///
/// This replaces the grey `Symbols.map_rounded` placeholder boxes that used
/// to stand in for a map on the tracking screens and the home dashboard.
/// Everything it draws is driven by whatever positions the caller streams
/// in, so a parent rebuilding from a Firestore snapshot is all it takes to
/// make the map live — no polling and no map-specific state in the screens.
class LiveMap extends StatefulWidget {
  final List<MapPoint> points;

  /// Draws the blue "you are here" dot and enables Google's own recentre
  /// button. Off by default because on the seeker's track-worker screen the
  /// interesting position is the *worker's*, not the viewer's.
  final bool showMyLocation;

  /// Zoom used when there's only one point to look at. Ignored when there
  /// are two or more, since those get a fitted bounding box instead.
  final double singlePointZoom;

  /// Extra bottom inset so pins aren't hidden behind a screen's bottom
  /// sheet / action card.
  final double bottomPadding;

  /// Shown centred over the map while [points] is still empty — e.g. while
  /// the first GPS fix or Firestore snapshot is in flight.
  final String emptyLabel;

  const LiveMap({
    super.key,
    required this.points,
    this.showMyLocation = false,
    this.singlePointZoom = 15,
    this.bottomPadding = 0,
    this.emptyLabel = 'Waiting for location…',
  });

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final _controller = Completer<GoogleMapController>();

  /// The positions the camera was last fitted to. Kept so that a parent
  /// rebuild that didn't actually move anything (a name loading in, a
  /// rating arriving) doesn't yank the camera back and fight a user who is
  /// panning around the map.
  String? _lastFittedKey;

  static const _fallbackCentre = CameraPosition(
    // Lahore — a sane starting frame for a Pakistan-based app while the
    // first real position is still resolving.
    target: LatLng(31.5204, 74.3587),
    zoom: 11,
  );

  String _keyFor(List<MapPoint> points) => points
      .map((p) => '${p.id}:${p.position.latitude.toStringAsFixed(5)},${p.position.longitude.toStringAsFixed(5)}')
      .join('|');

  @override
  void didUpdateWidget(covariant LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fitToPoints();
  }

  Future<void> _fitToPoints() async {
    if (widget.points.isEmpty) return;
    final key = _keyFor(widget.points);
    if (key == _lastFittedKey) return;
    _lastFittedKey = key;

    final controller = await _controller.future;
    if (!mounted) return;

    if (widget.points.length == 1) {
      final p = widget.points.first.position;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), widget.singlePointZoom),
      );
      return;
    }

    await controller.animateCamera(CameraUpdate.newLatLngBounds(_boundsOf(widget.points), 72));
  }

  /// Google's [LatLngBounds] asserts that southwest is genuinely south-west
  /// of northeast, so min/max each axis rather than assuming an ordering.
  LatLngBounds _boundsOf(List<MapPoint> points) {
    var minLat = points.first.position.latitude;
    var maxLat = minLat;
    var minLng = points.first.position.longitude;
    var maxLng = minLng;
    for (final p in points) {
      minLat = p.position.latitude < minLat ? p.position.latitude : minLat;
      maxLat = p.position.latitude > maxLat ? p.position.latitude : maxLat;
      minLng = p.position.longitude < minLng ? p.position.longitude : minLng;
      maxLng = p.position.longitude > maxLng ? p.position.longitude : maxLng;
    }
    // Two pins at (nearly) the same spot collapse the box to a point, which
    // makes newLatLngBounds zoom to max. Pad it out to a usable frame.
    const minSpan = 0.004;
    if (maxLat - minLat < minSpan) {
      final mid = (maxLat + minLat) / 2;
      minLat = mid - minSpan / 2;
      maxLat = mid + minSpan / 2;
    }
    if (maxLng - minLng < minSpan) {
      final mid = (maxLng + minLng) / 2;
      minLng = mid - minSpan / 2;
      maxLng = mid + minSpan / 2;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.points.isEmpty ? null : widget.points.first.position;
    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: first == null
                ? _fallbackCentre
                : CameraPosition(target: LatLng(first.latitude, first.longitude), zoom: widget.singlePointZoom),
            markers: {
              for (final p in widget.points)
                Marker(
                  markerId: MarkerId(p.id),
                  position: LatLng(p.position.latitude, p.position.longitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(p.hue),
                  infoWindow: InfoWindow(title: p.title, snippet: p.snippet),
                ),
            },
            myLocationEnabled: widget.showMyLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            onMapCreated: (c) {
              if (!_controller.isCompleted) _controller.complete(c);
              _fitToPoints();
            },
          ),
        ),
        if (widget.points.isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: AppColors.surfaceContainerHigh.withValues(alpha: 0.75),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.my_location_rounded, size: 40, color: AppColors.outlineVariant),
                    const SizedBox(height: 8),
                    Text(
                      widget.emptyLabel,
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
