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
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_align_geometry.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_align_map_layers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_align_rotation_control.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the crosshair-and-pan flow is currently placing, or nothing.
enum _Placing { none, start, end }

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
    // Computed once per build and shared by every layer that needs it below
    // -- each drag/slider frame already rebuilds this widget, so applying
    // the correction transform again per layer would repeat the same
    // full-route pass multiple times per frame.
    final corrected = NavTrackCorrector.apply(route.points, correction);
    final activeCorrected = corrected.sublist(
      activeStart.clamp(0, corrected.length),
      (activeEnd + 1).clamp(0, corrected.length),
    );

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
                        NavTrackGpsFixDotsLayer(route: route, anchor: anchor),
                      if (anchor != null && state._terrainResult != null)
                        NavTrackConflictDotsLayer(
                          corrected: activeCorrected,
                          anchor: anchor,
                          result: state._terrainResult!,
                        ),
                      if (anchor != null && route.points.length >= 2)
                        NavTrackTrustMarkerLayer(
                          route: route,
                          corrected: corrected,
                          anchor: anchor,
                          activeStart: activeStart,
                          cumulative: cumulative,
                          trustedDistance: trustedDistance,
                        ),
                      if (anchor != null)
                        NavTrackDraggableMarker(
                          point: anchor,
                          color: Colors.green,
                          keyValue: 'nav-track-align-start-marker',
                          onDrag: (d) => state._dragPoint(route, true, d),
                        ),
                      if (correction.endMode == NavTrackEndMode.point &&
                          correction.endPoint != null)
                        NavTrackDraggableMarker(
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
            NavTrackRotationControl(
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
