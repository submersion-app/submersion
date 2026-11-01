/// A stretch of the dive that adds to a running total, such as oxygen
/// exposure or the gas drawn from one cylinder, so the moment the total
/// first reaches a limit can be found once the dive is computed (#3738).
class RuntimeIncrement {
  const RuntimeIncrement({
    required this.startRuntime,
    required this.durationSeconds,
    required this.amount,
  });

  /// Elapsed dive time when the stretch begins, in seconds.
  final int startRuntime;

  /// Zero for a lump charged at one instant.
  final int durationSeconds;
  final double amount;
}

/// The runtime at which [start] plus [increments] first reaches [threshold],
/// each increment accruing evenly over its duration. Increments are read in
/// dive order, whatever order they were charged in, with a lump ahead of a
/// stretch starting at the same moment. 0 when [start] is already there, as
/// for a repetitive dive that begins with the exposure earlier dives left;
/// null when it is never reached.
int? runtimeReaching(
  Iterable<RuntimeIncrement> increments, {
  required double threshold,
  double start = 0,
}) {
  if (start >= threshold) return 0;
  final inDiveOrder = [...increments]
    ..sort((a, b) {
      final byStart = a.startRuntime.compareTo(b.startRuntime);
      return byStart != 0
          ? byStart
          : a.durationSeconds.compareTo(b.durationSeconds);
    });
  var total = start;
  for (final step in inDiveOrder) {
    final after = total + step.amount;
    if (after >= threshold && step.amount > 0) {
      final fraction = (threshold - total) / step.amount;
      return step.startRuntime + (fraction * step.durationSeconds).round();
    }
    total = after;
  }
  return null;
}

/// The runtime within a leg from [startDepth] to [endDepth] at which
/// [exceeds] first holds. [exceeds] must depend on depth alone and change
/// only once across the leg, as every depth limit does (deeper is worse for
/// ppO2, END and gas density; shallower is worse for a hypoxic gas), so the
/// crossing is found by bisection. Falls back to the leg's start when the
/// limit is already broken there or, defensively, never broken at all.
int legOnsetRuntime({
  required int startRuntime,
  required int durationSeconds,
  required double startDepth,
  required double endDepth,
  required bool Function(double depth) exceeds,
}) {
  double depthAt(double fraction) =>
      startDepth + (endDepth - startDepth) * fraction;
  if (durationSeconds <= 0 || exceeds(startDepth) || !exceeds(endDepth)) {
    return startRuntime;
  }
  var lo = 0.0;
  var hi = 1.0;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    if (exceeds(depthAt(mid))) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return startRuntime + (hi * durationSeconds).round();
}
