import 'dart:math' as math;

/// Round tick values for a tide height axis running from [min] to [max], in
/// whatever unit the axis is labelled in, with the decimals they need.
///
/// The step is the smallest of 1, 2 or 5 times a power of ten that leaves at
/// most [maxCount] ticks, so the labels read as round numbers in feet as
/// well as in metres.
({List<double> ticks, int decimals}) tideHeightTicks(
  double min,
  double max, {
  int maxCount = 4,
}) {
  final range = max - min;
  if (!(range > 0)) return (ticks: [min], decimals: 1);

  var exponent = (math.log(range / maxCount) / math.ln10).floor() - 1;
  while (true) {
    for (final factor in const [1, 2, 5]) {
      final step = factor * math.pow(10.0, exponent).toDouble();
      final first = (min / step - 1e-9).ceil();
      final last = (max / step + 1e-9).floor();
      final count = last - first + 1;
      if (count < 1 || count > maxCount) continue;
      final decimals = exponent >= 0 ? 0 : -exponent;
      return (
        ticks: [
          for (var i = first; i <= last; i++)
            double.parse((i * step).toStringAsFixed(decimals)),
        ],
        decimals: decimals,
      );
    }
    exponent++;
  }
}

/// The instants from [start] to [end] at which the site's clock reads a
/// whole multiple of [stepHours].
///
/// [toSite] maps an instant to the site's wall clock. Each tick is realigned
/// against it, so a daylight-saving change inside the window leaves the
/// later ticks on round hours rather than an hour off.
List<DateTime> wallClockHourTicks({
  required DateTime start,
  required DateTime end,
  required int stepHours,
  required DateTime Function(DateTime instant) toSite,
}) {
  final step = Duration(hours: stepHours);

  // How far the site clock at [instant] sits past a step boundary.
  Duration pastBoundary(DateTime instant) {
    final wall = toSite(instant);
    final intoDay = Duration(
      hours: wall.hour,
      minutes: wall.minute,
      seconds: wall.second,
      milliseconds: wall.millisecond,
      microseconds: wall.microsecond,
    );
    return Duration(microseconds: intoDay.inMicroseconds % step.inMicroseconds);
  }

  // [candidate] moved onto a step boundary of the site clock, later than
  // [after]. A step that crossed a clock change lands off a boundary by the
  // change. Moving the instant back or forward by that amount does not
  // always move the clock by it (stepping back can recross the change), so
  // each move is checked against the clock: the nearer one that lands on a
  // boundary wins, and failing both, the next boundary is found hour by
  // hour.
  bool onBoundary(DateTime instant) => pastBoundary(instant) == Duration.zero;
  DateTime realign(DateTime candidate, DateTime after) {
    final drift = pastBoundary(candidate);
    if (drift == Duration.zero) return candidate;
    final back = candidate.subtract(drift);
    final forward = candidate.add(step - drift);
    final options = drift * 2 <= step ? [back, forward] : [forward, back];
    for (final option in options) {
      if (option.isAfter(after) && onBoundary(option)) return option;
    }
    // Clock changes are whole or half hours, so a whole-hour walk from the
    // last tick finds the next boundary within a step and a little more.
    for (var hours = 1; hours <= stepHours + 2; hours++) {
      final probe = after.add(Duration(hours: hours));
      if (onBoundary(probe)) return probe;
    }
    return forward;
  }

  final ticks = <DateTime>[];
  final offset = pastBoundary(start);
  var tick = offset == Duration.zero
      ? start
      : realign(start.add(step - offset), start);
  while (!tick.isAfter(end)) {
    ticks.add(tick);
    final next = realign(tick.add(step), tick);
    if (!next.isAfter(tick)) break;
    tick = next;
  }
  return ticks;
}

/// The hour step for a day-long time axis [plotWidth] wide whose labels are
/// [labelWidth] wide: the finest step whose labels still fit side by side.
///
/// A window that starts on a step boundary has a tick at each end, so the
/// count includes both.
int tideTimeStepHours({
  required double plotWidth,
  required double labelWidth,
  int windowHours = 24,
}) {
  const gap = 8.0;
  for (final step in const [2, 3, 4, 6]) {
    final labels = windowHours ~/ step + 1;
    if (labels * (labelWidth + gap) <= plotWidth) return step;
  }
  return 12;
}
