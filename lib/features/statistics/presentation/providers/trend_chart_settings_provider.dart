import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';

/// Stable ids for the charts that carry a trend control strip. Used as the
/// family key so each chart keeps its own aggregation and overlay choices.
abstract final class TrendChartIds {
  static const depth = 'depth';
  static const bottomTime = 'bottom-time';
  static const sac = 'sac';
  static const weight = 'weight';
  static const waterTemp = 'water-temp';
}

/// How one trend chart is drawn. Raw per-dive by default: the whole point of
/// issue #299 is that an average is opt-in, not the starting position.
class TrendChartSettings {
  const TrendChartSettings({
    this.aggregation = TrendAggregation.none,
    this.showRollingMean = true,
    this.showLinearFit = false,
  });

  final TrendAggregation aggregation;
  final bool showRollingMean;
  final bool showLinearFit;

  TrendChartSettings copyWith({
    TrendAggregation? aggregation,
    bool? showRollingMean,
    bool? showLinearFit,
  }) {
    return TrendChartSettings(
      aggregation: aggregation ?? this.aggregation,
      showRollingMean: showRollingMean ?? this.showRollingMean,
      showLinearFit: showLinearFit ?? this.showLinearFit,
    );
  }
}

/// Per-chart drawing settings, keyed by [TrendChartIds].
///
/// Deliberately in-memory for the session only, matching
/// `statisticsFilterProvider`, which is likewise an unpersisted StateProvider.
final trendChartSettingsProvider =
    StateProvider.family<TrendChartSettings, String>(
      (ref, chartId) => const TrendChartSettings(),
    );
