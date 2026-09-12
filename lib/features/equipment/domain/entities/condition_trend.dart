import 'package:equatable/equatable.dart';

import 'package:submersion/features/statistics/domain/trend_aggregation.dart';

/// Which per-dive quantity an item's condition chart plots.
enum ConditionTrendKind {
  /// mV per bar, one series per cell slot (cells and rebreathers).
  cellGain,

  /// Seconds without a pressure reading over dive seconds (transmitters).
  transmitterGapFraction,

  /// Consumed scrubber minutes per dive (rebreathers).
  scrubberMinutes,

  /// Minimum water temperature per dive in Celsius, with the dives that
  /// carry an issue check-in as a second series (regulators, BCDs,
  /// drysuits, lights).
  minTemperature,
}

/// One drawn series. [slot] is set for cell series only; [key] is stable
/// across rebuilds so a legend colour never jumps between slots.
class ConditionTrendSeries extends Equatable {
  final String key;
  final int? slot;
  final List<TrendDataPoint> points;

  const ConditionTrendSeries({
    required this.key,
    this.slot,
    required this.points,
  });

  @override
  List<Object?> get props => [key, slot, points];
}

class ConditionTrend extends Equatable {
  final ConditionTrendKind kind;
  final List<ConditionTrendSeries> series;

  const ConditionTrend({required this.kind, required this.series});

  bool get isEmpty => series.every((s) => s.points.isEmpty);

  @override
  List<Object?> get props => [kind, series];
}
