import 'package:submersion/core/profile/tank_pressure_glitches.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';

/// Tanks whose pressure series fall in more than one segment of a combined
/// dive: one cylinder breathed on both sides of a surface interval, which
/// combine carries as a single tank (#2036).
///
/// [segmentOf] names the segment a series belongs to from its first sample's
/// timestamp, the same rule separate uses to decide which series move, or
/// null when none holds it.
Set<String> tanksSharedAcrossSegments(
  Iterable<TankPressureSeries> pressures,
  int? Function(int timestamp) segmentOf,
) {
  final segmentsByTank = <String, Set<int>>{};
  for (final s in pressures) {
    if (s.samples.isEmpty) continue;
    var first = s.samples.first.timestamp;
    for (final p in s.samples) {
      if (p.timestamp < first) first = p.timestamp;
    }
    final segment = segmentOf(first);
    if (segment == null) continue;
    (segmentsByTank[s.tankId] ??= <int>{}).add(segment);
  }
  return {
    for (final entry in segmentsByTank.entries)
      if (entry.value.length > 1) entry.key,
  };
}

/// The earliest and latest clean reading across [series], in bar, or null
/// when they hold no samples. A shared tank's start and end pressure are the
/// combined dive's, so a separated half takes its own from what its
/// transmitter logged, passing over a signal dropout at either end the way
/// every other derived endpoint does (#2441).
({double start, double end})? pressureSpanOf(
  Iterable<TankPressureSeries> series,
) => cleanSeriesEndpoints([
  for (final s in series)
    for (final p in s.samples) (t: p.timestamp, bar: p.pressure),
]);
