import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_backdrop_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_edit_controller.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_waypoint_menu.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final palette = PlanChartPalette.of(theme);

    if (series.isEmpty) {
      // The Listener goes with the chart, so a drag in progress never sees
      // its pointer-up; drop it rather than freeze the next plan's axes.
      _cancelLongPress();
      _dragVertex = null;
      _dragSegmentId = null;
      _hoverVertex = null;
      _frozenAxes = null;
      return _EmptyState(theme: theme);
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
          if (hit == null) {
            _scrubTo(geometry, event.localPosition);
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
          if (down != null && (event.localPosition - down).distance > 6) {
            _moved = true;
            _cancelLongPress();
          }
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
          endDrag();
          _clearScrub();
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
          if (lockTime == null) {
            _scrubTo(geometry, event.localPosition);
          } else {
            ref.read(scrubTimeProvider.notifier).state = lockTime;
          }
        }

        return Focus(
          focusNode: _focusNode,
          onKeyEvent: (_, event) => _onKey(event, geometry),
          child: MouseRegion(
            onExit: (_) {
              if (_hoverVertex != null) setState(() => _hoverVertex = null);
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
                              if (scrubTime != null)
                                Positioned(
                                  top: 12,
                                  left: PlanChartGeometry.leftGutter + 4,
                                  child: _ScrubReadout(
                                    runtimeSeconds: scrubTime,
                                    depthMeters: series.depthAt(scrubTime),
                                    units: units,
                                    palette: palette,
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

/// Scrub cursor + waypoint handles layer; repaints per pointer event without
/// touching the series or backdrop layers.
class PlanChartOverlayPainter extends CustomPainter {
  final PlanChartGeometry geometry;
  final PlanChartPalette palette;
  final double? scrubX;
  final List<Offset> handles;
  final int? activeHandle;
  final int? selectedHandle;

  const PlanChartOverlayPainter({
    required this.geometry,
    required this.palette,
    required this.scrubX,
    this.handles = const [],
    this.activeHandle,
    this.selectedHandle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plotRect;
    final x = scrubX;
    if (x != null) {
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = palette.scrubCursor
          ..strokeWidth = 1,
      );
    }

    final fill = Paint()..color = palette.backdrop;
    final stroke = Paint()
      ..color = palette.profileLine
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final selectedFill = Paint()..color = palette.profileLine;
    for (var i = 0; i < handles.length; i++) {
      final active = i == activeHandle;
      final selected = i == selectedHandle;
      final radius = active ? 6.5 : 4.5;
      canvas.drawCircle(handles[i], radius, selected ? selectedFill : fill);
      canvas.drawCircle(handles[i], radius, stroke);
    }
  }

  @override
  bool shouldRepaint(PlanChartOverlayPainter oldDelegate) =>
      oldDelegate.scrubX != scrubX ||
      oldDelegate.geometry != geometry ||
      oldDelegate.palette != palette ||
      oldDelegate.activeHandle != activeHandle ||
      oldDelegate.selectedHandle != selectedHandle ||
      !listEquals(oldDelegate.handles, handles);
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A mission builds its profile from the route, whose card says what is
    // missing; segments and a quick plan (which would end the mission) are
    // not what it needs.
    final missionOn = ref.watch(
      divePlanNotifierProvider.select((s) => s.mission != null),
    );
    // Scrollable so the fixed-height content survives the phone layout's
    // 160 px chart floor instead of overflowing on short viewports.
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              context.l10n.divePlanner_message_noProfile,
              style: theme.textTheme.titleMedium,
            ),
            if (!missionOn) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.divePlanner_message_addSegmentsForProfile,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const SimplePlanDialog(),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: Text(context.l10n.divePlanner_action_quickPlan),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScrubReadout extends ConsumerWidget {
  const _ScrubReadout({
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.units,
    required this.palette,
  });

  final double runtimeSeconds;
  final double depthMeters;
  final UnitFormatter units;
  final PlanChartPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final minutes = (runtimeSeconds / 60).round();
    final outcome = ref.watch(planOutcomeProvider);
    var text = context.l10n.plannerCanvas_scrub_readout(
      minutes.toString(),
      units.formatDepth(depthMeters, decimals: 0),
    );
    // The plan's own remaining time, not a bailout TTS: the schedule the
    // diver is actually following is already fully computed, so the time
    // left is just the plan's total runtime minus how far the scrub point
    // already is into it.
    final remainingSeconds = (outcome.runtimeSeconds - runtimeSeconds).clamp(
      0,
      outcome.runtimeSeconds,
    );
    text +=
        ' · '
        '${context.l10n.plannerCanvas_scrub_tts('${(remainingSeconds / 60).ceil()}')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.readoutBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.readoutBorder),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: palette.readoutText,
        ),
      ),
    );
  }
}
