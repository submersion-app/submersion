import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_camera_animator.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_map_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_marker.dart';
import 'package:submersion/features/media/presentation/widgets/media_place_strip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The library's map view mode: every located item as a thumbnail marker,
/// clustered, with a place strip for stacks that share one point.
///
/// Mirrors the dive map's widget tree (trackpad wrapper, world-constrained
/// rotatable map, the shared tile layer, the marker cluster layer,
/// attribution, compass, fit-all) without its heat map, seascape or
/// bathymetry layers. Camera moves go through [MapCameraAnimator].
class MediaMapContent extends ConsumerStatefulWidget {
  const MediaMapContent({super.key, this.openViewer = openMediaViewer});

  /// How a tap reaches the viewer. Injected so tests can capture the call
  /// instead of pushing the real viewer and its provider graph.
  final MediaViewerOpener openViewer;

  @override
  ConsumerState<MediaMapContent> createState() => _MediaMapContentState();
}

/// A stack of co-located points the strip is showing, by id, so the strip
/// always renders the current item for each, and its title follows the
/// current place label (a site rename shows without reopening the strip).
class _StripSelection {
  const _StripSelection({required this.ids});
  final List<String> ids;
}

/// Where each item sits, in order: what the cluster layer clusters and the
/// strip's stack is drawn from. Item fields that do not move a point
/// (favorite, thumbnail, store upload stamps) are not part of it.
typedef _Layout = List<(String, LatLng)>;

_Layout _layoutOf(List<MediaMapPoint> points) => [
  for (final p in points) (p.item.id, p.point),
];

/// Hands the current points to the memoised marker widgets inside the map,
/// so a reload that changes an item but not the layout reaches every tile
/// without giving the cluster layer a new marker list (which re-clusters).
class _CurrentPoints extends InheritedWidget {
  const _CurrentPoints({required this.byId, required super.child});

  final Map<String, MediaMapPoint> byId;

  static Map<String, MediaMapPoint> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CurrentPoints>()!.byId;

  @override
  bool updateShouldNotify(_CurrentPoints oldWidget) =>
      !identical(oldWidget.byId, byId);
}

/// One single-item marker. Reads its item by id so it always shows (and
/// opens) the current version.
class _MarkerTile extends StatelessWidget {
  const _MarkerTile({required this.id, required this.onTap});

  final String id;
  final ValueChanged<MediaMapPoint> onTap;

  @override
  Widget build(BuildContext context) {
    final point = _CurrentPoints.of(context)[id];
    if (point == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => onTap(point),
      child: MediaMapMarker(item: point.item),
    );
  }
}

