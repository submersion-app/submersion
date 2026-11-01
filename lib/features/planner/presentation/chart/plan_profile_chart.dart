import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_backdrop_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_empty_state.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_edit_controller.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_overlay_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_issue_marker_layer.dart';
import 'package:submersion/features/planner/presentation/chart/plan_scrub_readout.dart';
import 'package:submersion/features/planner/presentation/chart/plan_waypoint_menu.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_issue_marker_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_result_status.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Precision Instrument plan chart: three painter layers split by repaint
/// frequency (backdrop / series / overlay), a scrub readout, waypoint handles,
/// and full on-chart editing (drag, double-click add, gas menu, keyboard).
class PlanProfileChart extends ConsumerStatefulWidget {
  const PlanProfileChart({super.key});

  @override
  ConsumerState<PlanProfileChart> createState() => _PlanProfileChartState();
}

class _PlanProfileChartState extends ConsumerState<PlanProfileChart> {
  final _focusNode = FocusNode();
  int? _dragVertex;

  /// The segment under the drag, so a plan edited mid-drag (a segment
  /// removed before it, or the plan replaced) never redirects the drag to
  /// whichever waypoint now sits at the old index.
  String? _dragSegmentId;

  /// Axis extents captured when a waypoint drag starts and held until it
  /// ends. Mapping the pointer through axes that rescale as the plan grows
  /// turned each small move into a large jump in dive time (issue #3113),
  /// so both display and input use these until release, then refit.
  ({double time, double depth})? _frozenAxes;
  int? _hoverVertex;
  Offset? _downPosition;
  bool _moved = false;
  Duration? _lastTapAt;
  Offset? _lastTapPosition;
  var _idCounter = 0;

  /// Touch has no right button, so holding a finger still on a waypoint
  /// opens its menu instead (issue #3564).
  Timer? _longPressTimer;

  /// Set when a press already did its job (a right-click, or a long-press
  /// that opened the menu), so its pointer-up is not also read as a tap.
  bool _pressHandled = false;

