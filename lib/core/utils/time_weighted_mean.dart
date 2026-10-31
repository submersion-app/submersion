/// The mean of a series over elapsed time, built up one sample at a time.
///
/// Reads the samples as a piecewise linear series (the trapezoidal rule), so
/// the result depends on the path and not on how densely it was sampled: a
/// sample added on an existing segment leaves the mean unchanged. Samples go
/// in time order; a step that does not move forward in time adds nothing.
///
/// Before any time has passed (a single sample, or several at one instant)
/// [value] is the average of the samples, since there is no span to weight by.
class TimeWeightedMean {
  double _area = 0;
  num _span = 0;
  double _sum = 0;
  int _count = 0;
  num? _lastTime;
  double? _lastValue;

  /// The integral of the series so far, in value-seconds for times in seconds.
  double get area => _area;

  /// The time the mean spans so far.
  num get span => _span;

  /// Adds a sample of [value] at [time].
  void add(num time, double value) {
    final lastTime = _lastTime;
    final lastValue = _lastValue;
    if (lastTime != null && lastValue != null && time > lastTime) {
      final elapsed = time - lastTime;
      _area += elapsed * (lastValue + value) / 2;
      _span += elapsed;
    }
    _sum += value;
    _count++;
    _lastTime = time;
    _lastValue = value;
  }

  /// The mean of the samples so far, or null before the first.
  double? get value {
    if (_span > 0) return _area / _span;
    return _count > 0 ? _sum / _count : null;
  }
}

/// The mean of [value] over [samples] by elapsed [time], or null without any
/// samples. See [TimeWeightedMean].
double? timeWeightedMean<T>(
  Iterable<T> samples, {
  required num Function(T sample) time,
  required double Function(T sample) value,
}) {
  final mean = TimeWeightedMean();
  for (final sample in samples) {
    mean.add(time(sample), value(sample));
  }
  return mean.value;
}

/// [samples] over the window from [start] to [end], in time order.
///
/// Reads the series at the window's edges by interpolating between the samples
/// either side, so a window that starts or ends between samples still covers
/// the whole of its time. A window running past the samples stops at them.
/// Empty when [samples] do not reach the window.
List<({num time, double value})> samplesInWindow<T>(
  Iterable<T> samples, {
  required num start,
  required num end,
  required num Function(T sample) time,
  required double Function(T sample) value,
}) {
  final window = <({num time, double value})>[];
  ({num time, double value})? previous;
  for (final sample in samples) {
    final current = (time: time(sample), value: value(sample));
    final before = previous;
    if (current.time < start) {
      previous = current;
      continue;
    }
    double interpolatedAt(num edge) {
      final progress = (edge - before!.time) / (current.time - before.time);
      return before.value + (current.value - before.value) * progress;
    }

    if (before != null && before.time < start && current.time > start) {
      window.add((time: start, value: interpolatedAt(start)));
    }
    if (current.time > end) {
      if (before != null && before.time < end) {
        window.add((time: end, value: interpolatedAt(end)));
      }
      break;
    }
    window.add(current);
    previous = current;
  }
  return window;
}

/// The mean over [window], a result of [samplesInWindow], or null when empty.
double? timeWeightedMeanOfWindow(List<({num time, double value})> window) =>
    timeWeightedMean(window, time: (s) => s.time, value: (s) => s.value);

/// The mean of [value] over the window from [start] to [end], or null when
/// [samples] do not reach it. See [samplesInWindow].
double? timeWeightedMeanBetween<T>(
  Iterable<T> samples, {
  required num start,
  required num end,
  required num Function(T sample) time,
  required double Function(T sample) value,
}) => timeWeightedMeanOfWindow(
  samplesInWindow(samples, start: start, end: end, time: time, value: value),
);

/// The mean of [value] over several [windows], each read as
/// [timeWeightedMeanBetween] reads one. The time between them counts for
/// nothing, so a series left and rejoined has no weight in the gap. Null when
/// [samples] reach none of them.
double? timeWeightedMeanAcross<T>(
  Iterable<T> samples, {
  required Iterable<({num start, num end})> windows,
  required num Function(T sample) time,
  required double Function(T sample) value,
}) {
  double area = 0;
  num span = 0;
  final means = <double>[];
  for (final window in windows) {
    final mean = TimeWeightedMean();
    final points = samplesInWindow(
      samples,
      start: window.start,
      end: window.end,
      time: time,
      value: value,
    );
    for (final point in points) {
      mean.add(point.time, point.value);
    }
    area += mean.area;
    span += mean.span;
    final windowMean = mean.value;
    if (windowMean != null) means.add(windowMean);
  }
  if (span > 0) return area / span;
  return means.isEmpty ? null : means.reduce((a, b) => a + b) / means.length;
}
