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
import 'package:submersion/features/trips/presentation/widgets/story/day_map_pin_groups.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One story day's map: its itinerary location and one pin per dive, fitted
/// to the day's points (issue #2845). Tapping a dive pin reports the dive
/// through [onDiveTap] (null when the highlighted pin is tapped again); a
/// tap on the map itself reports through [onMapTap]; an [onExpand] handler
/// adds the fullscreen button.
///
/// Dive pins that would overlap on screen, at one site or at sites a few
/// metres apart, share one badge: the earliest dive's number with the
/// group's size on its corner. Tapping it lists the group's dives to choose
/// from (issue #2883). The groups follow the zoom, so in the fullscreen map
/// they come apart as the diver zooms in.
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

  /// Dive pins whose centres sit closer than this many pixels share a
  /// badge. A pin's dot is 28 wide inside a 48 pixel hit box, so nearer than
  /// this a tap aimed at one dot can land in its neighbour's box.
  static const double groupRadius = 32.0;

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

  /// The day's markers at [camera]'s zoom: a flag per itinerary location,
  /// then a pin per dive, or one badge for dives whose pins would overlap.
  /// Matching exact coordinates is not enough: two sites a few metres apart
  /// land on the same pixels at the day's fitted zoom (issue #2883).
  List<Marker> _markers(MapCamera camera) {
    final points = widget.points;
    final dives = [
      for (final p in points)
        if (p.isDive) p,
    ];
    final groups = groupNearbyPins(
      [for (final p in dives) camera.projectAtZoom(_latLng(p))],
      radius: TripDayMap.groupRadius,
      worldWidth: camera.getWorldWidthAtZoom(),
    );
    return [
      for (final (i, point) in points.indexed)
        if (!point.isDive) _marker(point, _PlacePin(point: point, index: i)),
      for (final group in groups)
        if (group.length == 1)
          _marker(
            dives[group.single],
            _DivePin(
              point: dives[group.single],
              highlighted:
                  dives[group.single].diveId == widget.highlightedDiveId,
              onTap: () => _tapDive(dives[group.single]),
            ),
          )
        else
          _marker(
            dives[group.first],
            _DiveGroupPin(
              points: [for (final i in group) dives[i]],
              highlightedDiveId: widget.highlightedDiveId,
              onChoose: _tapDive,
            ),
          ),
    ];
  }

  static LatLng _latLng(TripStoryMapPoint p) => LatLng(p.latitude, p.longitude);

  // 48x48 meets the touch-target guideline; the dot stays 28x28 inside it.
  static Marker _marker(TripStoryMapPoint point, Widget child) =>
      Marker(point: _latLng(point), width: 48, height: 48, child: child);

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
                // Its own builder, so a pan or zoom regroups the pins
                // without rebuilding the tiles.
                Builder(
                  builder: (context) =>
                      MarkerLayer(markers: _markers(MapCamera.of(context))),
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
          child: _PinDot(number: point.diveNumber, highlighted: highlighted),
        ),
      ),
    );
  }
}

/// Dives whose pins would overlap, as one badge: the earliest dive's dot
/// with the group's size on its corner, in the tertiary colour while any of
/// them is highlighted. Tapping it opens a menu of the dives; choosing one
/// acts as tapping its own pin would (issue #2883).
class _DiveGroupPin extends StatelessWidget {
  final List<TripStoryMapPoint> points;
  final String? highlightedDiveId;
  final ValueChanged<TripStoryMapPoint> onChoose;

  const _DiveGroupPin({
    required this.points,
    required this.highlightedDiveId,
    required this.onChoose,
  });

  Future<void> _openMenu(BuildContext context) async {
    final l10n = context.l10n;
    final badge = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final chosen = await showMenu<TripStoryMapPoint>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          badge.localToGlobal(Offset.zero, ancestor: overlay),
          badge.localToGlobal(
            badge.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final point in points)
          CheckedPopupMenuItem(
            key: Key('day-map-group-item-${point.diveId}'),
            value: point,
            checked: point.diveId == highlightedDiveId,
            child: Text(
              '${l10n.trips_story_dayMap_divePin(point.diveNumber ?? 0)}'
              ' · ${point.label}',
            ),
          ),
      ],
    );
    if (chosen != null && context.mounted) onChoose(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlighted = points.any((p) => p.diveId == highlightedDiveId);
    void open() => _openMenu(context);
    // A node of its own, as a single pin's is, so a screen reader finds it.
    return Semantics(
      container: true,
      button: true,
      selected: highlighted,
      label: context.l10n.trips_story_dayMap_diveGroup(points.length),
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('day-map-group-${points.first.diveId}'),
        onTap: open,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _PinDot(
                number: points.first.diveNumber,
                highlighted: highlighted,
              ),
              Positioned(
                top: -7,
                right: -7,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.onSecondaryContainer,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${points.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 28 pixel numbered dot a dive pin and a group badge share.
class _PinDot extends StatelessWidget {
  final int? number;
  final bool highlighted;

  const _PinDot({required this.number, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fill = highlighted ? colorScheme.tertiary : colorScheme.primary;
    final ink = highlighted ? colorScheme.onTertiary : colorScheme.onPrimary;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: ink, width: 2),
      ),
      child: Text(
        '${number ?? ''}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: ink,
          fontWeight: FontWeight.bold,
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
