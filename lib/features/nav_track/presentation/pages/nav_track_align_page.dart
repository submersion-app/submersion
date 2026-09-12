import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_depth_overlay_layer.dart';
import 'package:submersion/features/bathymetry/presentation/depth_overlay_toggle_button.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_terrain_check.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the crosshair-and-pan flow is currently placing, or nothing.
enum _Placing { none, start, end }

/// Cumulative distance per point, in metres, from the route's own first
/// sample -- presentation-local wrapper because the trust slider is the
/// only reader that needs it purely as a distance axis.
///
/// Delegates to [NavTrackCorrector.cumulativeDistances] instead of
/// recomputing geometric path length here: on an ENC log the device's own
/// `distance` channel and the 2D path length can disagree (a route that
/// loops back near itself keeps accumulating device distance from the
/// speed log while its geometric path length barely grows), and the
/// corrector itself prefers the device channel when it is present and
/// monotone (see [NavTrackCorrector.apply]). Recomputing path length
/// independently here would let the slider's trusted metres, cutoff
/// marker and duration point at a different sample than the correction
/// actually freezes.
///
/// Callers that feed this the trust slider's axis must first truncate
/// [points] to the active range
/// ([NavTrackCorrector.activeRangeStartIndex]..[NavTrackCorrector.activeRangeEndIndex]):
/// passing the whole raw recording would let a GPS-fix event's jump and
/// post-surfacing wobble (or a pre-dive calibration) dominate the total,
/// so the slider's "trusted up to" position would disagree with where
/// [NavTrackCorrector.apply] actually freezes the route -- the prefix
/// would look like it keeps moving as the diver drags the slider, when
/// the correction itself has already stopped touching it.
List<double> cumulativeDistances(List<NavTrackPoint> points) =>
    NavTrackCorrector.cumulativeDistances(points);

/// The corrected points of the ACTIVE dead-reckoned range only -- up to
/// [NavTrackCorrector.activeRangeEndIndex] -- for the terrain check and its
/// conflict-dot overlay. A GPS-fixed/out-of-water tail (a device sitting on
/// a car dashboard, say) is not part of the diver's swim path and must not
/// be checked against the seafloor at all: including it would inflate the
/// "N points on land / below the seafloor" readout with samples that have
/// nothing to do with where the route actually sits, the same "whole raw
/// recording" mistake the 3D ribbon, the 2D layer and the summary
/// statistics elsewhere in this module already avoid.
List<CorrectedNavTrackPoint> _activeCorrectedPoints(
  List<NavTrackPoint> points,
  NavTrackCorrection correction,
) {
  final activeStart = NavTrackCorrector.activeRangeStartIndex(points);
  final activeEnd = NavTrackCorrector.activeRangeEndIndex(points);
  final corrected = NavTrackCorrector.apply(points, correction);
  return corrected.sublist(
    activeStart.clamp(0, corrected.length),
    (activeEnd + 1).clamp(0, corrected.length),
  );
}

/// The index of the first point whose cumulative distance reaches
/// [trustedDistance] -- the point the trust slider's cutoff marker sits on
/// -- or the last index when none does (the whole route is within the
/// trusted range). Shared by the trust readout's duration and the map
/// marker so the two never disagree about which sample the slider points
/// at.
int trustCutoffIndex(List<double> cumulative, double trustedDistance) {
  for (var i = 0; i < cumulative.length; i++) {
    if (cumulative[i] >= trustedDistance) return i;
  }
  return cumulative.isEmpty ? 0 : cumulative.length - 1;
}

/// The alignment page (spec 2026-09-10-underwater-nav-track-design.md, "The
/// alignment page"): start point, end point, trust slider, rotation and the
/// terrain check, all against a transient in-memory [NavTrackCorrection]
/// that is only written back with "Save".
///
/// Renders the route by constructing a transient [NavTrack] copy carrying
/// the in-progress correction rather than extending [NavTrackPolylineLayer]
/// with a correction-override parameter: the layer already reads everything
/// it needs from a [NavTrack], and building one here keeps that widget
/// untouched.
class NavTrackAlignPage extends ConsumerStatefulWidget {
  const NavTrackAlignPage({super.key, required this.routeId});

