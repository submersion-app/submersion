import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_backdrop_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_edit_controller.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
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
  int? _hoverVertex;
  Offset? _downPosition;
  bool _moved = false;
  Duration? _lastTapAt;
  Offset? _lastTapPosition;
  var _idCounter = 0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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
    final vertexIndex = _dragVertex;
    if (vertexIndex == null) return;
    final ordered = _orderedSegments;
    if (vertexIndex >= ordered.length) return;
    final result = dragVertex(
      ordered: ordered,
      vertexIndex: vertexIndex,
      newDepthMeters: geometry.depthAtDy(local.dy),
      newTimeSeconds: geometry.timeAtDx(local.dx),
      depthUnitScale: geometry.depthUnitScale,
    );
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    for (final (id, segment) in result.updates) {
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

  Future<void> _showGasMenu(
    BuildContext context,
    PlanChartGeometry geometry,
    List<PlanVertex> vertices,
    Offset globalPosition,
    Offset local,
  ) async {
    final index = hitTestVertex(
      vertices: vertices,
      geometry: geometry,
      position: local,
    );
    if (index == null) return;
    final tanks = ref.read(divePlanNotifierProvider).tanks;
    if (tanks.isEmpty) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<DiveTank>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final tank in tanks)
          PopupMenuItem<DiveTank>(
            value: tank,
            child: Text(
              tank.name == null || tank.name!.isEmpty
                  ? tank.gasMix.name
                  : '${tank.name} · ${tank.gasMix.name}',
            ),
          ),
      ],
    );
    if (selected == null) return;

    final ordered = _orderedSegments;
    // A gas switch at vertex i applies to the FOLLOWING segment; fall back to
    // the vertex's own segment when it is the last one.
    final target = index + 1 < ordered.length
        ? ordered[index + 1]
        : ordered[index];
    ref
        .read(divePlanNotifierProvider.notifier)
        .updateSegment(
          target.id,
          target.copyWith(gasMix: selected.gasMix, tankId: selected.id),
        );
  }

  KeyEventResult _onKey(KeyEvent event, PlanChartGeometry geometry) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
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
      notifier.removeSegment(selectedId);
      ref.read(selectedSegmentIdProvider.notifier).state = null;
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
        newDepthMeters: segment.endDepth + delta,
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
    final ghost = ref.watch(deviationGhostSeriesProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final palette = PlanChartPalette.of(theme);

    if (series.isEmpty) return _EmptyState(theme: theme);

    final maxTime =
        ghost != null && ghost.maxTimeSeconds > series.maxTimeSeconds
        ? ghost.maxTimeSeconds
        : series.maxTimeSeconds;
    final maxDepth = ghost != null && ghost.maxDepth > series.maxDepth
        ? ghost.maxDepth
        : series.maxDepth;
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
    final vertices = planVertices(ref.watch(divePlanNotifierProvider).segments);

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
          if (vertexIndex == null) return null;
          final id = vertices[vertexIndex].segmentId;
          final idx = draggable.indexWhere((v) => v.segmentId == id);
          return idx >= 0 ? idx : null;
        }

        // Raw pointer handling (not GestureDetector) so tap, double-tap,
        // drag, scrub, and right-click never fight in a gesture arena - the
        // soup of tap + double-tap + pan recognizers swallows single taps.
        void onPointerDown(PointerDownEvent event) {
          _focusNode.requestFocus();
          if (event.buttons & kSecondaryButton != 0) {
            _showGasMenu(
              context,
              geometry,
              vertices,
              event.position,
              event.localPosition,
            );
            return;
          }
          _downPosition = event.localPosition;
          _moved = false;
          _dragVertex = hitTestVertex(
            vertices: vertices,
            geometry: geometry,
            position: event.localPosition,
          );
          if (_dragVertex == null) _scrubTo(geometry, event.localPosition);
        }

        void onPointerMove(PointerMoveEvent event) {
          final down = _downPosition;
          if (down != null && (event.localPosition - down).distance > 6) {
            _moved = true;
          }
          if (_dragVertex != null) {
            _applyDrag(geometry, event.localPosition);
          } else {
            _scrubTo(geometry, event.localPosition);
          }
        }

        void onPointerUp(PointerUpEvent event) {
          final wasDrag = _dragVertex != null;
          _dragVertex = null;
          _clearScrub();
          if (wasDrag || _moved) {
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
          if (hit == null) _scrubTo(geometry, event.localPosition);
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
                            ceiling: series.ceiling,
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
                        child: CustomPaint(
                          key: const Key('planChartSeries'),
                          painter: PlanChartSeriesPainter(
                            geometry: geometry,
                            palette: palette,
                            series: series,
                            ghost: ghost,
                            stopTagLabels: stopTagLabels,
                            meanDepthLabel: meanDepthLabel,
                            labelStyle: labelStyle,
                            tagStyle: tagStyle,
                            textDirection: direction,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            context.l10n.divePlanner_message_noProfile,
            style: theme.textTheme.titleMedium,
          ),
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
    final bailout = ref.watch(planBailoutProvider);
    var text = context.l10n.plannerCanvas_scrub_readout(
      minutes.toString(),
      units.formatDepth(depthMeters, decimals: 0),
    );
    if (bailout != null) {
      final point = bailout.nearest(runtimeSeconds);
      text +=
          ' · '
          '${context.l10n.plannerCanvas_scrub_bailout('${(point.ttsSeconds / 60).ceil()}')}';
    }
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
