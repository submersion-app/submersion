import 'package:flutter/foundation.dart';

import 'package:submersion/features/insights/domain/focus/focus_metric.dart';

/// How Dive focus picks its group.
enum FocusMode {
  lowest,
  highest,
  above,
  below;

  bool get isRanked => this == lowest || this == highest;
}

/// The diver's Dive focus choice. [threshold] is in storage units (litres
/// or bar per minute, metres, minutes, kilograms, Celsius).
@immutable
class FocusSelection {
  const FocusSelection({
    this.metric = FocusMetric.rmv,
    this.mode = FocusMode.lowest,
    this.count = 10,
    this.threshold,
  });

  static const int minCount = 1;
  static const int maxCount = 999;

  final FocusMetric metric;
  final FocusMode mode;
  final int count;
  final double? threshold;

  FocusSelection copyWith({
    FocusMetric? metric,
    FocusMode? mode,
    int? count,
    double? threshold,
    bool clearThreshold = false,
  }) => FocusSelection(
    metric: metric ?? this.metric,
    mode: mode ?? this.mode,
    count: count ?? this.count,
    threshold: clearThreshold ? null : threshold ?? this.threshold,
  );

  @override
  bool operator ==(Object other) =>
      other is FocusSelection &&
      other.metric == metric &&
      other.mode == mode &&
      other.count == count &&
      other.threshold == threshold;

  @override
  int get hashCode => Object.hash(metric, mode, count, threshold);
}
