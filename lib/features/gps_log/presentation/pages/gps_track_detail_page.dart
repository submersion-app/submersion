import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_edit_save_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/editing/gps_track_card_ids.dart';
import 'package:submersion/features/gps_log/presentation/editing/gps_track_edit_cards.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_camera.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_color_legend.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_point_info_card.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_stats_header.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_timeline_scrubber.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/widgets/delete_track_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

part 'gps_track_detail_page_editing.dart';

/// Full-screen map of one recorded GPS surface track. It opens locked and edits
/// in place (issue #4527): its name and trim are held in one sitting and
/// written by one Save.
class GpsTrackDetailPage extends ConsumerStatefulWidget {
  const GpsTrackDetailPage({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<GpsTrackDetailPage> createState() => _GpsTrackDetailPageState();
}

/// Which overflow-menu entry was chosen.
enum _TrackAction { shareGpx, saveGpx, shareKml, saveKml, split, delete }

/// Which editing affordance the detail page is showing: the split panel,
/// or none (a trim is the Trim card's).
enum TrackEditMode { none, split }

/// Active editing mode on the track detail page.
///
/// autoDispose so leaving the page (by any route, not just Cancel) resets it.
/// A plain StateProvider carried trim mode onto the NEXT track opened, where
/// Apply would then act on a track the user never meant to edit.
final trackEditModeProvider = StateProvider.autoDispose<TrackEditMode>(
  (ref) => TrackEditMode.none,
);

class _GpsTrackDetailPageState extends ConsumerState<GpsTrackDetailPage>
    with
        RecordEditHost<GpsTrackDetailPage, GpsTrack>,
        _GpsTrackDetailPageEditing {
  final MapController _mapController = MapController();
  final _log = LoggerService.forClass(GpsTrackDetailPage);

  /// The split point the scrubber shows, applied only when the diver
  /// confirms.
  int? _pendingStartMs;

  /// The fixes inside a trim, kept while the track's fixes and the trim
  /// stay the same: a sitting rebuilds the page on every change, and a new
  /// list each time would refit the map and walk every fix again.
  ({List<GpsTrackPoint> of, int? start, int? end, List<GpsTrackPoint> points})?
  _effective;

  /// The statistics header as last built, kept while its fixes and dive
  /// count stay the same, so a rebuild does not walk every fix again.
  TrackStatsHeader? _stats;

  List<GpsTrackPoint> _effectivePointsOf(GpsTrack track) {
    final kept = _effective;
    if (kept != null &&
        identical(kept.of, track.points) &&
        kept.start == track.trimStartTime &&
        kept.end == track.trimEndTime) {
      return kept.points;
    }
    final points = track.effectivePoints;
    _effective = (
      of: track.points,
      start: track.trimStartTime,
      end: track.trimEndTime,
      points: points,
    );
    return points;
  }

  TrackStatsHeader _statsHeader(List<GpsTrackPoint> points, int diveCount) {
    final kept = _stats;
    if (kept != null &&
        identical(kept.points, points) &&
        kept.diveCount == diveCount) {
      return kept;
    }
    return _stats = TrackStatsHeader(points: points, diveCount: diveCount);
  }

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  Future<void> _onMenu(_TrackAction action, GpsTrack track) async {
    // Seed the split point to what the scrubber will visibly show, so
    // confirming without dragging does exactly what the screen depicts.
    final points = track.effectivePoints;
    final spanStart = points.isEmpty ? null : points.first.timestamp * 1000;
    final spanEnd = points.isEmpty ? null : points.last.timestamp * 1000;

    switch (action) {
      case _TrackAction.split:
        // Matches TrackTimelineScrubber's initial single-handle position.
        _pendingStartMs = (spanStart == null || spanEnd == null)
            ? null
            : spanStart + (spanEnd - spanStart) ~/ 2;
        ref.read(trackEditModeProvider.notifier).state = TrackEditMode.split;
      case _TrackAction.delete:
        await _runOperation(() => _deleteTrack(track));
      default:
        await _export(action, track);
    }
  }

  Future<void> _applySplit(GpsTrack track) async {
    final at = _pendingStartMs;
    if (at == null) return;
    await _runOperation(() => _splitTrack(track, at));
  }

  /// The split controls, shown only while splitting.
  Widget _buildEditPanel(BuildContext context, GpsTrack track) {
    final mode = ref.watch(trackEditModeProvider);
    if (mode == TrackEditMode.none) return const SizedBox.shrink();
    // Only while the panel shows: the walk over every fix is not free.
    final points = track.effectivePoints;
    if (points.length < 2) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final startMs = points.first.timestamp * 1000;
    final endMs = points.last.timestamp * 1000;

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
              mode: TrackScrubberMode.single,
              onChanged: (s, _) => _pendingStartMs = s,
            ),
            const SizedBox(height: 4),
            // A split cannot be undone, so it warns.
            Text(
              l10n.gpsTrack_edit_splitWarning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
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
                  onPressed: () => _applySplit(track),
                  child: Text(l10n.gpsTrack_edit_confirmSplit),
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

  /// The page's top bar while locked: the title, the lock (once the track
  /// has been read), the menu, and the colour mode below.
  PreferredSizeWidget _lockedBar(GpsTrack? track) => AppBar(
    title: Text(context.l10n.gpsTrack_detail_title),
    actions: [
      if (track != null) lockButton(track),
      if (track != null) _menu(track),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(52),
      child: Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: _ColorModeSelector(),
      ),
    ),
  );

  /// The overflow menu: History, the exports, and what changes the track.
  /// The name and trim are cards, so Trim and Reset trim are not here.
  Widget _menu(GpsTrack track) {
    final l10n = context.l10n;
    return PopupMenuButton<_TrackAction>(
      key: const ValueKey('gps-track-overflow'),
      tooltip: l10n.gpsTrack_action_export,
      onSelected: (action) => _onMenu(action, track),
      itemBuilder: (context) => [
        changeLogHistoryMenuItem(
          context,
          rootTable: 'gps_tracks',
          rootId: track.id,
        ),
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
        // Split and Delete: whole-record operations, under the lock.
        ..._operationItems(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trackAsync = ref.watch(gpsTrackDetailProvider(widget.trackId));
    followStored(gpsTrackDetailProvider(widget.trackId));
    final stored = trackAsync.value;

    if (stored != null) {
      final shown = shownRecord(stored);
      return editScaffold(
        record: stored,
        shown: shown,
        lockedBar: _lockedBar(shown),
        unlockedActions: [_menu(shown)],
        content: _content(stored, shown),
      );
    }

    return Scaffold(
      appBar: _lockedBar(stored),
      body: trackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // A corrupt or undecodable blob must not crash the page. Surface it
        // as a readable message; deletion is offered from the list.
        error: (_, _) => Center(child: Text(l10n.gpsTrack_detail_unreadable)),
        data: (_) => Center(child: Text(l10n.gpsTrack_detail_notFound)),
      ),
    );
  }

  /// The page under its bar: the name and trim cards where the page edits
  /// in place, the statistics, the split panel and the map, for [shown]
  /// (the track with the sitting's changes, or as [stored]).
  Widget _content(GpsTrack stored, GpsTrack shown) {
    final l10n = context.l10n;
    final sitting = isSittingOpen;
    final points = _effectivePointsOf(shown);
    if (points.length < 2) {
      final noPoints = Center(child: Text(l10n.gpsTrack_detail_noPoints));
      // Too few fixes to draw, held trim or not: the name can still be
      // given, and a held trim changed back while the track has the fixes.
      return Column(
        children: [
          _headerBlock(shown),
          if (sitting && shown.points.length >= 2) _trimCard(shown),
          Expanded(child: noPoints),
        ],
      );
    }
    final drawable = points;
    final trimHeld =
        sitting &&
        (maybeEditController?.session?.changedCardIds.contains(
              GpsTrackCardId.trim.name,
            ) ??
            false);
    final dives = trimHeld
        ? divesCoveredBy(shown, ref.watch(divesProvider).value ?? const [])
        : ref.watch(divesOnTrackProvider(widget.trackId)).value ??
              const <Dive>[];
    return Column(
      children: [
        _headerBlock(shown),
        _calculated(_statsHeader(drawable, dives.length)),
        _trimCard(shown),
        _buildEditPanel(context, stored),
        Expanded(
          child: _TrackMap(
            trackId: widget.trackId,
            fallbackPoints: drawable,
            heldPoints: trimHeld ? drawable : null,
            dives: dives,
            controller: _mapController,
          ),
        ),
      ],
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
    required this.dives,
    required this.controller,
    this.heldPoints,
  });

  final String trackId;
  final List<GpsTrackPoint> fallbackPoints;

  /// The dives logged during the track, pinned on the map.
  final List<Dive> dives;
  final MapController controller;

  /// The track as a sitting holds it while its trim is changed (issue
  /// #4527): drawn in place of the cached geometry, which follows storage.
  final List<GpsTrackPoint>? heldPoints;

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
    final held = widget.heldPoints;
    final points =
        held ??
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
                // The zoom range and pole stop every other map has (#3664).
                minZoom: 2.0,
                maxZoom: 18.0,
                interactionOptions: rotatableMapInteraction,
                cameraConstraint: worldMapCameraConstraint,
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
                Positioned(
                  top: 8,
                  right: 8,
                  child: MapCornerControls(controller: controller),
                ),
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
    final dives = widget.dives;

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
