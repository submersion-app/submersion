import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';

/// Default when the diver has no trip history to read a rate from.
const defaultDivesPerDiveDay = 2.0;

/// [calendarDate]'s date as a dive timestamp. Dives are stored as their
/// wall clock in UTC, while trip and service dates are local midnights,
/// so comparing the two as instants puts a dive on the wrong side of the
/// line whenever the device is not on UTC. Compare against this instead.
DateTime asDiveWallClockDate(DateTime calendarDate) =>
    DateTime.utc(calendarDate.year, calendarDate.month, calendarDate.day);

/// The caution line: a margin under this share of the rated duration.
const scrubberCautionFraction = 0.2;

/// Pure. Expected dives = override, else dive days times the median dives
/// per dive day over recent trips (default 2), rounded up. Minutes per
/// dive = override, else the median summary figure over recent rebreather dives,
/// else the median CCR runtime, else 0. Margin = remaining minus expected
/// use; null without a rating. A zero or negative override counts as
/// unset, the same rule the trip form applies when it saves.
ScrubberMargin computeScrubberMargin(ScrubberMarginInputs inputs) {
  int? positive(int? v) => v != null && v > 0 ? v : null;
  final divesOverride = positive(inputs.expectedDivesOverride);
  final minutesOverride = positive(inputs.runtimeMinutesOverride);
  final rated = inputs.ratedMinutes;
  final remaining = rated == null
      ? 0.0
      : (rated - inputs.consumedMinutes).clamp(0.0, double.infinity);

  final int expectedDives;
  final int expectedDivesN;
  if (divesOverride != null) {
    expectedDives = divesOverride;
    expectedDivesN = 0;
  } else {
    final history = inputs.divesPerDiveDayHistory;
    final perDay = history.isEmpty ? defaultDivesPerDiveDay : _median(history);
    expectedDives = (inputs.itineraryDiveDays * perDay).ceil();
    expectedDivesN = history.length;
  }

  final double minutesPerDive;
  final int minutesPerDiveN;
  if (minutesOverride != null) {
    minutesPerDive = minutesOverride.toDouble();
    minutesPerDiveN = 0;
  } else if (inputs.scrubberMinutesHistory.isNotEmpty) {
    minutesPerDive = _median(inputs.scrubberMinutesHistory);
    minutesPerDiveN = inputs.scrubberMinutesHistory.length;
  } else if (inputs.rebreatherRuntimeMinutesHistory.isNotEmpty) {
    minutesPerDive = _median(inputs.rebreatherRuntimeMinutesHistory);
    minutesPerDiveN = inputs.rebreatherRuntimeMinutesHistory.length;
  } else {
    minutesPerDive = 0;
    minutesPerDiveN = 0;
  }

  final expectedUse = expectedDives * minutesPerDive;
  final margin = rated == null ? null : remaining - expectedUse;
  final caution =
      rated != null &&
      margin != null &&
      (margin < 0 || margin < scrubberCautionFraction * rated);

  return ScrubberMargin(
    item: inputs.item,
    ratedMinutes: rated,
    consumedMinutes: inputs.consumedMinutes,
    consumedSince: inputs.consumedSince,
    remainingBefore: remaining,
    expectedDives: expectedDives,
    expectedDivesN: expectedDivesN,
    divesFromOverride: divesOverride != null,
    minutesPerDive: minutesPerDive,
    minutesPerDiveN: minutesPerDiveN,
    minutesFromOverride: minutesOverride != null,
    expectedUse: expectedUse,
    marginAfter: margin,
    caution: caution,
  );
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}