class _MediaMapContentState extends ConsumerState<MediaMapContent>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final MapCameraAnimator _animator = MapCameraAnimator(
    controller: _mapController,
    vsync: this,
  );

  static const _defaultCenter = LatLng(20.0, 0.0);
  static const _defaultZoom = 2.0;
  static const _minZoom = 2.0;
  static const _maxZoom = 18.0;

  bool _mapReady = false;

  /// True until the next successful data delivery has been fitted. Set on
  /// first build and on every filter change; NOT on table-write reloads,
  /// which would yank the camera mid-browse.
  bool _pendingFit = true;

  _StripSelection? _strip;

  /// The marker list handed to the cluster layer, rebuilt only when the
  /// layout or the localisations change. The plugin re-clusters whenever it
  /// receives a different list instance and keys cluster tiles by node, so a
  /// fresh list on every build (a strip toggle, a loading flip, a store
  /// upload stamping a row) would recreate every cluster thumbnail and blink
  /// it. Item changes reach the tiles through [_CurrentPoints] instead.
  List<Marker> _markers = const [];
  _Layout? _markersFor;
  Object? _markersL10n;

  @override
  void dispose() {
    _animator.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _fitIfPending(MediaMapState state) {
    if (!_pendingFit || !_mapReady) return;
    if (state.isLoading && state.points.isEmpty) return;
    if (state.error != null) return;
    _pendingFit = false;
    _animator.fitAll(state.points.map((p) => p.point).toList());
  }

  String _titleFor(List<MediaMapPoint> cluster) {
    final label = cluster
        .map((p) => p.placeLabel)
        .firstWhere((l) => l != null, orElse: () => null);
    if (label != null) return label;
    final first = cluster.first.point;
    final units = UnitFormatter(ref.read(settingsProvider));
    return units.formatCoordinates(first.latitude, first.longitude);
  }

  MediaMapPoint _representative(List<MediaMapPoint> cluster) =>
      cluster.firstWhere((p) => p.item.isFavorite, orElse: () => cluster.first);

  /// Recovers the points behind the plugin's markers through their media-id
  /// keys, in library order (date taken, oldest first). The plugin's own
  /// traversal order follows its nested cluster tree, not the dates, so it
  /// cannot be trusted for the representative or the strip. Markers without
  /// one of our keys are ignored.
  List<MediaMapPoint> _pointsFor(
    Iterable<Marker> markers,
    Map<String, MediaMapPoint> byId,
    Map<String, int> orderOf,
  ) {
    final points = <MediaMapPoint>[];
    for (final marker in markers) {
      final key = marker.key;
      if (key is ValueKey<String>) {
        final point = byId[key.value];
        if (point != null) points.add(point);
      }
    }
    points.sort((x, y) => orderOf[x.item.id]!.compareTo(orderOf[y.item.id]!));
    return points;
  }

  void _onClusterTap(
    MarkerClusterNode node,
    Map<String, MediaMapPoint> byId,
    Map<String, int> orderOf,
  ) {
    final cluster = _pointsFor(node.mapMarkers, byId, orderOf);
    if (cluster.isEmpty) return;
    final first = cluster.first.point;
    final coLocated = cluster.every((p) => p.point == first);
    // A tap that cannot zoom further in cannot separate the cluster. The
    // dive map caps cluster zoom at 14, but photos with their own GPS fix
    // sit metres apart and stay clustered there, so the media map fits to
    // the map's own maximum and treats "no zoom progress" as a stack.
    final camera = _mapController.camera;
    final target = CameraFit.bounds(
      bounds: node.bounds,
      padding: const EdgeInsets.all(120),
      maxZoom: _maxZoom,
    ).fit(camera);
    final noProgress = target.zoom <= camera.zoom + 0.01;
    if (coLocated || noProgress) {
      setState(() {
        _strip = _StripSelection(ids: [for (final p in cluster) p.item.id]);
      });
    } else {
      _animator.animateToBounds(node.bounds, maxZoom: _maxZoom);
    }
  }

  List<Marker> _markersFrom(BuildContext context, List<MediaMapPoint> points) {
    final l10n = context.l10n;
    final layout = _layoutOf(points);
    final previous = _markersFor;
    if (previous != null &&
        listEquals(previous, layout) &&
        identical(l10n, _markersL10n)) {
      return _markers;
    }
    _markersFor = layout;
    _markersL10n = l10n;
    _markers = [
      for (final (id, point) in layout)
        Marker(
          key: ValueKey<String>(id),
          point: point,
          width: kMediaMapMarkerSize,
          height: kMediaMapMarkerSize,
          child: Semantics(
            button: true,
            label: l10n.media_map_markerSemantics,
            child: _MarkerTile(
              id: id,
              onTap: (p) => widget.openViewer(context, [p.item], p.item.id),
            ),
          ),
        ),
    ];
    return _markers;
  }

  /// The filter or the diver changed: the next points refit the camera, and
  /// any open strip belongs to the old scope.
  void _onScopeChanged() {
    _pendingFit = true;
    if (_strip != null && mounted) setState(() => _strip = null);
  }

  void _closeStrip() {
    if (_strip == null) return;
    setState(() => _strip = null);
  }

  @override
  Widget build(BuildContext context) {
    // The strip shows one stack, so it closes whenever that stack's layout
    // goes away: a filter or diver change, or a reload that adds, removes or
    // moves a point. A reload that only changes items (a favorite, a store
    // upload) keeps it open; it renders the current items by id.
    ref.listen(mediaLibraryFilterProvider, (_, _) => _onScopeChanged());
    ref.listen(currentDiverIdProvider, (_, _) => _onScopeChanged());
    ref.listen(mediaMapPointsProvider, (previous, next) {
      // The watched provider rebuilds this widget, so a field write is
      // enough here.
      if (previous != null &&
          !listEquals(_layoutOf(previous.points), _layoutOf(next.points))) {
        _strip = null;
      }
      _fitIfPending(next);
    });

    final state = ref.watch(mediaMapPointsProvider);
    final l10n = context.l10n;

    // Both early returns unmount the FlutterMap, so the controller is
    // detached until the next onMapReady; a fit must wait for that.
    // An in-flight move is cancelled too: its ticker would keep driving the
    // detached controller and could overwrite the fit that follows.
    if (state.isLoading && state.points.isEmpty && state.error == null) {
      _mapReady = false;
      _animator.dispose();
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.points.isEmpty) {
      _mapReady = false;
      _animator.dispose();
      return _buildErrorState(context, state.error!);
    }

    final byId = {for (final p in state.points) p.item.id: p};
    final orderOf = {
      for (var i = 0; i < state.points.length; i++) state.points[i].item.id: i,
    };
    final colorScheme = Theme.of(context).colorScheme;
    final strip = _strip;
    final stripPoints = strip == null
        ? const <MediaMapPoint>[]
        : [for (final id in strip.ids) ?byId[id]];

    return Stack(
      children: [
        _CurrentPoints(
          byId: byId,
          child: TrackpadZoomMap(
            controller: _mapController,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: _defaultZoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                interactionOptions: rotatableMapInteraction,
                onMapReady: () {
                  _mapReady = true;
                  _fitIfPending(ref.read(mediaMapPointsProvider));
                },
                onTap: (_, _) => _closeStrip(),
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    const LatLng(-90, -180),
                    const LatLng(90, 180),
                  ),
                ),
              ),
              children: [
                submersionTileLayer(ref),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 80,
                    size: const Size(kMediaMapMarkerSize, kMediaMapMarkerSize),
                    markers: _markersFrom(context, state.points),
                    builder: (context, markers) {
                      final cluster = _pointsFor(markers, byId, orderOf);
                      if (cluster.isEmpty) return const SizedBox.shrink();
                      return Semantics(
                        button: true,
                        label: l10n.media_map_clusterSemantics(
                          cluster.length,
                          _titleFor(cluster),
                        ),
                        child: MediaMapMarker(
                          item: _representative(cluster).item,
                          count: cluster.length,
                        ),
                      );
                    },
                    zoomToBoundsOnClick: false,
                    // The place strip replaces the plugin's spiderfy fan for a
                    // stack; leaving it on would draw both, and each fanned
                    // tile would open a one-item viewer instead of the stack.
                    spiderfyCluster: false,
                    onClusterTap: (node) => _onClusterTap(node, byId, orderOf),
                  ),
                ),
                const MapAttribution(),
              ],
            ),
          ),
        ),

        // Controls card: fit-all, plus the unlocated count when non-zero.
        Positioned(
          top: 8,
          right: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.unlocatedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      child: Text(
                        l10n.media_map_unlocatedCount(state.unlocatedCount),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  // A reload failed but the last points are still on screen:
                  // say so, rather than leaving stale markers unexplained.
                  if (state.error != null)
                    IconButton(
                      icon: Icon(
                        Icons.sync_problem,
                        size: 20,
                        color: colorScheme.error,
                      ),
                      tooltip: l10n.media_map_errorLoading(
                        state.error.toString(),
                      ),
                      onPressed: () => ref.invalidate(mediaMapPointsProvider),
                    ),
                  IconButton(
                    icon: const Icon(Icons.my_location, size: 20),
                    tooltip: l10n.diveLog_map_tooltip_fitAllSites,
                    onPressed: () => _animator.fitAll(
                      state.points.map((p) => p.point).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top: 64,
          right: 8,
          child: MapCompassButton(controller: _mapController),
        ),

        if (state.points.isEmpty)
          Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.media_map_emptyTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.media_map_emptyHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (strip != null && stripPoints.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: MediaPlaceStrip(
                    title: _titleFor(stripPoints),
                    points: stripPoints,
                    onClose: _closeStrip,
                    onItemTap: (point) => widget.openViewer(
                      context,
                      stripPoints.map((p) => p.item).toList(),
                      point.item.id,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(l10n.media_map_errorLoading(error.toString())),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(mediaMapPointsProvider),
            child: Text(l10n.diveLog_error_retry),
          ),
        ],
      ),
    );
  }
}