  final String routeId;

  @override
  ConsumerState<NavTrackAlignPage> createState() => _NavTrackAlignPageState();
}

class _NavTrackAlignPageState extends ConsumerState<NavTrackAlignPage> {
  final MapController _mapController = MapController();
  Timer? _terrainDebounce;

  bool _initialized = false;
  NavTrackCorrection _correction = const NavTrackCorrection();
  _Placing _placing = _Placing.none;
  NavTrackTerrainCheckResult? _terrainResult;

  /// Bumped every time a new terrain check starts, so a check whose async
  /// bathymetry fetch is still in flight when a NEWER one starts can tell
  /// it has been superseded once it finally resolves, and discard its
  /// result instead of overwriting whatever the newer check already
  /// applied. Cancelling `_terrainDebounce` only stops a check that has not
  /// started yet; it cannot cancel `_runTerrainCheck`'s own already-awaited
  /// `Future`.
  int _terrainCheckGeneration = 0;

  static const Duration _terrainDebounceDuration = Duration(milliseconds: 300);

  @override
  void dispose() {
    _terrainDebounce?.cancel();
    super.dispose();
  }

  void _initFromRoute(NavTrack route) {
    if (_initialized) return;
    _initialized = true;
    var correction = route.correction;
    // Propose "same as start" when the raw recording already ends close to
    // where it started -- only as a starting suggestion, so it never
    // overrides a correction the diver already set on a previous visit.
    if (correction.endMode == NavTrackEndMode.none &&
        route.points.length >= 2 &&
        _rawEndDistanceFromStart(route.points) <= 50) {
      correction = correction.copyWith(endMode: NavTrackEndMode.sameAsStart);
    }
    _correction = correction;
    _scheduleTerrainCheck(route);
  }

  double _rawEndDistanceFromStart(List<NavTrackPoint> points) {
    final first = points.first;
    final last = points.last;
    final dNorth = last.north - first.north;
    final dEast = last.east - first.east;
    return math.sqrt(dNorth * dNorth + dEast * dEast);
  }

  void _updateCorrection(
    NavTrackCorrection Function(NavTrackCorrection) fn,
    NavTrack route,
  ) {
    setState(() => _correction = fn(_correction));
    _scheduleTerrainCheck(route);
  }

  void _scheduleTerrainCheck(NavTrack route) {
    _terrainDebounce?.cancel();
    _terrainDebounce = Timer(
      _terrainDebounceDuration,
      () => _runTerrainCheck(route),
    );
  }

  Future<void> _runTerrainCheck(NavTrack route) async {
    final generation = ++_terrainCheckGeneration;
    final anchor = _correction.anchor;
    if (anchor == null || route.points.length < 2) {
      if (mounted && generation == _terrainCheckGeneration) {
        setState(() => _terrainResult = null);
      }
      return;
    }
    final corrected = _activeCorrectedPoints(route.points, _correction);
    final grid = await ref.read(
      bathymetryGridProvider(BathymetryRepository.quantize(anchor)).future,
    );
    // A newer terrain check may have started (and even already applied its
    // own result) while this one awaited the bathymetry fetch above --
    // cancelling the debounce timer only stops a check that had not yet
    // started, not this one's in-flight Future. Discard silently rather
    // than let a slow, stale fetch clobber a faster, newer result.
    if (!mounted || generation != _terrainCheckGeneration) return;
    if (grid == null) {
      setState(() => _terrainResult = null);
      return;
    }
    setState(
      () => _terrainResult = NavTrackTerrainCheck.run(corrected, anchor, grid),
    );
  }

