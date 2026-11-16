import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';

/// True when [event] is the mouse crossing a chart's edge with a button held.
///
/// Flutter's mouse tracker re-hit-tests every move of a pressed mouse, so a
/// drag that strays off a chart reports an exit even though the scrub goes
/// on: the gesture recognizer that won the pointer keeps tracking it, and its
/// updates, then its end, carry the cursor. An enter with a button held is
/// that same drag coming back, which its updates already cover, or a drag
/// that began elsewhere and is not the chart's to follow. Neither should move
/// a chart's cursor (issue #4611).
bool isDragCrossing(PointerEvent event) => event.buttons != 0;

/// [isDragCrossing] for the enter and exit events fl_chart reports to a
/// chart's touch callback. Every other event is false.
bool crossesChartEdgeMidDrag(FlTouchEvent event) => switch (event) {
  FlPointerExitEvent(:final event) => isDragCrossing(event),
  FlPointerEnterEvent(:final event) => isDragCrossing(event),
  _ => false,
};
