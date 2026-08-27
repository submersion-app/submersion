import 'dart:math' as math;

/// Tolerance for treating a ceiling as sitting exactly on a stop boundary.
/// Buhlmann ceilings arrive as floating point, so a value that is 1e-9 above
/// a multiple of the stop increment must not be pushed to the next stop.
const double _stopEpsilon = 1e-6;

/// Quantize a decompression ceiling curve to discrete stop levels.
///
/// Each positive ceiling is rounded up to the next multiple of
/// [stopIncrement], which is how a dive computer presents a stop: a ceiling of
/// 4.2 m means the diver may not ascend above the 6 m stop. Zero and negative
/// values mean no obligation and become 0.0.
///
/// When [stopIncrement] is not positive the curve is returned unchanged, so a
/// misconfigured setting degrades to the raw ceiling rather than dividing by
/// zero.
List<double> quantizeCeilingToStops(
  List<double> ceilingCurve, {
  required double stopIncrement,
}) {
  if (stopIncrement <= 0) return List<double>.from(ceilingCurve);
  return [
    for (final ceiling in ceilingCurve)
      if (ceiling <= 0)
        0.0
      else
        (math.max(1, (ceiling / stopIncrement - _stopEpsilon).ceil())) *
            stopIncrement,
  ];
}

/// Indices at which a piecewise-constant curve changes value.
///
/// A stop curve is flat between transitions, so keeping only the transition
/// samples (plus the final index, which anchors the trailing segment) is a
/// lossless compression. The generic profile decimator is unsuitable here
/// because it can drop the exact sample where a step occurs, which would slant
/// the step edge.
List<int> stepTransitionIndices(List<double> curve) {
  if (curve.isEmpty) return const [];
  final indices = <int>[0];
  for (var i = 1; i < curve.length; i++) {
    if (curve[i] != curve[i - 1]) indices.add(i);
  }
  final lastIndex = curve.length - 1;
  if (indices.last != lastIndex) indices.add(lastIndex);
  return indices;
}
