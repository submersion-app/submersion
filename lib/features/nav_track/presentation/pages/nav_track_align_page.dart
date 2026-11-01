import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_depth_overlay_layer.dart';
import 'package:submersion/features/bathymetry/presentation/depth_overlay_toggle_button.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';
import 'package:submersion/features/nav_track/domain/nav_track_scale_handle.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_terrain_check.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_align_geometry.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_align_map_layers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_align_rotation_control.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_position_row_controls.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_scale_control.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_scale_handle_layer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

part 'nav_track_align_controls_panel.dart';

/// The body height from which a desktop-width window shows the whole controls
/// panel uncapped. Width alone cannot decide this: a phone in landscape is
/// desktop-width too, with a body shorter than the panel (issue #3994).
const double _uncappedPanelMinBodyHeight = 540;

/// What the crosshair-and-pan flow is currently placing, or nothing.
enum _Placing { none, start, end }

/// The alignment page (spec 2026-09-10-underwater-nav-track-design.md, "The
/// alignment page"): start point, end point, trust slider, rotation, scale and
/// the terrain check, all against a transient in-memory [NavTrackCorrection]
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
  final GlobalKey _mapKey = GlobalKey();

  /// Shared by the controls panel's scroll view and its [Scrollbar]: a scroll
  /// view inherits the PrimaryScrollController on mobile only, so a Scrollbar
  /// without this has no position to follow on desktop.
  final ScrollController _panelScrollController = ScrollController();
  Timer? _terrainDebounce;

  bool _initialized = false;
  bool _framed = false;
  NavTrackCorrection _correction = const NavTrackCorrection();
  _Placing _placing = _Placing.none;
  NavTrackTerrainCheckResult? _terrainResult;

  /// Bumped every time a terrain check is scheduled and again when it
  /// starts, so a check whose async bathymetry fetch is still in flight
  /// when the correction changes can tell it has been superseded once it
  /// finally resolves, and discard its result instead of showing it for a
  /// correction the diver already moved on from. Cancelling
  /// `_terrainDebounce` only stops a check that has not started yet; it
  /// cannot cancel `_runTerrainCheck`'s own already-awaited `Future`.
  int _terrainCheckGeneration = 0;

  static const Duration _terrainDebounceDuration = Duration(milliseconds: 300);

  @override
  void dispose() {
    _terrainDebounce?.cancel();
    _panelScrollController.dispose();
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

  /// How far the dive ends from where it started, over the active range: a
  /// post-surfacing GPS tail (or a pre-dive calibration) says where the
  /// console was on the surface, not whether the dive closed its loop.
  double _rawEndDistanceFromStart(List<NavTrackPoint> points) {
    final range = NavTrackCorrector.activeRange(points);
    final first = points[range.start];
    final last = points[range.end];
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

  /// Like [_updateCorrection], for a suggestion chip or end-mode chip
  /// specifically: also cancels an in-progress crosshair-placement flow.
  ///
  /// Without this, picking a chip while "Start/Ende auf der Karte setzen"
  /// is still awaiting a map tap left the crosshair and the floating "Set
  /// ... here" button on screen; a diver who then tapped that button got
  /// [_setPointHere] silently overwriting the chip's choice with a manual
  /// point at the map's current center, discarding the selection they just
  /// made with no further confirmation (code review).
  void _selectChip(
    NavTrackCorrection Function(NavTrackCorrection) fn,
    NavTrack route,
  ) {
    setState(() {
      _placing = _Placing.none;
      _correction = fn(_correction);
    });
    _scheduleTerrainCheck(route);
  }

  void _scheduleTerrainCheck(NavTrack route) {
    // Superseding here, not only when the next check starts: a fetch still
    // in flight must not apply its result during this debounce either, for
    // a correction the diver has already moved on from.
    _terrainCheckGeneration++;
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
    final corrected = activeCorrectedPoints(route.points, _correction);
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
    context.push(underwaterTrackSeascapeLocation(route.id));
  }

  /// Fits the map to the track, once, when the page opens: close enough on a
  /// small track to keep the scale handle clear of the start marker.
  ///
  /// Driven from `onMapReady` rather than `initialCameraFit`, which reapplies
  /// on a size change. This map resizes whenever the panel below it changes
  /// height, and that must not undo the diver's own pan and zoom.
  void _frameTrack(NavTrack route) {
    if (_framed) return;
    _framed = true;
    final track = route.withCorrection(_correction);
    if (track.anchor == null) return;
    navTrackCamera(
      track,
      padding: const EdgeInsets.all(48),
      // As on the detail map: a tiny track must not fit past what a map style
      // has tiles for.
      maxZoom: 17,
    ).applyTo(_mapController);
  }

  void _startPlacing(_Placing target) => setState(() => _placing = target);

  /// Starts the end-point crosshair flow and sets the end mode to [point]
  /// in one rebuild, instead of two separate `setState` calls for what is a
  /// single user action (pressing "Place end on map").
  void _startPlacingEndPoint(NavTrack route) {
    setState(() {
      _placing = _Placing.end;
      _correction = _correction.copyWith(endMode: NavTrackEndMode.point);
    });
    _scheduleTerrainCheck(route);
  }

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

  void _dragPoint(NavTrack route, bool isStart, GeoPoint moved) {
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
      error: (e, _) => Scaffold(
        body: Center(child: Text(l10n.navTrack_common_trackLoadError)),
      ),
      data: (route) {
        if (route == null) {
          return Scaffold(
            body: Center(child: Text(l10n.navTrack_common_trackNotFound)),
          );
        }
        // The repository hands back an empty points list for a synced blob
        // it cannot decode; everything below needs at least two samples.
        if (route.points.length < 2) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.navTrack_align_title)),
            body: Center(child: Text(l10n.navTrack_common_trackLoadError)),
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
    final transientRoute = route.withCorrection(correction);
    final fixEvents = NavTrackSegmenter.classify(route.points).fixEvents;
    final hasFix = fixEvents.isNotEmpty;
    // Gates the "GPS position at surfacing" end chip specifically: `hasFix`
    // (used below for the map's fix dots) is true for ANY fix event, pre-dive
    // included, but NavTrackEndMode.gpsFix only ever resolves against a
    // post-dive one (NavTrackCorrector._resolveTarget). A recording with only
    // a pre-dive calibration would otherwise show a chip that silently
    // behaves like "no correction" once selected.
    final hasPostDiveFix =
        NavTrackCorrector.postDiveFixEvent(route.points) != null;
    final range = NavTrackCorrector.activeRange(route.points);
    final activeStart = range.start;
    final activeEnd = range.end;
    final cumulative = cumulativeDistances(
      route.points.sublist(activeStart, activeEnd + 1),
    );
    final totalDistance = cumulative.isEmpty ? 0.0 : cumulative.last;
    final trustedDistance = correction.trustFraction * totalDistance;
    final units = ref.watch(unitFormatterProvider);
    // Computed once per build and shared by every layer that needs it below
    // -- each drag/slider frame already rebuilds this widget, so applying
    // the correction transform again per layer would repeat the same
    // full-route pass multiple times per frame.
    final corrected = NavTrackCorrector.apply(route.points, correction);
    final activeCorrected = corrected.sublist(
      activeStart.clamp(0, corrected.length),
      (activeEnd + 1).clamp(0, corrected.length),
    );

    final endPinned = NavTrackCorrector.endIsPinned(route.points, correction);
    final scaleHandle = anchor == null || endPinned
        ? null
        : scaleHandleIndex(route.points, start: activeStart, end: activeEnd);

    final initialCenter = anchor != null
        ? LatLng(anchor.latitude, anchor.longitude)
        : const LatLng(0, 0);
    final l10n = context.l10n;
    // Out here, not in the LayoutBuilder below: it watches providers, and a
    // layout-time builder runs after this element has finished building.
    final tileLayer = submersionTileLayer(ref);

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
            icon: const Icon(Icons.terrain),
            tooltip: l10n.navTrack_common_open3dTooltip,
            onPressed: () => state._openIn3d(route),
          ),
        ],
      ),
      // Capped at a fraction of the body height so a tall controls panel
      // can never squeeze the map below a usable size (issue #3994),
      // mirroring color_adjust_layout.dart's viewer-above/panel-below
      // phone layout. The panel's SingleChildScrollView already shrinks
      // to its content up to this cap (it only fills the cap and scrolls
      // once the content actually exceeds it), so a tablet or a
      // chip-light route whose panel fits in a fraction of this today
      // keeps that same smaller size.
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          key: const ValueKey('nav-track-align-body'),
          children: [
            Expanded(
              child: Stack(
                children: [
                  TrackpadZoomMap(
                    key: state._mapKey,
                    controller: state._mapController,
                    child: FlutterMap(
                      mapController: state._mapController,
                      options: MapOptions(
                        initialCenter: initialCenter,
                        initialZoom: anchor != null ? 15 : 3,
                        // The zoom range, pole stop and pinch handling every
                        // other map has (#3664).
                        minZoom: 2.0,
                        maxZoom: 18.0,
                        onMapReady: () => state._frameTrack(route),
                        interactionOptions: rotatableMapInteraction,
                        cameraConstraint: worldMapCameraConstraint,
                      ),
                      children: [
                        tileLayer,
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
                            trustedDistanceLabel: units.formatDistance(
                              trustedDistance,
                            ),
                          ),
                        if (anchor != null &&
                            scaleHandle != null &&
                            state._placing == _Placing.none)
                          NavTrackScaleHandleLayer(
                            mapKey: state._mapKey,
                            point: offsetToGeoPoint(
                              anchor,
                              east: corrected[scaleHandle].east,
                              north: corrected[scaleHandle].north,
                            ),
                            pivot: offsetToGeoPoint(
                              anchor,
                              east: corrected[activeStart].east,
                              north: corrected[activeStart].north,
                            ),
                            scaleFactor: correction.scaleFactor,
                            onChanged: (value) => state._updateCorrection(
                              (c) => c.copyWith(scaleFactor: value),
                              route,
                            ),
                          ),
                        if (anchor != null)
                          NavTrackDraggableMarker(
                            mapKey: state._mapKey,
                            point: anchor,
                            color: Colors.green,
                            keyValue: 'nav-track-align-start-marker',
                            onDrag: (p) => state._dragPoint(route, true, p),
                          ),
                        if (correction.endMode == NavTrackEndMode.point &&
                            correction.endPoint != null)
                          NavTrackDraggableMarker(
                            mapKey: state._mapKey,
                            point: correction.endPoint!,
                            color: Colors.red,
                            keyValue: 'nav-track-align-end-marker',
                            onDrag: (p) => state._dragPoint(route, false, p),
                          ),
                        const MapAttribution(),
                      ],
                    ),
                  ),
                  if (state._placing != _Placing.none)
                    const IgnorePointer(
                      child: Center(
                        child: Icon(Icons.add, size: 32, color: Colors.black87),
                      ),
                    ),
                  // Map style switcher and reset-to-north compass, with the
                  // depth overlay toggle below them once the track is anchored.
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MapCornerControls(controller: state._mapController),
                        if (anchor != null) ...[
                          const SizedBox(height: 8),
                          DepthOverlayToggleButton(siteLocation: anchor),
                        ],
                      ],
                    ),
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
            ConstrainedBox(
              key: const ValueKey('nav-track-align-controls-panel'),
              // A desktop window with the height to spare shows the whole
              // panel, with Save on screen without scrolling. Everything
              // else is capped, including a wide but short body, where an
              // uncapped panel leaves no map at all.
              constraints: BoxConstraints(
                maxHeight:
                    constraints.maxWidth >= ResponsiveBreakpoints.desktop &&
                        constraints.maxHeight >= _uncappedPanelMinBodyHeight
                    ? double.infinity
                    : constraints.maxHeight * 0.45,
              ),
              child: _ControlsPanel(
                state: state,
                route: route,
                correction: correction,
                hasPostDiveFix: hasPostDiveFix,
                endPinned: endPinned,
                activeStart: activeStart,
                cumulative: cumulative,
                totalDistance: totalDistance,
                trustedDistance: trustedDistance,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
