import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:submersion/core/utils/bidi_isolate.dart';

/// Half the span of the trim axis for [values], in degrees: the largest
/// angle either side of flat, rounded up to the next 5 degrees, never less
/// than 10 so a well-trimmed dive is not drawn as a large swing, and never
/// past vertical (issue #5098). A non-finite value is no reading.
double trimAxisHalfRange(Iterable<double> values) {
  final largest = values
      .where((v) => v.isFinite)
      .fold<double>(0, (m, v) => math.max(m, v.abs()));
  final rounded = (largest / 5).ceil() * 5.0;
  return rounded.clamp(10.0, 90.0);
}

/// [degrees] as the chart shows a trim angle: whole degrees with a sign, so
/// head up (+) and head down (-) read at a glance; flat is '0°'. Isolated
/// in right-to-left text ([direction]) so bidi reordering cannot move the
/// sign to the far end of the number. A non-finite value reads '-', as a
/// sample with no reading does.
String formatTrimDegrees(
  double degrees, {
  TextDirection direction = TextDirection.ltr,
}) {
  if (!degrees.isFinite) return '-';
  final whole = degrees.round();
  if (whole == 0) return '0°';
  return isolateForDirection(whole > 0 ? '+$whole°' : '$whole°', direction);
}
