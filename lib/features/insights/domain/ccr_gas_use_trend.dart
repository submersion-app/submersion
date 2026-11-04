import 'package:submersion/features/insights/domain/trend_aggregation.dart';

/// O2 and diluent use per CCR dive, in L/min of loop time (issue #4082). A
/// line has one point per dive that has a rate for it, so the two can differ
/// in length.
class CcrGasUseTrend {
  const CcrGasUseTrend({required this.o2, required this.diluent});

  final List<TrendDataPoint> o2;
  final List<TrendDataPoint> diluent;

  bool get isEmpty => o2.isEmpty && diluent.isEmpty;

  /// The mean of the per-dive rates, null with no dives.
  double? get o2Average => _mean(o2);
  double? get diluentAverage => _mean(diluent);

  static double? _mean(List<TrendDataPoint> points) => points.isEmpty
      ? null
      : points.fold(0.0, (total, p) => total + p.value) / points.length;
}