  /// A transient [NavTrack] carrying [_correction] instead of the persisted
  /// one, for the map layers that read a [NavTrack] directly.
  NavTrack _transientRoute(NavTrack base) => NavTrack(
    id: base.id,
    diveId: base.diveId,
    linkMode: base.linkMode,
    isPrimary: base.isPrimary,
    siteId: base.siteId,
    source: base.source,
    sourceRef: base.sourceRef,
    deviceName: base.deviceName,
    name: base.name,
    equipmentId: base.equipmentId,
    startTime: base.startTime,
    endTime: base.endTime,
    tzOffsetMinutes: base.tzOffsetMinutes,
    timeOffsetSeconds: base.timeOffsetSeconds,
    pointCount: base.pointCount,
    totalDistance: base.totalDistance,
    maxDepth: base.maxDepth,
    maxSpeed: base.maxSpeed,
    avgSpeed: base.avgSpeed,
    anchorLatitude: _correction.anchor?.latitude,
    anchorLongitude: _correction.anchor?.longitude,
    endMode: _correction.endMode,
    endLatitude: _correction.endPoint?.latitude,
    endLongitude: _correction.endPoint?.longitude,
    trustFraction: _correction.trustFraction,
    headingOffsetDeg: _correction.headingOffsetDeg,
    points: base.points,
    createdAt: base.createdAt,
    updatedAt: base.updatedAt,
  );

  Future<void> _persistCorrection(NavTrack route) => ref
      .read(navTrackRepositoryProvider)
      .updateCorrection(route.id, _correction);

  Future<void> _save(NavTrack route) async {
    await _persistCorrection(route);
    if (mounted) context.pop();
  }

  /// Saves the in-progress correction, then opens the 3D view for it.
  ///
  /// The 3D page loads the route fresh from the repository, so without
  /// saving first it would show whatever was last persisted -- not
  /// necessarily what the diver is currently looking at on this page.
  Future<void> _openIn3d(NavTrack route) async {
    await _persistCorrection(route);
    if (!mounted) return;
    context.push('/nav-routes/${route.id}/3d');
  }

  void _startPlacing(_Placing target) => setState(() => _placing = target);

  void _resetCorrection() => setState(() {
    _correction = const NavTrackCorrection();
    _terrainResult = null;
  });

  void _setPointHere(NavTrack route) {
    final center = _mapController.camera.center;
    final point = GeoPoint(center.latitude, center.longitude);
    if (_placing == _Placing.start) {
      _updateCorrection((c) => c.copyWith(anchor: point), route);
    } else if (_placing == _Placing.end) {
      _updateCorrection(
        (c) => c.copyWith(endMode: NavTrackEndMode.point, endPoint: point),
        route,
      );
    }
    setState(() => _placing = _Placing.none);
  }

  void _dragPoint(NavTrack route, bool isStart, Offset delta) {
    final current = isStart ? _correction.anchor : _correction.endPoint;
    if (current == null) return;
    final zoom = _mapController.camera.zoom;
    final metersPerPixel =
        156543.03392 *
        math.cos(current.latitude * math.pi / 180) /
        math.pow(2, zoom);
    final dLon =
        delta.dx * metersPerPixel / metersPerDegreeLongitude(current.latitude);
    final dLat = -delta.dy * metersPerPixel / metersPerDegreeLatitude;
    final moved = GeoPoint(current.latitude + dLat, current.longitude + dLon);
    if (isStart) {
      _updateCorrection((c) => c.copyWith(anchor: moved), route);
    } else {
      _updateCorrection((c) => c.copyWith(endPoint: moved), route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(navTrackByIdProvider(widget.routeId));
    final l10n = context.l10n;
    return routeAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(l10n.navTrack_common_loadError))),
      data: (route) {
        if (route == null) {
          return Scaffold(
            body: Center(child: Text(l10n.navTrack_common_notFound)),
          );
        }
        _initFromRoute(route);
        return _AlignPageBody(state: this, route: route);
      },
    );
  }
}

class _AlignPageBody extends ConsumerWidget {
  const _AlignPageBody({required this.state, required this.route});

