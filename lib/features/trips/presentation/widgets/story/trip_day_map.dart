import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_camera_fit.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One story day's map: its itinerary location and one pin per dive, fitted
/// to the day's points (issue #2845). Tapping a dive pin reports the dive
/// through [onDiveTap] (null when the highlighted pin is tapped again); a
/// tap on the map itself reports through [onMapTap]; an [onExpand] handler
/// adds the fullscreen button.
class TripDayMap extends ConsumerStatefulWidget {
  final TripStoryDay day;
  final List<TripStoryMapPoint> points;
  final String? highlightedDiveId;
  final ValueChanged<String?>? onDiveTap;
  final VoidCallback? onMapTap;
  final VoidCallback? onExpand;

  /// Whether the map pans and zooms. A story card turns it off so the map
  /// never catches the story's scroll; the fullscreen page leaves it on.
  final bool interactive;

  const TripDayMap({
    super.key,
    required this.day,
    required this.points,
    this.highlightedDiveId,
    this.onDiveTap,
    this.onMapTap,
    this.onExpand,
    this.interactive = true,
  });

  /// Zoomed out further the world shrinks to a strip; matches the other
  /// embedded detail maps.
  static const double minZoom = 2.0;

  /// A lone site gets a close view rather than a dot in an ocean.
  static const double singlePointZoom = 13.0;

  /// Pixels between pins that share a spot. Each pin's hit box is 48 wide,
  /// so the step must put every dot's centre outside its neighbour's box
  /// (more than 24): a 28 pixel dot and a gap.
  static const double stackOffset = 32.0;

  @override
  ConsumerState<TripDayMap> createState() => _TripDayMapState();
}

class _TripDayMapState extends ConsumerState<TripDayMap> {
  final MapController _controller = MapController();

  @override
  void didUpdateWidget(TripDayMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The initial fit runs once; a dive whose site moved, or a story whose
    // days shifted, brings new points that must be framed again.
    if (!listEquals(oldWidget.points, widget.points)) {
      _controller.fitCamera(_fit(ref.read(mapTileMaxZoomProvider)));
    }
  }

  WorldCameraFit _fit(double maxZoom) => WorldCameraFit(
    points: [for (final p in widget.points) LatLng(p.latitude, p.longitude)],
    padding: const EdgeInsets.all(32),
    maxZoom: maxZoom,
    singlePointZoom: TripDayMap.singlePointZoom,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Horizontal offsets for pins on the same spot: 0, +32, -32, +64, ...
  Map<int, double> _stackOffsets() {
    final seen = <String, int>{};
    final offsets = <int, double>{};
    for (final (i, p) in widget.points.indexed) {
      final key = '${p.latitude},${p.longitude}';
      final n = seen.update(key, (v) => v + 1, ifAbsent: () => 0);
      final step = (n + 1) ~/ 2 * TripDayMap.stackOffset;
      offsets[i] = n == 0 ? 0 : (n.isOdd ? step : -step);
    }
    return offsets;
  }

  void _tapDive(TripStoryMapPoint point) {
    final onDiveTap = widget.onDiveTap;
    if (onDiveTap == null) return;
    onDiveTap(point.diveId == widget.highlightedDiveId ? null : point.diveId);
  }

  /// The trackpad zoom wraps only an interactive map: it wins the gesture
  /// arena against any enclosing scrollable, which in a story card would turn
  /// a trackpad scroll over the map into a zoom.
  Widget _withTrackpad(double maxZoom, Widget map) => widget.interactive
      ? TrackpadZoomMap(
          controller: _controller,
          minZoom: TripDayMap.minZoom,
          maxZoom: maxZoom,
          child: map,
        )
      : map;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final maxZoom = ref.watch(mapTileMaxZoomProvider);
    final urlTemplate = ref.watch(mapTileUrlProvider);
    final offsets = _stackOffsets();

    return Semantics(
      label: l10n.trips_story_dayMap_semantics(widget.day.dayNumber),
      child: Stack(
        children: [
          _withTrackpad(
            maxZoom,
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCameraFit: _fit(maxZoom),
                minZoom: TripDayMap.minZoom,
                maxZoom: maxZoom,
                cameraConstraint: worldMapCameraConstraint,
                onTap: widget.onMapTap == null
                    ? null
                    : (_, _) => widget.onMapTap!(),
                // Interactive, it pans and zooms like the other embedded maps
                // with north up. In a story card it takes no gestures, as the
                // app's other maps in a scrolling list do: a drag over it
                // scrolls the story, and pins stay tappable.
                interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.all & ~InteractiveFlag.rotate
                      : InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: urlTemplate,
                  userAgentPackageName: 'app.submersion',
                  maxZoom: maxZoom,
                  tileProvider: TileCacheService.instance.tileProviderFor(
                    urlTemplate: urlTemplate,
                  ),
                ),
                MarkerLayer(
                  markers: [
                    for (final (i, point) in widget.points.indexed)
                      Marker(
                        point: LatLng(point.latitude, point.longitude),
                        // 48x48 meets the touch-target guideline; the dot
                        // stays 28x28 inside it.
                        width: 48,
                        height: 48,
                        child: Transform.translate(
                          offset: Offset(offsets[i]!, 0),
                          child: point.isDive
                              ? _DivePin(
                                  point: point,
                                  highlighted:
                                      point.diveId == widget.highlightedDiveId,
                                  onTap: () => _tapDive(point),
                                )
                              : _PlacePin(point: point, index: i),
                        ),
                      ),
                  ],
                ),
                const MapAttribution(),
              ],
            ),
          ),
          if (widget.onExpand != null)
            PositionedDirectional(
              top: 4,
              end: 4,
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.85),
                shape: const CircleBorder(),
                child: IconButton(
                  key: const Key('day-map-expand'),
                  tooltip: l10n.trips_story_dayMap_expand,
                  icon: const Icon(Icons.fullscreen),
                  onPressed: widget.onExpand,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A dive's pin: the day card's number in a circle, in the tertiary colour
/// while its row is highlighted.
class _DivePin extends StatelessWidget {
  final TripStoryMapPoint point;
  final bool highlighted;
  final VoidCallback onTap;

  const _DivePin({
    required this.point,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fill = highlighted ? colorScheme.tertiary : colorScheme.primary;
    final ink = highlighted ? colorScheme.onTertiary : colorScheme.onPrimary;
    // Its own node, activated by its own tap: without a container it merges
    // into the map's node, and excludeSemantics drops the detector's action,
    // so a screen reader could neither find nor press one pin of several.
    return Semantics(
      container: true,
      button: true,
      selected: highlighted,
      label: context.l10n.trips_story_dayMap_divePin(point.diveNumber ?? 0),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('day-map-pin-${point.diveId}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: ink, width: 2),
            ),
            child: Text(
              '${point.diveNumber ?? ''}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: ink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The itinerary location's flag; informative, not a button.
class _PlacePin extends StatelessWidget {
  final TripStoryMapPoint point;
  final int index;

  const _PlacePin({required this.point, required this.index});

  @override
  Widget build(BuildContext context) {
    // Its own node: a label-only Semantics would merge into the map's.
    return Semantics(
      container: true,
      label: point.label,
      child: Center(
        key: Key('day-map-pin-port-$index'),
        child: Icon(
          Icons.flag,
          size: 24,
          color: Theme.of(context).colorScheme.secondary,
          shadows: const [Shadow(blurRadius: 4)],
        ),
      ),
    );
  }
}
