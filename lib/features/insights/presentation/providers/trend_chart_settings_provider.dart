import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';

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
    this.range = TrendRange.all,
  });

  final TrendAggregation aggregation;
  final bool showRollingMean;
  final bool showLinearFit;

  /// The visible window, from the Range menu or the last pan and zoom.
  final TrendRange range;

  TrendChartSettings copyWith({
    TrendAggregation? aggregation,
    bool? showRollingMean,
    bool? showLinearFit,
    TrendRange? range,
  }) {
    return TrendChartSettings(
      aggregation: aggregation ?? this.aggregation,
      showRollingMean: showRollingMean ?? this.showRollingMean,
      showLinearFit: showLinearFit ?? this.showLinearFit,
      range: range ?? this.range,
    );
  }
}

/// Per-chart drawing settings, keyed by [TrendChartIds].
///
/// Deliberately in-memory for the session only, matching
/// `insightsFilterProvider`, which is likewise an unpersisted StateProvider.
final trendChartSettingsProvider =
    StateProvider.family<TrendChartSettings, String>(
      (ref, chartId) => const TrendChartSettings(),
    );
