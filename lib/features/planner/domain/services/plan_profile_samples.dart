import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// How often a planned dive's profile is sampled in the log.
const plannedDiveSampleInterval = Duration(seconds: 30);

/// [corners], a plan's waypoints, as a dive log profile: a sample every
/// [interval] along the straight lines between them, like a dive computer, with
/// every corner kept so a stop is never cut short (issue #3565). The log
/// analyses a dive only at its samples, and its chart curves between them, so
/// corners alone give a ceiling with gaps and a line that overshoots.
List<DiveProfilePoint> sampledPlanProfile(
  List<DiveProfilePoint> corners, {
  Duration interval = plannedDiveSampleInterval,
}) {
  if (corners.length < 2) return corners;
  final step = interval.inSeconds;
  final samples = <DiveProfilePoint>[corners.first];
  for (var i = 1; i < corners.length; i++) {
    final from = corners[i - 1];
    final to = corners[i];
    final span = to.timestamp - from.timestamp;
    if (span <= 0) {
      // Two corners at one moment: the later one stands.
      samples[samples.length - 1] = to;
      continue;
    }
    for (
      var t = (from.timestamp ~/ step + 1) * step;
      t < to.timestamp;
      t += step
    ) {
      final fraction = (t - from.timestamp) / span;
      samples.add(
        DiveProfilePoint(
          timestamp: t,
          depth: from.depth + (to.depth - from.depth) * fraction,
        ),
      );
    }
    samples.add(to);
  }
  return samples;
}
