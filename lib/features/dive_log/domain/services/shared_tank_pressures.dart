import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
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

/// The earliest and latest reading across [series], in bar, or null when
/// they hold no samples. A shared tank's start and end pressure are the
/// combined dive's, so a separated half takes its own from what its
/// transmitter logged.
({double start, double end})? pressureSpanOf(
  Iterable<TankPressureSeries> series,
) {
  TankPressureSample? first;
  TankPressureSample? last;
  for (final s in series) {
    for (final p in s.samples) {
      if (first == null || p.timestamp < first.timestamp) first = p;
      if (last == null || p.timestamp > last.timestamp) last = p;
    }
  }
  if (first == null || last == null) return null;
  return (start: first.pressure, end: last.pressure);
}