  final _NavTrackAlignPageState state;
  final NavTrack route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correction = state._correction;
    final anchor = correction.anchor;
    final transientRoute = state._transientRoute(route);
    final fixEvents = NavTrackSegmenter.classify(route.points).fixEvents;
    final hasFix = fixEvents.isNotEmpty;
    final activeStart = NavTrackCorrector.activeRangeStartIndex(route.points);
    final activeEnd = NavTrackCorrector.activeRangeEndIndex(route.points);
    final cumulative = cumulativeDistances(
      route.points.sublist(activeStart, activeEnd + 1),
    );
    final totalDistance = cumulative.isEmpty ? 0.0 : cumulative.last;
    final trustedDistance = correction.trustFraction * totalDistance;

    final initialCenter = anchor != null
        ? LatLng(anchor.latitude, anchor.longitude)
        : const LatLng(0, 0);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navTrack_align_title),
        actions: [
          IconButton(
            key: const ValueKey('nav-track-align-reset'),
            icon: const Icon(Icons.restore),
            tooltip: l10n.navTrack_align_resetTooltip,
            onPressed: state._resetCorrection,
          ),
          IconButton(
            key: const ValueKey('nav-track-align-3d'),
            icon: const Icon(Icons.view_in_ar),
            tooltip: l10n.navTrack_common_open3dTooltip,
            onPressed: () => state._openIn3d(route),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                TrackpadZoomMap(
                  controller: state._mapController,
                  child: FlutterMap(
                    mapController: state._mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: anchor != null ? 15 : 3,
                    ),
                    children: [
                      submersionTileLayer(ref),
                      if (anchor != null)
                        BathymetryDepthOverlayLayer(location: anchor),
                      NavTrackPolylineLayer(route: transientRoute),
                      if (anchor != null && hasFix)
                        _GpsFixDotsLayer(route: route, anchor: anchor),
                      if (anchor != null && state._terrainResult != null)
                        _ConflictDotsLayer(
                          route: route,
                          anchor: anchor,
                          correction: correction,
                          result: state._terrainResult!,
                        ),
                      if (anchor != null && route.points.length >= 2)
                        _TrustMarkerLayer(
                          route: route,
                          anchor: anchor,
                          correction: correction,
                          activeStart: activeStart,
                          cumulative: cumulative,
                          trustedDistance: trustedDistance,
                        ),
                      if (anchor != null)
                        _DraggableMarker(
                          point: anchor,
                          color: Colors.green,
                          keyValue: 'nav-track-align-start-marker',
                          onDrag: (d) => state._dragPoint(route, true, d),
                        ),
                      if (correction.endMode == NavTrackEndMode.point &&
                          correction.endPoint != null)
                        _DraggableMarker(
                          point: correction.endPoint!,
                          color: Colors.red,
                          keyValue: 'nav-track-align-end-marker',
                          onDrag: (d) => state._dragPoint(route, false, d),
                        ),
                    ],
                  ),
                ),
                if (state._placing != _Placing.none)
                  const IgnorePointer(
                    child: Center(
                      child: Icon(Icons.add, size: 32, color: Colors.black87),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: anchor == null
                      ? const SizedBox.shrink()
                      : DepthOverlayToggleButton(siteLocation: anchor),
                ),
                if (state._placing != _Placing.none)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: FilledButton(
                      key: const ValueKey('nav-track-align-set-here'),
                      onPressed: () => state._setPointHere(route),
                      child: Text(
                        state._placing == _Placing.start
                            ? l10n.navTrack_align_setStartHere
                            : l10n.navTrack_align_setEndHere,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _ControlsPanel(
            state: state,
            route: route,
            correction: correction,
            hasFix: hasFix,
            activeStart: activeStart,
            totalDistance: totalDistance,
            trustedDistance: trustedDistance,
          ),
        ],
      ),
    );
  }
}

class _ControlsPanel extends ConsumerWidget {
  const _ControlsPanel({
    required this.state,
    required this.route,
    required this.correction,
    required this.hasFix,
    required this.activeStart,
    required this.totalDistance,
    required this.trustedDistance,
  });

