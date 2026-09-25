import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
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

/// A stack of co-located points the strip is showing.
class _StripSelection {
  const _StripSelection({required this.title, required this.points});
  final String title;
  final List<MediaMapPoint> points;
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
  /// point list instance or the localisations change. The plugin re-clusters
  /// whenever it receives a different list instance and keys cluster tiles
  /// by node, so a fresh list on every build (a strip toggle, a loading
  /// flip) would recreate every cluster thumbnail and blink it.
  List<Marker> _markers = const [];
  List<MediaMapPoint>? _markersFor;
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
  /// keys. Markers without one of our keys are ignored.
  List<MediaMapPoint> _pointsFor(
    Iterable<Marker> markers,
    Map<String, MediaMapPoint> byId,
  ) {
    final points = <MediaMapPoint>[];
    for (final marker in markers) {
      final key = marker.key;
      if (key is ValueKey<String>) {
        final point = byId[key.value];
        if (point != null) points.add(point);
      }
    }
    return points;
  }

  void _onClusterTap(MarkerClusterNode node, Map<String, MediaMapPoint> byId) {
    final cluster = _pointsFor(node.mapMarkers, byId);
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
        _strip = _StripSelection(title: _titleFor(cluster), points: cluster);
      });
    } else {
      _animator.animateToBounds(node.bounds, maxZoom: _maxZoom);
    }
  }

  List<Marker> _markersFrom(BuildContext context, List<MediaMapPoint> points) {
    final l10n = context.l10n;
    if (identical(points, _markersFor) && identical(l10n, _markersL10n)) {
      return _markers;
    }
    _markersFor = points;
    _markersL10n = l10n;
    _markers = [
      for (final p in points)
        Marker(
          key: ValueKey<String>(p.item.id),
          point: p.point,
          width: kMediaMapMarkerSize,
          height: kMediaMapMarkerSize,
          child: Semantics(
            button: true,
            label: l10n.media_map_markerSemantics,
            child: GestureDetector(
              onTap: () => widget.openViewer(context, [p.item], p.item.id),
              child: MediaMapMarker(item: p.item),
            ),
          ),
        ),
    ];
    return _markers;
  }

  void _closeStrip() {
    if (_strip == null) return;
    setState(() => _strip = null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mediaLibraryFilterProvider, (_, _) => _pendingFit = true);
    ref.listen(mediaMapPointsProvider, (_, next) => _fitIfPending(next));

    final state = ref.watch(mediaMapPointsProvider);
    final l10n = context.l10n;

    if (state.isLoading && state.points.isEmpty && state.error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.points.isEmpty) {
      return _buildErrorState(context, state.error!);
    }

    final byId = {for (final p in state.points) p.item.id: p};
    final colorScheme = Theme.of(context).colorScheme;
    final strip = _strip;

    return Stack(
      children: [
        TrackpadZoomMap(
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
                    final cluster = _pointsFor(markers, byId);
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
                  onClusterTap: (node) => _onClusterTap(node, byId),
                ),
              ),
              const MapAttribution(),
            ],
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

        if (strip != null)
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
                    title: strip.title,
                    points: strip.points,
                    onClose: _closeStrip,
                    onItemTap: (point) => widget.openViewer(
                      context,
                      strip.points.map((p) => p.item).toList(),
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
