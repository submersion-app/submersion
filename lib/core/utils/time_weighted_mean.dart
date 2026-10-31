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
