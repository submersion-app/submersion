import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_camera.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_color_legend.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_point_info_card.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_stats_header.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_timeline_scrubber.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Full-screen map of one recorded GPS surface track.
class GpsTrackDetailPage extends ConsumerStatefulWidget {
  const GpsTrackDetailPage({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<GpsTrackDetailPage> createState() => _GpsTrackDetailPageState();
}

/// Which overflow-menu entry was chosen.
enum _TrackAction {
  shareGpx,
  saveGpx,
  shareKml,
  saveKml,
  trim,
  split,
  resetTrim,
}

/// Which editing affordance the detail page is showing.
enum TrackEditMode { none, trim, split }

/// Active editing mode on the track detail page.
///
/// autoDispose so leaving the page (by any route, not just Cancel) resets it.
/// A plain StateProvider carried trim mode onto the NEXT track opened, where
/// Apply would then act on a track the user never meant to edit.
final trackEditModeProvider = StateProvider.autoDispose<TrackEditMode>(
  (ref) => TrackEditMode.none,
);

class _GpsTrackDetailPageState extends ConsumerState<GpsTrackDetailPage> {
  final MapController _mapController = MapController();
  final _log = LoggerService.forClass(GpsTrackDetailPage);

  /// Live scrubber values, applied only when the user confirms.
  int? _pendingStartMs;
  int? _pendingEndMs;

  Future<void> _onMenu(_TrackAction action, GpsTrack track) async {
    // Seed the pending values to what the scrubber will visibly show, so
    // confirming WITHOUT dragging does exactly what the screen depicts.
    // Leaving them null meant Apply wrote (null, null) - identical to
    // clearTrim - silently erasing an existing trim.
    final points = track.effectivePoints;
    final spanStart = points.isEmpty ? null : points.first.timestamp * 1000;
    final spanEnd = points.isEmpty ? null : points.last.timestamp * 1000;

    switch (action) {
      case _TrackAction.trim:
        _pendingStartMs = spanStart;
        _pendingEndMs = spanEnd;
        ref.read(trackEditModeProvider.notifier).state = TrackEditMode.trim;
      case _TrackAction.split:
        // Matches TrackTimelineScrubber's initial single-handle position.
        _pendingStartMs = (spanStart == null || spanEnd == null)
            ? null
            : spanStart + (spanEnd - spanStart) ~/ 2;
        ref.read(trackEditModeProvider.notifier).state = TrackEditMode.split;
      case _TrackAction.resetTrim:
        await ref.read(trimTrackProvider)(track.id);
      default:
        await _export(action, track);
    }
  }

  Future<void> _applyTrim(GpsTrack track) async {
    await ref.read(trimTrackProvider)(
      track.id,
      startMs: _pendingStartMs,
      endMs: _pendingEndMs,
    );
    if (!mounted) return;
    ref.read(trackEditModeProvider.notifier).state = TrackEditMode.none;
  }

  Future<void> _applySplit(GpsTrack track) async {
    final at = _pendingStartMs;
    if (at == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(splitTrackProvider)(track.id, at);
      if (!mounted) return;
      ref.read(trackEditModeProvider.notifier).state = TrackEditMode.none;
      Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('${e.message}')));
    }
  }

