import 'package:submersion/features/dive_import/domain/entities/health_sample.dart';

/// Turns Apple Health samples into a dive's readings (issue #637). Every
/// instant is true UTC; callers convert a dive's wall-clock times first.

/// A dive's average and highest heart rate, in bpm.
class HeartRateSummary {
  const HeartRateSummary({required this.average, required this.maximum});

  final int average;
  final int maximum;
}

/// Heart rate at the exit and five and fifteen minutes later, in bpm; null
/// where Health has no sample close enough.
class RecoveryReadings {
  const RecoveryReadings({this.atExit, this.plus5, this.plus15});

  final int? atExit;
  final int? plus5;
  final int? plus15;
}

/// How far a sample may be from a recovery moment and still stand for it.
const recoveryTolerance = Duration(minutes: 2);

/// Asleep stretches this close together are one night.
const _nightGap = Duration(hours: 1);

/// A night is at least this long, so an afternoon nap is not one.
const _shortestNight = Duration(hours: 3);

/// How long after the dive the night may start.
const _nightReach = Duration(hours: 18);

HeartRateSummary? summarizeHeartRate(List<HealthSample> samples) {
  if (samples.isEmpty) return null;
  final values = [for (final s in samples) s.value];
  final total = values.reduce((a, b) => a + b);
  final maximum = values.reduce((a, b) => a > b ? a : b);
  return HeartRateSummary(
    average: (total / values.length).round(),
    maximum: maximum.round(),
  );
}

RecoveryReadings recoveryAfter(List<HealthSample> samples, DateTime exit) =>
    RecoveryReadings(
      atExit: _nearest(samples, exit),
      plus5: _nearest(samples, exit.add(const Duration(minutes: 5))),
      plus15: _nearest(samples, exit.add(const Duration(minutes: 15))),
    );

int? _nearest(List<HealthSample> samples, DateTime moment) {
  HealthSample? best;
  Duration? bestGap;
  for (final s in samples) {
    final gap = s.at.difference(moment).abs();
    if (gap > recoveryTolerance) continue;
    if (bestGap == null || gap < bestGap) {
      best = s;
      bestGap = gap;
    }
  }
  return best?.value.round();
}

/// The mean heart rate variability (SDNN, ms) over the first night that
/// starts after [afterExit] and within 18 hours of it, or null. Asleep
/// stretches under an hour apart join into one night, and a night lasts at
/// least three hours, so a nap after the dive is not taken for it.
double? overnightHrv(
  List<HealthSample> hrv,
  List<SleepInterval> sleep,
  DateTime afterExit,
) {
  final night = _joined(sleep, _nightGap)
      .where(
        (n) =>
            !n.start.isBefore(afterExit) &&
            n.start.difference(afterExit) <= _nightReach &&
            n.end.difference(n.start) >= _shortestNight,
      )
      .firstOrNull;
  if (night == null) return null;
  final inside = [
    for (final s in hrv)
      if (!s.at.isBefore(night.start) && !s.at.isAfter(night.end)) s.value,
  ];
  if (inside.isEmpty) return null;
  return inside.reduce((a, b) => a + b) / inside.length;
}

/// Minutes asleep from 18:00 the evening before [firstEntryOfDay] to the
/// entry itself, or null when Health has none. 18:00 is read in the zone
/// [firstEntryOfDay] carries (local for a dive's converted entry). Overlapping
/// stretches, as from a phone and a watch, count once.
int? sleepBeforeMinutes(List<SleepInterval> sleep, DateTime firstEntryOfDay) {
  final from = firstEntryOfDay.isUtc
      ? DateTime.utc(
          firstEntryOfDay.year,
          firstEntryOfDay.month,
          firstEntryOfDay.day - 1,
          18,
        )
      : DateTime(
          firstEntryOfDay.year,
          firstEntryOfDay.month,
          firstEntryOfDay.day - 1,
          18,
        );
  final clipped = [
    for (final s in sleep)
      SleepInterval(
        start: s.start.isBefore(from) ? from : s.start,
        end: s.end.isAfter(firstEntryOfDay) ? firstEntryOfDay : s.end,
      ),
  ].where((s) => s.end.isAfter(s.start)).toList();
  final seconds = _joined(
    clipped,
    Duration.zero,
  ).fold<int>(0, (sum, s) => sum + s.end.difference(s.start).inSeconds);
  return seconds == 0 ? null : (seconds / 60).round();
}

/// `[epochSeconds, bpm]` pairs, true instants in time order, for the
/// samples from [from] on. Kept as times rather than offsets, so the line
/// stays where it was recorded when the dive's entry later moves.
List<List<int>> heartRateSeries(
  List<HealthSample> samples, {
  required DateTime from,
}) {
  final kept = [
    for (final s in samples)
      if (!s.at.isBefore(from)) s,
  ]..sort((a, b) => a.at.compareTo(b.at));
  return [
    for (final s in kept)
      [s.at.millisecondsSinceEpoch ~/ 1000, s.value.round()],
  ];
}

/// [intervals] in time order, with any that overlap or lie within [gap] of
/// each other joined.
List<SleepInterval> _joined(List<SleepInterval> intervals, Duration gap) {
  final sorted = [...intervals]..sort((a, b) => a.start.compareTo(b.start));
  return sorted.fold<List<SleepInterval>>([], (joined, s) {
    final last = joined.isEmpty ? null : joined.last;
    if (last == null || s.start.difference(last.end) > gap) {
      return [...joined, s];
    }
    final end = s.end.isAfter(last.end) ? s.end : last.end;
    return [
      ...joined.take(joined.length - 1),
      SleepInterval(start: last.start, end: end),
    ];
  });
}
