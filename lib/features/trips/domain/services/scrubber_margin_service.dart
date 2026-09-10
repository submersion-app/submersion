import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';

/// Default when the diver has no trip history to read a rate from.
const defaultDivesPerDiveDay = 2.0;

/// The caution line: a margin under this share of the rated duration.
const scrubberCautionFraction = 0.2;

/// Pure. Expected dives = override, else dive days times the median dives
/// per dive day over recent trips (default 2), rounded up. Minutes per
/// dive = override, else the median summary figure over recent CCR dives,
/// else the median CCR runtime, else 0. Margin = remaining minus expected
/// use; null without a rating.
ScrubberMargin computeScrubberMargin(ScrubberMarginInputs inputs) {
  final rated = inputs.ratedMinutes;
  final remaining = rated == null
      ? 0.0
      : (rated - inputs.consumedMinutes).clamp(0.0, double.infinity);

  final int expectedDives;
  final int expectedDivesN;
  if (inputs.expectedDivesOverride != null) {
    expectedDives = inputs.expectedDivesOverride!;
    expectedDivesN = 0;
  } else {
    final history = inputs.divesPerDiveDayHistory;
    final perDay = history.isEmpty ? defaultDivesPerDiveDay : _median(history);
    expectedDives = (inputs.itineraryDiveDays * perDay).ceil();
    expectedDivesN = history.length;
  }

  final double minutesPerDive;
  final int minutesPerDiveN;
  if (inputs.runtimeMinutesOverride != null) {
    minutesPerDive = inputs.runtimeMinutesOverride!.toDouble();
    minutesPerDiveN = 0;
  } else if (inputs.scrubberMinutesHistory.isNotEmpty) {
    minutesPerDive = _median(inputs.scrubberMinutesHistory);
    minutesPerDiveN = inputs.scrubberMinutesHistory.length;
  } else if (inputs.ccrRuntimeMinutesHistory.isNotEmpty) {
    minutesPerDive = _median(inputs.ccrRuntimeMinutesHistory);
    minutesPerDiveN = inputs.ccrRuntimeMinutesHistory.length;
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
    remainingBefore: remaining,
    expectedDives: expectedDives,
    expectedDivesN: expectedDivesN,
    minutesPerDive: minutesPerDive,
    minutesPerDiveN: minutesPerDiveN,
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