  /// Trim or split controls, shown only while the corresponding mode is on.
  Widget _buildEditPanel(
    BuildContext context,
    GpsTrack track,
    List<GpsTrackPoint> points,
  ) {
    final mode = ref.watch(trackEditModeProvider);
    if (mode == TrackEditMode.none) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final startMs = points.first.timestamp * 1000;
    final endMs = points.last.timestamp * 1000;
    final isSplit = mode == TrackEditMode.split;

    return Card(
      key: const ValueKey('gps-track-edit-panel'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrackTimelineScrubber(
              startMs: startMs,
              endMs: endMs,
              mode: isSplit
                  ? TrackScrubberMode.single
                  : TrackScrubberMode.range,
              onChanged: (s, e) {
                _pendingStartMs = s;
                _pendingEndMs = isSplit ? null : e;
              },
            ),
            if (isSplit) ...[
              const SizedBox(height: 4),
              // Trim is reversible and split is not, so only split warns.
              Text(
                l10n.gpsTrack_edit_splitWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('gps-track-edit-cancel'),
                  onPressed: () =>
                      ref.read(trackEditModeProvider.notifier).state =
                          TrackEditMode.none,
                  child: Text(l10n.gpsTrack_edit_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('gps-track-edit-apply'),
                  onPressed: () =>
                      isSplit ? _applySplit(track) : _applyTrim(track),
                  child: Text(
                    isSplit
                        ? l10n.gpsTrack_edit_confirmSplit
                        : l10n.gpsTrack_edit_applyTrim,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(_TrackAction action, GpsTrack track) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final gpx = ref.read(gpxExportServiceProvider);
    final kml = ref.read(kmlExportServiceProvider);

    try {
      final String? path = switch (action) {
        _TrackAction.shareGpx => await gpx.shareTrack(track),
        _TrackAction.saveGpx => await gpx.saveTrackToFile(track),
        _TrackAction.shareKml => await kml.shareTrackKml(track),
        _TrackAction.saveKml => await kml.saveTrackKmlToFile(track),
        _ => null,
      };
      if (!mounted) return;
      // A null path means the user cancelled the picker. That is not a
      // failure, and reporting it as one trains people to ignore the message.
      if (path == null) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gpsTrack_export_saved)),
      );
    } catch (e, stackTrace) {
      _log.error('GPS track export failed', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gpsTrack_export_failed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trackAsync = ref.watch(gpsTrackDetailProvider(widget.trackId));

    final track = trackAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gpsTrack_detail_title),
        actions: [
          if (track != null)
            PopupMenuButton<_TrackAction>(
              key: const ValueKey('gps-track-overflow'),
              tooltip: l10n.gpsTrack_action_export,
              onSelected: (action) => _onMenu(action, track),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _TrackAction.shareGpx,
                  child: Text(l10n.gpsTrack_action_shareGpx),
                ),
                PopupMenuItem(
                  value: _TrackAction.saveGpx,
                  child: Text(l10n.gpsTrack_action_saveGpx),
                ),
                PopupMenuItem(
                  value: _TrackAction.shareKml,
                  child: Text(l10n.gpsTrack_action_shareKml),
                ),
                PopupMenuItem(
                  value: _TrackAction.saveKml,
                  child: Text(l10n.gpsTrack_action_saveKml),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _TrackAction.trim,
                  child: Text(l10n.gpsTrack_action_trim),
                ),
                PopupMenuItem(
                  value: _TrackAction.split,
                  child: Text(l10n.gpsTrack_action_split),
                ),
                // Only offered when there is a trim to undo.
                if (track.trimStartTime != null || track.trimEndTime != null)
                  PopupMenuItem(
                    value: _TrackAction.resetTrim,
                    child: Text(l10n.gpsTrack_action_resetTrim),
                  ),
              ],
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(52),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _ColorModeSelector(),
          ),
        ),
      ),
      body: trackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // A corrupt or undecodable blob must not crash the page. Surface it
        // as a readable message; deletion is offered from the list.
        error: (_, _) => Center(child: Text(l10n.gpsTrack_detail_unreadable)),
        data: (track) {
          if (track == null) {
            return Center(child: Text(l10n.gpsTrack_detail_notFound));
          }
          final points = track.effectivePoints;
          if (points.length < 2) {
            return Center(child: Text(l10n.gpsTrack_detail_noPoints));
          }
          return Column(
            children: [
              TrackStatsHeader(
                points: points,
                diveCount:
                    ref
                        .watch(divesOnTrackProvider(widget.trackId))
                        .value
                        ?.length ??
                    0,
              ),
              _buildEditPanel(context, track, points),
              Expanded(
                child: _TrackMap(
                  trackId: widget.trackId,
                  fallbackPoints: points,
                  controller: _mapController,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The colour-mode toggle, watching trackColorModeProvider on its own.
///
/// Watching it in the page's build instead meant a toggle rebuilt the whole
/// Scaffold body, and TrackStatsHeader recomputes distance and speedRange
/// over the full decoded list - up to ~20k points - on every rebuild. The
/// toggle is supposed to cost a frame; that made it O(n) twice.
class _ColorModeSelector extends ConsumerWidget {
  const _ColorModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(trackColorModeProvider);
    return SegmentedButton<TrackColorMode>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: TrackColorMode.uniform,
          label: Text(l10n.gpsTrack_colorMode_uniform),
        ),
        ButtonSegment(
          value: TrackColorMode.speed,
          label: Text(l10n.gpsTrack_colorMode_speed),
        ),
        ButtonSegment(
          value: TrackColorMode.elapsed,
          label: Text(l10n.gpsTrack_colorMode_elapsed),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) {
        // Only bucketizeTrack re-runs; the decoded and simplified geometry
        // stay resident, so this is a frame not a reload.
        ref.read(trackColorModeProvider.notifier).state = selection.first;
      },
    );
  }
}

class _TrackMap extends ConsumerStatefulWidget {
  const _TrackMap({
    required this.trackId,
    required this.fallbackPoints,
    required this.controller,
  });

  final String trackId;
  final List<GpsTrackPoint> fallbackPoints;
  final MapController controller;

  @override
  ConsumerState<_TrackMap> createState() => _TrackMapState();
}

class _TrackMapState extends ConsumerState<_TrackMap> {
  final LayerHitNotifier<int> _hitNotifier = ValueNotifier(null);
  ({GpsTrackPoint point, double speedMps})? _inspected;

  bool _mapReady = false;

  /// The point list the camera is currently framed on, by identity.
  ///
  /// Every geometry list comes from a List.unmodifiable, so a trim or a
  /// finished simplify always yields a NEW instance - which is exactly the
  /// signal that the framing is stale.
  List<GpsTrackPoint>? _framedOn;

  String get trackId => widget.trackId;
  List<GpsTrackPoint> get fallbackPoints => widget.fallbackPoints;
  MapController get controller => widget.controller;

  @override
  void dispose() {
    _hitNotifier.dispose();
    super.dispose();
  }

  /// Re-frames the camera when the drawn geometry changes identity.
  ///
  /// initialCameraFit only applies on first layout, so without this a trim,
  /// a filter change, or geometry arriving after the first AsyncLoading frame
  /// all leave the map showing the previous extent.
  void _scheduleRefitIfNeeded(
    List<GpsTrackPoint> drawable,
    TrackCamera camera,
  ) {
    if (!_mapReady || identical(_framedOn, drawable)) return;
    _framedOn = drawable;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) camera.applyTo(controller);
    });
  }

  /// Resolves a tap on the polyline back to a real recorded fix.
  void _handleTap(List<TrackRun> runs, List<GpsTrackPoint> fullPoints) {
    final hit = _hitNotifier.value;
    if (hit == null || hit.hitValues.isEmpty) {
      // Tapped the layer but missed the line: dismiss.
      setState(() => _inspected = null);
      return;
    }
    final runIndex = hit.hitValues.first;
    if (runIndex < 0 || runIndex >= runs.length) return;
    final found = nearestPointInRun(
      fullPoints: fullPoints,
      run: runs[runIndex],
      tapped: hit.coordinate,
    );
    setState(() => _inspected = found);
  }

  @override
  Widget build(BuildContext context) {
    // Fall back to the unsimplified points while the isolate is working, so
    // the map draws immediately rather than flashing empty.
    final points =
        ref.watch(gpsTrackGeometryProvider((trackId, TrackLod.detail))).value ??
        fallbackPoints;
    final drawable = points.length >= 2 ? points : fallbackPoints;
    final mode = ref.watch(trackColorModeProvider);
    final runs = bucketizeTrack(drawable, mode);
    // LatLngBounds asserts east <= 180, so an antimeridian track cannot be
    // expressed as bounds and gets a centre+zoom instead.
    final camera = TrackCamera.forPoints(drawable)!;

    final inspected = _inspected;
    _scheduleRefitIfNeeded(drawable, camera);

    return Stack(
      children: [
        Positioned.fill(
          child: TrackpadZoomMap(
            controller: controller,
            child: FlutterMap(
              mapController: controller,
              options: MapOptions(
                onMapReady: () {
                  _mapReady = true;
                  _framedOn = drawable;
                },
                initialCameraFit: camera.fit,
                initialCenter: camera.center ?? const LatLng(0, 0),
                initialZoom: camera.zoom ?? 13.0,
                interactionOptions: rotatableMapInteraction,
              ),
              children: [
                submersionTileLayer(ref),
                // The notifier is populated by the layer's own hit test, so
                // the tap handler has to wrap the layer - MapOptions.onTap
                // fires without it being set.
                GestureDetector(
                  // deferToChild (the default) means a tap that misses the
                  // drawn line never reaches this handler, so the card could
                  // only be dismissed with its close button.
                  behavior: HitTestBehavior.translucent,
                  // Resolve against the FULL decoded list, not the simplified
                  // one: at the 2 m LOD a straight 3-minute transit keeps only
                  // its endpoints, so tapping the middle reported a timestamp
                  // up to ~90 s off with another fix's accuracy. This is the
                  // contract track_point_lookup_test asserts.
                  onTap: () => _handleTap(runs, fallbackPoints),
                  child: GpsTrackPolylineLayer(
                    runs: runs,
                    mode: mode,
                    hitNotifier: _hitNotifier,
                  ),
                ),
                MarkerLayer(markers: _markers(context, drawable)),
                const MapAttribution(),
                MapCompassButton(controller: controller),
              ],
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: TrackColorLegend(
            mode: mode,
            speedRangeMps: speedRange(drawable),
          ),
        ),
        if (inspected != null)
          Positioned(
            right: 12,
            bottom: 12,
            child: TrackPointInfoCard(
              point: inspected.point,
              speedMps: inspected.speedMps,
              onDismiss: () => setState(() => _inspected = null),
            ),
          ),
      ],
    );
  }

  /// Start and end pins, plus one pin per dive logged during this track.
  ///
  /// Keys live on the marker CHILD via KeyedSubtree, never on the Marker
  /// itself: flutter_map reuses Marker.key for every repeated world copy it
  /// renders at low zoom, which would make those copies duplicate-keyed
  /// siblings in the layer's Stack.
  List<Marker> _markers(BuildContext context, List<GpsTrackPoint> points) {
    final scheme = Theme.of(context).colorScheme;
    final dives = ref.watch(divesOnTrackProvider(trackId)).value ?? const [];

    return [
      Marker(
        point: LatLng(points.first.latitude, points.first.longitude),
        width: 24,
        height: 24,
        child: KeyedSubtree(
          key: const ValueKey('track-start-marker'),
          child: _pin(scheme, Icons.play_arrow, scheme.tertiary),
        ),
      ),
      Marker(
        point: LatLng(points.last.latitude, points.last.longitude),
        width: 24,
        height: 24,
        child: KeyedSubtree(
          key: const ValueKey('track-end-marker'),
          child: _pin(scheme, Icons.stop, scheme.outline),
        ),
      ),
      for (final dive in dives)
        if (dive.entryLocation != null)
          Marker(
            point: LatLng(
              dive.entryLocation!.latitude,
              dive.entryLocation!.longitude,
            ),
            width: 32,
            height: 32,
            child: KeyedSubtree(
              key: ValueKey('track-dive-marker-${dive.id}'),
              child: GestureDetector(
                onTap: () => context.push('/dives/${dive.id}'),
                child: _pin(scheme, Icons.scuba_diving, scheme.primary),
              ),
            ),
          ),
    ];
  }

  Widget _pin(ColorScheme scheme, IconData icon, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}