  final _NavTrackAlignPageState state;
  final NavTrack route;
  final NavTrackCorrection correction;
  final bool hasFix;
  final int activeStart;
  final double totalDistance;
  final double trustedDistance;

  /// The linked dive's entry fix, watched through the existing
  /// `diveProvider` family rather than re-`read` inside a fresh `Future`
  /// handed to a `FutureBuilder` on every build: `_updateCorrection` calls
  /// `setState` on every drag, slider move and rotation tap, so a
  /// per-build `Future` would be recreated (and re-awaited) constantly.
  /// `ref.watch` instead reads the provider's already-cached value and only
  /// rebuilds this widget when the dive itself actually changes.
  GeoPoint? _diveEntryLocation(WidgetRef ref) {
    final diveId = route.diveId;
    if (diveId == null) return null;
    return ref.watch(diveProvider(diveId)).value?.entryLocation;
  }

  GeoPoint? _siteLocation(WidgetRef ref) {
    final siteId = route.siteId;
    if (siteId == null) return null;
    return ref.watch(siteProvider(siteId)).value?.location;
  }

  /// A start suggestion built from the route's own pre-dive GPS fix, when it
  /// has one (item 3: the segmenter detects a fix event anywhere in the
  /// recording, so a jump before the diver ever descends -- not seen in any
  /// fixture so far, but not hardcoded away either -- is classified exactly
  /// like the far more common post-dive one).
  ///
  /// The ENC CSV never carries an absolute coordinate (see the design spec's
  /// "Ground truth" section), so the pre-dive fix's own position -- even
  /// [NavTrackSegmenter.stabilizedFixPosition]'s better estimate of it -- is
  /// still only a local offset from the recording's origin, not a place on
  /// the map. This suggestion is only available at all because a known
  /// absolute location already exists to anchor that offset against (the
  /// linked dive's entry fix, or the site pin): it back-solves the origin's
  /// map position so that, once placed there, the stabilized fix position
  /// itself lands on that known location -- the same reasoning as "the diver
  /// surfaced roughly where the site pin already says", just applied to the
  /// start instead of the end. Ignores the route's own rotation setting
  /// (rarely non-zero this early in alignment); the diver reviews the result
  /// on the map like any other suggestion.
  GeoPoint? _preDiveFixStartSuggestion(WidgetRef ref) {
    final points = route.points;
    if (points.length < 2) return null;
    final segmentation = NavTrackSegmenter.classify(points);
    final firstUnderwaterIndex = segmentation.kinds.indexOf(
      NavTrackSampleKind.underwater,
    );
    NavTrackFixEvent? preDiveFix;
    for (final event in segmentation.fixEvents) {
      if (firstUnderwaterIndex == -1 || event.index < firstUnderwaterIndex) {
        preDiveFix = event;
        break;
      }
    }
    if (preDiveFix == null) return null;

    final reference = _diveEntryLocation(ref) ?? _siteLocation(ref);
    if (reference == null) return null;

    final stabilized = NavTrackSegmenter.stabilizedFixPosition(
      points,
      preDiveFix,
    );
    return offsetToGeoPoint(
      reference,
      east: -stabilized.east,
      north: -stabilized.north,
    );
  }