  /// The warning marker under the mouse, and the one a press began on
  /// (#3738). A press on a marker is never a scrub, a selection or half of
  /// a double-tap. On a marker that sits on a waypoint, the press picks the
  /// marker only if it ends where it began: a drag moves the waypoint and a
  /// long-press opens its menu.
  int? _hoverMarker;
  int? _markerPress;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  String _newId() =>
      'seg_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  List<PlanSegment> get _orderedSegments {
    final segments = List<PlanSegment>.from(
      ref.read(divePlanNotifierProvider).segments,
    )..sort((a, b) => a.order.compareTo(b.order));
    return segments;
  }

  void _scrubTo(PlanChartGeometry geometry, Offset local) {
    ref.read(scrubTimeProvider.notifier).state = geometry.timeAtDx(local.dx);
  }

  void _clearScrub() => ref.read(scrubTimeProvider.notifier).state = null;

  /// Picks out [placed]'s warnings on the chart and in the warnings list,
  /// scrolling the list to them, or clears them when they are already
  /// picked.
  void _toggleMarker(PlacedIssueMarker placed) {
    final highlighted = ref.read(highlightedPlanIssuesProvider.notifier);
    final keys = placed.marker.keys;
    if (setEquals(highlighted.state, keys)) {
      highlighted.state = const {};
      return;
    }
    highlighted.state = keys;
    ref.read(planIssueRevealRequestProvider.notifier).state++;
  }

  void _applyDrag(PlanChartGeometry geometry, Offset local) {
    final dragId = _dragSegmentId;
    if (dragId == null) return;
    final ordered = _orderedSegments;
    final vertexIndex = ordered.indexWhere((s) => s.id == dragId);
    if (vertexIndex < 0) {
      // The dragged waypoint is gone: end the drag instead of editing
      // another one.
      _dragVertex = null;
      _dragSegmentId = null;
      return;
    }
    _dragVertex = vertexIndex;
    final result = dragVertex(
      ordered: ordered,
      vertexIndex: vertexIndex,
      newDepthMeters: geometry.dragDepthAtDy(local.dy),
      newTimeSeconds: geometry.dragTimeAtDx(local.dx),
      depthUnitScale: geometry.depthUnitScale,
    );
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    for (final (id, segment) in result.updates) {
      // Most pointer moves snap to the waypoint it already has; publishing
      // it anyway would re-run the whole deco schedule for nothing.
      if (segment == ordered[vertexIndex]) continue;
      notifier.updateSegment(id, segment);
    }
    ref.read(selectedSegmentIdProvider.notifier).state =
        ordered[vertexIndex].id;
  }

  void _doubleTapAt(PlanChartGeometry geometry, Offset local) {
    final split = splitSegmentAt(
      ordered: _orderedSegments,
      timeSeconds: geometry.timeAtDx(local.dx),
      depthMeters: geometry.depthAtDy(local.dy),
      depthUnitScale: geometry.depthUnitScale,
      idGen: _newId,
    );
    if (split == null) return;
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    if (split.replaceId.isEmpty) {
      notifier.addSegment(split.replacements.single);
    } else {
      notifier.replaceSegment(split.replaceId, split.replacements);
    }
  }

  /// The menu for the waypoint at the end of [segmentId]. It is keyed by
  /// segment, not index, because the plan can change while the menu is open.
  Future<void> _showWaypointMenu(
    BuildContext context,
    String segmentId,
    Offset globalPosition,
  ) async {
    final action = await showWaypointMenu(
      context: context,
      globalPosition: globalPosition,
      tanks: ref.read(divePlanNotifierProvider).tanks,
    );
    if (action == null || !mounted || _readOnly) return;

    switch (action) {
      case RemoveWaypointAction():
        _removeWaypoint(segmentId);
      case SwitchGasAction(:final tank):
        final ordered = _orderedSegments;
        final index = ordered.indexWhere((s) => s.id == segmentId);
        if (index < 0) return;
        // A gas switch at vertex i applies to the FOLLOWING segment; fall
        // back to the vertex's own segment when it is the last one.
        final target = index + 1 < ordered.length
            ? ordered[index + 1]
            : ordered[index];
        ref
            .read(divePlanNotifierProvider.notifier)
            .updateSegment(
              target.id,
              target.copyWith(gasMix: tank.gasMix, tankId: tank.id),
            );
    }
  }

  /// Removes the waypoint at the end of [segmentId], leaving every other
  /// waypoint in place (see [removeVertex]).
  void _removeWaypoint(String segmentId) {
    final ordered = _orderedSegments;
    final index = ordered.indexWhere((s) => s.id == segmentId);
    if (index < 0) return;
    final removal = removeVertex(ordered: ordered, vertexIndex: index);
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    // Update before removing: removal renumbers the orders, and the update
    // carries the next leg's order from before it.
    for (final (id, segment) in removal.updates) {
      notifier.updateSegment(id, segment);
    }
    notifier.removeSegment(removal.removeId);
    final selected = ref.read(selectedSegmentIdProvider.notifier);
    if (selected.state == removal.removeId) selected.state = null;
  }

  KeyEventResult _onKey(KeyEvent event, PlanChartGeometry geometry) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_readOnly) return KeyEventResult.ignored;
    final selectedId = ref.read(selectedSegmentIdProvider);
    if (selectedId == null) return KeyEventResult.ignored;
    final ordered = _orderedSegments;
    final index = ordered.indexWhere((s) => s.id == selectedId);
    if (index < 0) return KeyEventResult.ignored;
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final segment = ordered[index];
    final unitMeters = 1 / geometry.depthUnitScale;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _removeWaypoint(selectedId);
      return KeyEventResult.handled;
    }
    // Depth axis grows downward: ArrowDown deepens.
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final delta = key == LogicalKeyboardKey.arrowDown
          ? unitMeters
          : -unitMeters;
      final result = dragVertex(
        ordered: ordered,
        vertexIndex: index,
        newDepthMeters: segment.targetDepth + delta,
        newTimeSeconds: _endTimeOf(ordered, index),
        depthUnitScale: geometry.depthUnitScale,
      );
      for (final (id, updated) in result.updates) {
        notifier.updateSegment(id, updated);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final delta = key == LogicalKeyboardKey.arrowRight ? 60 : -60;
      final newDuration = (segment.durationSeconds + delta).clamp(
        60,
        6000 * 60,
      );
      notifier.updateSegment(
        selectedId,
        segment.copyWith(durationSeconds: newDuration),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// A DPV mission generates the profile from its route, so the chart only
  /// scrubs it: an edit here would disagree with the route and be replaced
  /// by the next mission edit.
  bool get _readOnly => ref.read(divePlanNotifierProvider).mission != null;

  static double _endTimeOf(List<PlanSegment> ordered, int index) {
    var t = 0.0;
    for (var i = 0; i <= index; i++) {
      t += ordered[i].durationSeconds;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final series = ref.watch(planCanvasSeriesProvider);
    final ghost = ref.watch(contingencyGhostSeriesProvider);
    final sourceDive = ref.watch(sourceDiveOverlaySeriesProvider);
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final palette = PlanChartPalette.of(theme);

    if (series.isEmpty) {
      // The Listener goes with the chart, so a drag in progress never sees
      // its pointer-up; drop it rather than freeze the next plan's axes.
      _cancelLongPress();
      _dragVertex = null;
      _dragSegmentId = null;
      _hoverVertex = null;
      _hoverMarker = null;
      _markerPress = null;
      _frozenAxes = null;
      return PlanChartEmptyState(theme: theme);
    }

    // Axes stretch to cover every drawn series: plan, ghost and the source
    // dive's actual profile.
    var maxTime = series.maxTimeSeconds;
    var maxDepth = series.maxDepth;
    for (final extra in [ghost, sourceDive]) {
      if (extra == null) continue;
      if (extra.maxTimeSeconds > maxTime) maxTime = extra.maxTimeSeconds;
      if (extra.maxDepth > maxDepth) maxDepth = extra.maxDepth;
    }
    final labelStyle =
        theme.textTheme.labelSmall ?? const TextStyle(fontSize: 10);
    final tagStyle = (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );
    final direction = Directionality.of(context);

    final stopTagLabels = [
      for (final marker in series.stopLabels)
        "${units.formatDepth(marker.depth, decimals: 0)} "
            "${marker.durationSeconds ~/ 60}'",
    ];
    final meanDepthLabel = context.l10n.plannerCanvas_chart_meanDepth(
      units.formatDepth(
        PlanChartGeometry.meanDepthMeters(series.profile),
        decimals: 0,
      ),
    );

    final selectedId = ref.watch(selectedSegmentIdProvider);
    final plan = ref.watch(divePlanNotifierProvider);
    // No vertices on a mission profile: no handles, no drag, no gas menu.
    final vertices = plan.mission == null
        ? planVertices(plan.segments)
        : const <PlanVertex>[];

    final issueMarkers = ref.watch(planIssueMarkersProvider);
    final highlightedIssues = ref.watch(highlightedPlanIssuesProvider);

    final frozen = _frozenAxes;
    if (frozen != null) {
      maxTime = frozen.time;
      maxDepth = frozen.depth;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = PlanChartGeometry(
          size: constraints.biggest,
          maxTimeSeconds: maxTime,
          maxDepthMeters: maxDepth,
          depthUnitScale: units.convertDepth(1),
        );

        // On the profile the warnings describe: a previewed contingency's
        // when one is shown, as the warnings list then shows its warnings.
        final placedMarkers = placeIssueMarkers(
          markers: issueMarkers,
          geometry: geometry,
          depthAt: (ghost ?? series).depthAt,
          highlighted: highlightedIssues,
        );
        final hoverMarker = _hoverMarker;
        // A waypoint being dragged hides the warnings, which describe the
        // plan as it was.
        final dragging = _dragVertex != null && _moved;
        int? activeMarker =
            !dragging &&
                hoverMarker != null &&
                hoverMarker < placedMarkers.length
            ? hoverMarker
            : null;
        if (activeMarker == null && !dragging && highlightedIssues.isNotEmpty) {
          final picked = placedMarkers.indexWhere((p) => p.highlighted);
          if (picked >= 0) activeMarker = picked;
        }

        final handleOffsets = [
          for (final v in vertices)
            if (v.draggable) geometry.toPixel(v.timeSeconds, v.depth),
        ];
        final draggable = [
          for (final v in vertices)
            if (v.draggable) v,
        ];
        int? selectedHandleIndex;
        if (selectedId != null) {
          final idx = draggable.indexWhere((v) => v.segmentId == selectedId);
          if (idx >= 0) selectedHandleIndex = idx;
        }
        int? draggableHandleFor(int? vertexIndex) {
          // The plan can change under a stale drag or hover index.
          if (vertexIndex == null || vertexIndex >= vertices.length) {
            return null;
          }
          final id = vertices[vertexIndex].segmentId;
          final idx = draggable.indexWhere((v) => v.segmentId == id);
          return idx >= 0 ? idx : null;
        }

        // Raw pointer handling (not GestureDetector) so tap, double-tap,
        // drag, scrub, and right-click never fight in a gesture arena - the
        // soup of tap + double-tap + pan recognizers swallows single taps.
        void endDrag() {
          _dragVertex = null;
          _dragSegmentId = null;
          if (_frozenAxes != null) setState(() => _frozenAxes = null);
        }

        void onPointerDown(PointerDownEvent event) {
          _focusNode.requestFocus();
          _cancelLongPress();
          _pressHandled = false;
          if (event.buttons & kSecondaryButton != 0 && !_readOnly) {
            // Off a waypoint no menu opens, so the pointer-up still arrives;
            // two quick right-clicks there must not add a waypoint.
            _pressHandled = true;
            final hit = hitTestVertex(
              vertices: vertices,
              geometry: geometry,
              position: event.localPosition,
            );
            if (hit != null) {
              _showWaypointMenu(
                context,
                vertices[hit].segmentId,
                event.position,
              );
            }
            return;
          }
          _downPosition = event.localPosition;
          _moved = false;
          _dragVertex = hitTestVertex(
            vertices: vertices,
            geometry: geometry,
            position: event.localPosition,
            // A fingertip needs the 48 px minimum touch target.
            radius: event.kind == PointerDeviceKind.mouse ? 16 : 24,
          );
          final hit = _dragVertex;
          _dragSegmentId = hit == null ? null : vertices[hit].segmentId;
          _markerPress = hitTestIssueMarker(
            placedMarkers,
            event.localPosition,
            radius: event.kind == PointerDeviceKind.mouse ? 16 : 24,
          );
          if (hit == null) {
            if (_markerPress != null) {
              _clearScrub();
            } else {
              _scrubTo(geometry, event.localPosition);
            }
          } else {
            _frozenAxes = (time: maxTime, depth: maxDepth);
            // A mouse has right-click, and holding its button still on a
            // handle is just a drag that has not moved yet.
            if (event.kind != PointerDeviceKind.mouse && !_readOnly) {
              final segmentId = vertices[hit].segmentId;
              final globalPosition = event.position;
              _longPressTimer = Timer(kLongPressTimeout, () {
                _longPressTimer = null;
                if (!mounted || _dragSegmentId != segmentId) return;
                _pressHandled = true;
                _markerPress = null;
                endDrag();
                _clearScrub();
                Feedback.forLongPress(context);
                _showWaypointMenu(context, segmentId, globalPosition);
              });
            }
          }
        }

        void onPointerMove(PointerMoveEvent event) {
          final down = _downPosition;
          if (down != null &&
              !_moved &&
              (event.localPosition - down).distance > 6) {
            _markerPress = null;
            _cancelLongPress();
            // The warnings go before the waypoint moves. A touch shows them
            // only once it lifts, so a drag never flashes them up.
            setState(() {
              _moved = true;
              if (_dragVertex != null) _hoverMarker = null;
            });
          }
          if (_markerPress != null) return;
          // A touch still inside the slop may yet become a long-press, so
          // finger jitter must not edit the waypoint. The drag maps the
          // absolute position, so nothing is lost once it starts.
          if (_longPressTimer != null) return;
          if (_dragVertex != null) {
            _applyDrag(geometry, event.localPosition);
          } else {
            _scrubTo(geometry, event.localPosition);
          }
        }

        void onPointerUp(PointerUpEvent event) {
          _cancelLongPress();
          final wasDrag = _dragVertex != null;
          final markerTap = _markerPress;
          _markerPress = null;
          endDrag();
          _clearScrub();
          if (markerTap != null && markerTap < placedMarkers.length) {
            _toggleMarker(placedMarkers[markerTap]);
            _downPosition = null;
            _lastTapAt = null;
            _lastTapPosition = null;
            return;
          }
          if (!wasDrag && !_moved && !_pressHandled) {
            // A tap anywhere else lets go of a picked marker.
            ref.read(highlightedPlanIssuesProvider.notifier).state = const {};
          }
          if (wasDrag || _moved || _readOnly || _pressHandled) {
            _pressHandled = false;
            _downPosition = null;
            return;
          }
          // A stationary tap: select immediately. A second tap within the
          // double-tap window adds a waypoint (selecting first is harmless).
          final time = geometry.timeAtDx(event.localPosition.dx);
          ref.read(selectedSegmentIdProvider.notifier).state = segmentIdAtTime(
            _orderedSegments,
            time,
          );
          final now = event.timeStamp;
          final last = _lastTapAt;
          final lastPos = _lastTapPosition;
          if (last != null &&
              lastPos != null &&
              now - last < const Duration(milliseconds: 300) &&
              (event.localPosition - lastPos).distance < 24) {
            _doubleTapAt(geometry, event.localPosition);
            _lastTapAt = null;
            _lastTapPosition = null;
          } else {
            _lastTapAt = now;
            _lastTapPosition = event.localPosition;
          }
          _downPosition = null;
        }

        void onPointerHover(PointerHoverEvent event) {
          final hit = hitTestVertex(
            vertices: vertices,
            geometry: geometry,
            position: event.localPosition,
          );
          if (hit != _hoverVertex) setState(() => _hoverVertex = hit);
          // Within reach of a waypoint, or of a stop the deco schedule
          // added, the line locks onto it so its own time and depth can be
          // read; left where the cursor last was, it stopped short of the
          // waypoint (#3775).
          final lockTime = hit != null
              ? vertices[hit].timeSeconds
              : hitTestProfilePoint(
                  profile: series.profile,
                  geometry: geometry,
                  position: event.localPosition,
                )?.timeSeconds;
          // A warning marker on a waypoint or a deco stop shows its
          // warnings while the line stays locked onto that point (#3738).
          final marker = hitTestIssueMarker(placedMarkers, event.localPosition);
          if (marker != _hoverMarker) setState(() => _hoverMarker = marker);
          if (lockTime != null) {
            ref.read(scrubTimeProvider.notifier).state = lockTime;
          } else if (marker != null) {
            _clearScrub();
          } else {
            _scrubTo(geometry, event.localPosition);
          }
        }

        return Focus(
          focusNode: _focusNode,
          onKeyEvent: (_, event) => _onKey(event, geometry),
          child: MouseRegion(
            onExit: (_) {
              if (_hoverVertex != null || _hoverMarker != null) {
                setState(() {
                  _hoverVertex = null;
                  _hoverMarker = null;
                });
              }
              _clearScrub();
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: onPointerDown,
              onPointerMove: onPointerMove,
              onPointerUp: onPointerUp,
              onPointerCancel: (_) {
                _cancelLongPress();
                _pressHandled = false;
                endDrag();
                _clearScrub();
                _downPosition = null;
                // A cancelled sequence must not pair with the next tap.
                _lastTapAt = null;
                _lastTapPosition = null;
              },
              onPointerHover: onPointerHover,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.backdrop,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: const Key('planChartBackdrop'),
                          painter: PlanChartBackdropPainter(
                            geometry: geometry,
                            palette: palette,
                            ceiling: ghost?.ceiling ?? series.ceiling,
                            depthUnitScale: units.convertDepth(1),
                            depthAxisLabel: units.depthSymbol,
                            timeAxisLabel:
                                context.l10n.divePlanner_label_timeAxis,
                            labelStyle: labelStyle,
                            textDirection: direction,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: RepaintBoundary(
                        // While the axes are frozen the plan can outgrow
                        // them; keep it inside the plot until they refit.
                        child: ClipRect(
                          clipper: _PlotClipper(geometry.plotRect),
                          clipBehavior: frozen == null
                              ? Clip.none
                              : Clip.hardEdge,
                          child: CustomPaint(
                            key: const Key('planChartSeries'),
                            painter: PlanChartSeriesPainter(
                              geometry: geometry,
                              palette: palette,
                              series: series,
                              ghost: ghost,
                              sourceDive: sourceDive,
                              stopTagLabels: stopTagLabels,
                              meanDepthLabel: meanDepthLabel,
                              labelStyle: labelStyle,
                              tagStyle: tagStyle,
                              textDirection: direction,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final scrubTime = ref.watch(scrubTimeProvider);
                          return Stack(
                            children: [
                              Positioned.fill(
                                // A handle dragged past the frozen axes
                                // must not paint over the axis labels or
                                // neighbouring panels. The margin keeps a
                                // handle on the plot edge (a surface
                                // waypoint) whole.
                                child: ClipRect(
                                  clipper: _PlotClipper(
                                    geometry.plotRect.inflate(8),
                                  ),
                                  clipBehavior: frozen == null
                                      ? Clip.none
                                      : Clip.hardEdge,
                                  child: CustomPaint(
                                    key: const Key('planChartOverlay'),
                                    painter: PlanChartOverlayPainter(
                                      geometry: geometry,
                                      palette: palette,
                                      scrubX: scrubTime == null
                                          ? null
                                          : geometry.xFor(scrubTime),
                                      handles: handleOffsets,
                                      activeHandle: draggableHandleFor(
                                        _dragVertex ?? _hoverVertex,
                                      ),
                                      selectedHandle: selectedHandleIndex,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: PlanIssueMarkerLayer(
                                  placed: placedMarkers,
                                  activeIndex: activeMarker,
                                  palette: palette,
                                  units: units,
                                  onActivate: (i) =>
                                      _toggleMarker(placedMarkers[i]),
                                ),
                              ),
                              // The bailout status goes top centre: on a phone
                              // the corners hold the readouts and the bottom
                              // edge holds the chips. In one column with the
                              // scrub readout, which reaches past the centre
                              // on a narrow chart, so it clears the readout at
                              // any text size.
                              Positioned(
                                top: 12,
                                left: 0,
                                right: 0,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 2,
                                  children: [
                                    if (scrubTime != null)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left:
                                                PlanChartGeometry.leftGutter +
                                                4,
                                          ),
                                          child: PlanScrubReadout(
                                            runtimeSeconds: scrubTime,
                                            depthMeters: series.depthAt(
                                              scrubTime,
                                            ),
                                            units: units,
                                            palette: palette,
                                          ),
                                        ),
                                      ),
                                    const PlanChartBailoutStatus(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlotClipper extends CustomClipper<Rect> {
  const _PlotClipper(this.plot);

  final Rect plot;

  @override
  Rect getClip(Size size) => plot;

  @override
  bool shouldReclip(_PlotClipper oldClipper) => oldClipper.plot != plot;
}
