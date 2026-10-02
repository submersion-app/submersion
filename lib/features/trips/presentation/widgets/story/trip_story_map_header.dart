import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Eases the flutter_map camera between positions (flutter_map has no
/// built-in animated move).
///
/// A gesture on the map, or any camera move the animator did not make (the
/// trackpad zoom moves the camera through the controller), stops a move in
/// flight, so the diver's drag or zoom is not pulled back toward the target
/// for the rest of the animation.
class MapCameraAnimator {
  final TickerProvider vsync;
  final MapController controller;
  AnimationController? _animation;
  StreamSubscription<MapEvent>? _gestureWatch;

  /// Tags the animator's own camera moves, which report
  /// [MapEventSource.mapController] like any other controller move.
  static const String _moveId = 'MapCameraAnimator';

  /// The sources a diver's own flutter_map gesture starts with. The band's
  /// resize reports [MapEventSource.nonRotatedSizeChange] and does not stop
  /// the animator.
  static const Set<MapEventSource> _userGestureSources = {
    MapEventSource.dragStart,
    MapEventSource.multiFingerGestureStart,
    MapEventSource.doubleTap,
    MapEventSource.doubleTapHold,
    MapEventSource.scrollWheel,
    MapEventSource.keyboard,
  };

  MapCameraAnimator({required this.vsync, required this.controller});

  /// Whether a move is in flight and listening for the diver's gestures.
  @visibleForTesting
  bool get isWatchingGestures => _gestureWatch != null;

  void animateTo({required LatLng center, required double zoom}) {
    _stop();
    final camera = controller.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: center.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: center.longitude,
    );
    final zoomTween = Tween<double>(begin: camera.zoom, end: zoom);

    final animation = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 450),
    );
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    animation.addListener(() {
      controller.move(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
        id: _moveId,
      );
    });
    _gestureWatch = controller.mapEventStream.listen((event) {
      final movedByOther =
          event is MapEventMove &&
          event.source == MapEventSource.mapController &&
          event.id != _moveId;
      if (movedByOther || _userGestureSources.contains(event.source)) _stop();
    });
    // Nothing left to interrupt once the move lands.
    animation.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _gestureWatch?.cancel();
      _gestureWatch = null;
    });
    animation.forward();
    _animation = animation;
  }

  void _stop() {
    _gestureWatch?.cancel();
    _gestureWatch = null;
    _animation?.dispose();
    _animation = null;
  }

  void dispose() => _stop();
}

/// The story map: the trip's route and its day pins.
///
/// It renders the gradient fallback itself when the trip has no mappable
/// points, so the band can hold one map instance either way.
class TripStoryMap extends ConsumerWidget {
  final TripStoryMapGeometry geometry;
  final int activeDayIndex;
  final MapController mapController;
  final ValueChanged<int> onDaySelected;

  /// Zoomed out further, the world shrinks to a strip inside the band. Matches
  /// the other embedded detail maps.
  static const double _minZoom = 2.0;

  const TripStoryMap({
    super.key,
    required this.geometry,
    required this.activeDayIndex,
    required this.mapController,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!geometry.hasPoints) return const _MapFallback();

    final colorScheme = Theme.of(context).colorScheme;
    final points = geometry.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final bounds = LatLngBounds.fromPoints(points);
    final zoom = calculateZoomForBounds(points, bounds);
    // Past the style's deepest tiles the tile layer draws nothing, so zoom
    // stops there rather than blanking the band.
    final maxZoom = ref.watch(mapTileMaxZoomProvider);

    return Semantics(
      label: context.l10n.trips_story_map_semantics,
      child: TrackpadZoomMap(
        controller: mapController,
        minZoom: _minZoom,
        maxZoom: maxZoom,
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: bounds.center,
            initialZoom: zoom,
            minZoom: _minZoom,
            maxZoom: maxZoom,
            // Stops at the poles and wraps east and west, like the app's
            // other maps that pan.
            cameraConstraint: worldMapCameraConstraint,
            // Pans and zooms like the other embedded detail maps. A drag that
            // starts on the map moves the map, not the page; the camera still
            // eases back to the active day whenever that day changes.
            // Rotation stays off so the overview keeps north up.
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: ref.watch(mapTileUrlProvider),
              userAgentPackageName: 'app.submersion',
              maxZoom: maxZoom,
              tileProvider: TileCacheService.instance.tileProviderFor(
                urlTemplate: ref.watch(mapTileUrlProvider),
              ),
            ),
            // A route only makes sense with at least two points.
            if (points.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 2,
                    color: colorScheme.primary.withValues(alpha: 0.5),
                    pattern: const StrokePattern.dotted(),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final point in geometry.points)
                  Marker(
                    point: LatLng(point.latitude, point.longitude),
                    // 48x48 meets the minimum touch-target guideline even though
                    // the visible dot stays 28x28 (centered inside the hit area).
                    width: 48,
                    height: 48,
                    child: Semantics(
                      button: true,
                      label: point.label.isNotEmpty
                          ? point.label
                          : context.l10n.trips_story_dayLabel(
                              point.dayIndex + 1,
                            ),
                      child: GestureDetector(
                        onTap: () => onDaySelected(point.dayIndex),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Opacity(
                            opacity: point.dayIndex == activeDayIndex
                                ? 1
                                : 0.45,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.onPrimary,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.scuba_diving,
                                size: 14,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const MapAttribution(),
          ],
        ),
      ),
    );
  }
}

/// Gradient card shown when the trip has no mappable points.
class _MapFallback extends StatelessWidget {
  const _MapFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primaryContainer, colorScheme.surface],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.scuba_diving,
        size: 48,
        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
      ),
    );
  }
}