  int _trustedDurationSeconds() {
    if (route.points.isEmpty || totalDistance <= 0) return 0;
    final activeEnd = NavTrackCorrector.activeRangeEndIndex(route.points);
    final cumulative = cumulativeDistances(
      route.points.sublist(activeStart, activeEnd + 1),
    );
    final relativeIndex = trustCutoffIndex(cumulative, trustedDistance);
    final index = activeStart + relativeIndex;
    return route.points[index].timestamp - route.points[activeStart].timestamp;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustedMinutes = (_trustedDurationSeconds() / 60).round();
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.navTrack_align_startLabel),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton.tonal(
                      key: const ValueKey('nav-track-align-place-start'),
                      onPressed: () => state._startPlacing(_Placing.start),
                      child: Text(l10n.navTrack_align_setStartOnMap),
                    ),
                    if (_diveEntryLocation(ref) case final location?)
                      ActionChip(
                        key: const ValueKey('nav-track-align-from-dive-entry'),
                        label: Text(l10n.navTrack_align_fromDiveEntry),
                        onPressed: () => state._updateCorrection(
                          (c) => c.copyWith(anchor: location),
                          route,
                        ),
                      ),
                    if (_siteLocation(ref) case final location?)
                      ActionChip(
                        key: const ValueKey('nav-track-align-from-site'),
                        label: Text(l10n.navTrack_align_fromSite),
                        onPressed: () => state._updateCorrection(
                          (c) => c.copyWith(anchor: location),
                          route,
                        ),
                      ),
                    if (_preDiveFixStartSuggestion(ref) case final location?)
                      ActionChip(
                        key: const ValueKey('nav-track-align-from-gps'),
                        label: Text(l10n.navTrack_align_fromGps),
                        onPressed: () => state._updateCorrection(
                          (c) => c.copyWith(anchor: location),
                          route,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.navTrack_align_endLabel),
                const SizedBox(height: 4),
                DropdownButton<NavTrackEndMode>(
                  key: const ValueKey('nav-track-align-end-mode'),
                  value: correction.endMode,
                  items: [
                    DropdownMenuItem(
                      value: NavTrackEndMode.none,
                      child: Text(l10n.navTrack_align_endMode_none),
                    ),
                    DropdownMenuItem(
                      value: NavTrackEndMode.sameAsStart,
                      child: Text(l10n.navTrack_align_endMode_sameAsStart),
                    ),
                    DropdownMenuItem(
                      value: NavTrackEndMode.point,
                      child: Text(l10n.navTrack_align_endMode_point),
                    ),
                    if (hasFix)
                      DropdownMenuItem(
                        value: NavTrackEndMode.gpsFix,
                        child: Text(l10n.navTrack_align_endMode_gpsFix),
                      ),
                  ],
                  onChanged: (mode) {
                    if (mode == null) return;
                    if (mode == NavTrackEndMode.point) {
                      state._startPlacing(_Placing.end);
                    }
                    state._updateCorrection(
                      (c) => c.copyWith(endMode: mode),
                      route,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.navTrack_align_trustSummary(
                trustedDistance.toStringAsFixed(0),
                trustedMinutes,
              ),
            ),
            Slider(
              key: const ValueKey('nav-track-align-trust-slider'),
              value: correction.trustFraction.clamp(0.0, 1.0),
              onChanged: totalDistance <= 0
                  ? null
                  : (value) => state._updateCorrection(
                      (c) => c.copyWith(trustFraction: value),
                      route,
                    ),
            ),
            _RotationControl(
              headingOffsetDeg: correction.headingOffsetDeg,
              onChanged: (value) => state._updateCorrection(
                (c) => c.copyWith(headingOffsetDeg: value),
                route,
              ),
            ),
            if (state._terrainResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  key: const ValueKey('nav-track-align-terrain-summary'),
                  state._terrainResult!.summaryLine(l10n),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  key: const ValueKey('nav-track-align-cancel'),
                  onPressed: () => context.pop(),
                  child: Text(l10n.navTrack_common_cancel),
                ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('nav-track-align-save'),
                  onPressed: () => state._save(route),
                  child: Text(l10n.navTrack_common_save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The rotation control: the existing +/- stepper (0.5 degree steps)
/// alongside a directly editable numeric field, so a diver who knows the
/// exact declination correction they want does not have to click a button
/// dozens of times. Values are clamped to [_min, _max] -- the same range a
/// diver could reach one 0.5-degree step at a time is unbounded in
/// principle, but a rotation outside +/-180 degrees is never meaningful
/// (it is equivalent to a smaller rotation the other way), so that is the
/// sensible bound for typed input.
class _RotationControl extends StatefulWidget {
  const _RotationControl({
    required this.headingOffsetDeg,
    required this.onChanged,
  });

  final double headingOffsetDeg;
  final ValueChanged<double> onChanged;

  @override
  State<_RotationControl> createState() => _RotationControlState();
}

class _RotationControlState extends State<_RotationControl> {
  static const double _min = -180;
  static const double _max = 180;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.headingOffsetDeg));
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _RotationControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-seed only when the stored value actually moved (a stepper tap, a
    // reset, or this field's own commit) and the diver isn't mid-edit --
    // otherwise every keystroke elsewhere on the page would overwrite what
    // they just typed.
    if (!_focusNode.hasFocus &&
        oldWidget.headingOffsetDeg != widget.headingOffsetDeg) {
      _controller.text = _format(widget.headingOffsetDeg);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  static String _format(double value) => value.toStringAsFixed(1);

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  /// Parses the field, clamps it, and reports it -- or, when the text is
  /// not a valid number, leaves [widget.headingOffsetDeg] unchanged and
  /// restores the field to it rather than crashing or silently zeroing it.
  void _commit() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || !parsed.isFinite) {
      _controller.text = _format(widget.headingOffsetDeg);
      return;
    }
    final clamped = parsed.clamp(_min, _max);
    _controller.text = _format(clamped);
    if (clamped != widget.headingOffsetDeg) widget.onChanged(clamped);
  }

  void _step(double delta) {
    final next = (widget.headingOffsetDeg + delta).clamp(_min, _max);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Text(l10n.navTrack_align_rotationLabel),
        IconButton(
          key: const ValueKey('nav-track-align-rotate-down'),
          icon: const Icon(Icons.remove),
          onPressed: () => _step(-0.5),
        ),
        SizedBox(
          width: 80,
          child: TextField(
            key: const ValueKey('nav-track-align-rotation-field'),
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(suffixText: '°', isDense: true),
            onTapOutside: (_) => _focusNode.unfocus(),
            onEditingComplete: _focusNode.unfocus,
            onSubmitted: (_) => _focusNode.unfocus(),
          ),
        ),
        IconButton(
          key: const ValueKey('nav-track-align-rotate-up'),
          icon: const Icon(Icons.add),
          onPressed: () => _step(0.5),
        ),
      ],
    );
  }
}

/// A correction-target marker that reports pixel-delta drags. Fine
/// adjustment uses screen-pixel deltas converted to degrees via the local
/// Web Mercator metres-per-pixel formula rather than any flutter_map
/// internal API, so it stays independent of the package's camera
/// implementation.
///
/// Uses a raw [Listener] rather than [GestureDetector]'s `onPanUpdate`: a
/// marker sits on top of `FlutterMap`'s own pan-to-move-the-map gesture, and
/// a plain [GestureDetector] loses the gesture arena to it almost every
/// time, so the marker looked draggable but silently never moved (the drag
/// panned the map underneath it instead) -- easy to miss by eye since a
/// marker pinned to a lat/lon does not visibly detach from the map while
/// the whole view pans with it. [Listener] receives every routed pointer
/// event directly, independent of which [GestureRecognizer] wins the arena
/// for the same pointer, so the marker now actually moves every time.
class _DraggableMarker extends StatelessWidget {
  const _DraggableMarker({
    required this.point,
    required this.color,
    required this.keyValue,
    required this.onDrag,
  });

  final GeoPoint point;
  final Color color;
  final String keyValue;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(point.latitude, point.longitude),
          width: 36,
          height: 36,
          child: Listener(
            key: ValueKey(keyValue),
            behavior: HitTestBehavior.opaque,
            onPointerMove: (event) => onDrag(event.delta),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Marks the point on the route where the trust slider's cutoff sits: the
/// sample whose cumulative distance first reaches `trustFraction *
/// totalDistance` (design spec "The alignment page": "the trust point
/// marked on the route"). Rendered as a diamond, distinct from the green
/// start and red end glyphs, and moves live as the slider is dragged since
/// it reads straight from the in-progress [correction].
class _TrustMarkerLayer extends StatelessWidget {
  const _TrustMarkerLayer({
    required this.route,
    required this.anchor,
    required this.correction,
    required this.activeStart,
    required this.cumulative,
    required this.trustedDistance,
  });

  final NavTrack route;
  final GeoPoint anchor;
  final NavTrackCorrection correction;
  final int activeStart;
  final List<double> cumulative;
  final double trustedDistance;

  @override
  Widget build(BuildContext context) {
    final corrected = NavTrackCorrector.apply(route.points, correction);
    final relativeIndex = trustCutoffIndex(cumulative, trustedDistance);
    final index = activeStart + relativeIndex;
    if (index >= corrected.length) return const SizedBox.shrink();
    final p = corrected[index];
    final geo = offsetToGeoPoint(anchor, east: p.east, north: p.north);
    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(geo.latitude, geo.longitude),
          width: 20,
          height: 20,
          child: Tooltip(
            message: context.l10n.navTrack_align_trustSummary(
              trustedDistance.toStringAsFixed(0),
              ((route.points[index].timestamp -
                          route.points[activeStart].timestamp) /
                      60)
                  .round(),
            ),
            child: const _TrustGlyph(
              key: ValueKey('nav-track-align-trust-marker'),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small orange diamond -- visually distinct from the round green start
/// and red end glyphs -- marking the trust slider's cutoff point.
class _TrustGlyph extends StatelessWidget {
  const _TrustGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}

/// Renders the device's own GPS-fixed samples as yellow dots.
///
/// Deliberately built from the RAW `route.points`, never from
/// `NavTrackCorrector.apply`: a `gpsFixed` sample is the console's own
/// GPS-derived position (see the design spec, "Segments and GPS fixes"),
/// already the truth the dead-reckoned path is being corrected *against*,
/// not part of the path being corrected. Rotating it by `headingOffsetDeg`
/// or shifting it by the trust/end-point rubber band would apply a
/// correction for the console's dead-reckoning error to a position that
/// never went through dead reckoning in the first place. The dot only ever
/// moves when the anchor itself moves, since it is still expressed as a
/// local (north, east) offset from the recording's own origin.
class _GpsFixDotsLayer extends StatelessWidget {
  const _GpsFixDotsLayer({required this.route, required this.anchor});

  final NavTrack route;
  final GeoPoint anchor;

  @override
  Widget build(BuildContext context) {
    final kinds = NavTrackSegmenter.classify(route.points).kinds;
    final points = route.points;
    final markers = <Marker>[
      for (var i = 0; i < points.length; i++)
        if (kinds[i] == NavTrackSampleKind.gpsFixed)
          Marker(
            point: LatLng(
              offsetToGeoPoint(
                anchor,
                east: points[i].east,
                north: points[i].north,
              ).latitude,
              offsetToGeoPoint(
                anchor,
                east: points[i].east,
                north: points[i].north,
              ).longitude,
            ),
            width: 6,
            height: 6,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ),
    ];
    return MarkerLayer(markers: markers);
  }
}

class _ConflictDotsLayer extends StatelessWidget {
  const _ConflictDotsLayer({
    required this.route,
    required this.anchor,
    required this.correction,
    required this.result,
  });

  final NavTrack route;
  final GeoPoint anchor;
  final NavTrackCorrection correction;
  final NavTrackTerrainCheckResult result;

  @override
  Widget build(BuildContext context) {
    // Must use the same active-range truncation _runTerrainCheck used to
    // produce [result], so its indices land on the same points here.
    final corrected = _activeCorrectedPoints(route.points, correction);
    final conflicts = result.conflictingIndices;
    final markers = <Marker>[
      for (final i in conflicts)
        if (i < corrected.length)
          Marker(
            point: LatLng(
              offsetToGeoPoint(
                anchor,
                east: corrected[i].east,
                north: corrected[i].north,
              ).latitude,
              offsetToGeoPoint(
                anchor,
                east: corrected[i].east,
                north: corrected[i].north,
              ).longitude,
            ),
            width: 8,
            height: 8,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
    ];
    return MarkerLayer(markers: markers);
  }
}
