import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _StripDrag { move, resizeStart, resizeEnd }

/// A slim map of a zoomed date chart: every point across the full range, and
/// the visible window as a box. Drag the box to scroll, drag an edge to
/// resize, tap elsewhere to jump (issue #1611).
///
/// Reads and writes the chart's own [ChartViewport], so the strip, the zoom
/// buttons and pointer gestures can never disagree about the window.
class ChartOverviewStrip extends StatefulWidget {
  const ChartOverviewStrip({
    super.key,
    required this.points,
    required this.viewport,
    required this.onViewportChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.height = 28,
  });

  /// Every data point, x and y each normalised to 0..1 of the full range
  /// (y = 0 at the bottom).
  final List<Offset> points;
  final ChartViewport viewport;
  final ValueChanged<ChartViewport> onViewportChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;
  final double height;

  @override
  State<ChartOverviewStrip> createState() => _ChartOverviewStripState();
}

class _ChartOverviewStripState extends State<ChartOverviewStrip> {
  /// How close to an edge, in logical pixels, a drag must start to resize.
  static const _edgeSlop = 10.0;

  late ChartViewport _current = widget.viewport;
  _StripDrag _drag = _StripDrag.move;

  /// True between a drag's start and its end. The drag recognizer also
  /// cancels when a tap wins the arena, and that must not report an end.
  bool _dragging = false;

  @override
  void didUpdateWidget(ChartOverviewStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _current = widget.viewport;
  }

  void _emit(ChartViewport next) {
    _current = next;
    widget.onViewportChanged(next);
  }

  ChartViewport _centredOn(double fraction) => _current.pannedBy(
    fraction - (_current.windowStart + _current.windowEnd) / 2,
    0,
  );

  bool _inside(double fraction) =>
      fraction >= _current.windowStart && fraction <= _current.windowEnd;

  void _onDragStart(DragStartDetails details, double width) {
    _dragging = true;
    widget.onChangeStart?.call();
    final x = details.localPosition.dx;
    final startPx = _current.windowStart * width;
    final endPx = _current.windowEnd * width;
    // A narrow window would be all edge: shrink the grab zones so its middle
    // still moves it (a year of a long logbook is a few pixels on a phone).
    final slop = math.min(_edgeSlop, (endPx - startPx) / 4);
    if ((x - startPx).abs() <= slop) {
      _drag = _StripDrag.resizeStart;
    } else if ((x - endPx).abs() <= slop) {
      _drag = _StripDrag.resizeEnd;
    } else {
      _drag = _StripDrag.move;
      if (!_inside(x / width)) _emit(_centredOn(x / width));
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    final delta = details.delta.dx / width;
    final minWidth = 1 / _current.zoomLimit;
    switch (_drag) {
      case _StripDrag.move:
        _emit(_current.pannedBy(delta, 0));
      case _StripDrag.resizeStart:
        final start = (_current.windowStart + delta).clamp(
          0.0,
          _current.windowEnd - minWidth,
        );
        _emit(
          ChartViewport.forWindow(
            start,
            _current.windowEnd,
            zoomLimit: _current.zoomLimit,
          ),
        );
      case _StripDrag.resizeEnd:
        final end = (_current.windowEnd + delta).clamp(
          _current.windowStart + minWidth,
          1.0,
        );
        _emit(
          ChartViewport.forWindow(
            _current.windowStart,
            end,
            zoomLimit: _current.zoomLimit,
          ),
        );
    }
  }

  void _onDragEnd() {
    if (!_dragging) return;
    _dragging = false;
    widget.onChangeEnd?.call();
  }

  void _onTapUp(TapUpDetails details, double width) {
    final fraction = details.localPosition.dx / width;
    if (_inside(fraction)) return;
    widget.onChangeStart?.call();
    _emit(_centredOn(fraction));
    widget.onChangeEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.insights_trend_overview_semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            key: const ValueKey('trend-overview-strip'),
            behavior: HitTestBehavior.opaque,
            // The drag starts where the finger went down, so an edge grab is
            // decided before the slop moves the pointer off the edge.
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (d) => _onDragStart(d, width),
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
            onHorizontalDragEnd: (_) => _onDragEnd(),
            onHorizontalDragCancel: _onDragEnd,
            onTapUp: (d) => _onTapUp(d, width),
            child: CustomPaint(
              size: Size(width, widget.height),
              painter: _StripPainter(
                points: widget.points,
                start: widget.viewport.windowStart,
                end: widget.viewport.windowEnd,
                trackColor: scheme.surfaceContainerHighest,
                dotColor: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                windowColor: scheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.points,
    required this.start,
    required this.end,
    required this.trackColor,
    required this.dotColor,
    required this.windowColor,
  });

  final List<Offset> points;
  final double start;
  final double end;
  final Color trackColor;
  final Color dotColor;
  final Color windowColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
      Paint()..color = trackColor,
    );
    final dot = Paint()..color = dotColor;
    final usable = size.height - 6;
    for (final p in points) {
      canvas.drawCircle(
        Offset(p.dx * size.width, 3 + (1 - p.dy) * usable),
        1.2,
        dot,
      );
    }
    final window = Rect.fromLTRB(
      start * size.width,
      0,
      end * size.width,
      size.height,
    );
    canvas.drawRect(
      window,
      Paint()..color = windowColor.withValues(alpha: 0.18),
    );
    canvas.drawRect(
      window.deflate(0.75),
      Paint()
        ..color = windowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final handle = Paint()
      ..color = windowColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final x in [window.left, window.right]) {
      canvas.drawLine(
        Offset(x, size.height * 0.3),
        Offset(x, size.height * 0.7),
        handle,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.start != start ||
      old.end != end ||
      !identical(old.points, points) ||
      old.trackColor != trackColor ||
      old.dotColor != dotColor ||
      old.windowColor != windowColor;
}
