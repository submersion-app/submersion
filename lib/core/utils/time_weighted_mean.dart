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

/// The mean of [value] over the window from [start] to [end], or null when
/// [samples] do not reach it.
///
/// Reads the series at the window's edges by interpolating between the samples
/// either side, so a window that starts or ends between samples still weighs
/// the whole of its time. A window running past the samples stops at them.
double? timeWeightedMeanBetween<T>(
  Iterable<T> samples, {
  required num start,
  required num end,
  required num Function(T sample) time,
  required double Function(T sample) value,
}) {
  final mean = TimeWeightedMean();
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
      mean.add(start, interpolatedAt(start));
    }
    if (current.time > end) {
      if (before != null && before.time < end) {
        mean.add(end, interpolatedAt(end));
      }
      break;
    }
    mean.add(current.time, current.value);
    previous = current;
  }
  return mean.value;
}
