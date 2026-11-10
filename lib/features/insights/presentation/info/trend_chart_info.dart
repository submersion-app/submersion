import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// A per-dive trend chart: its own [summary] and [metricTerms], then each
/// overlay its controls have switched on, and how the controls work.
InfoContent trendChartInfo(
  AppLocalizations l10n,
  UnitFormatter units, {
  required String title,
  required String summary,
  List<DiveTerm> metricTerms = const [],
  required TrendChartSettings settings,
  required TrendGapThreshold gaps,
}) {
  return InfoContent(
    title: title,
    summary: summary,
    terms: diveTermEntries(l10n, units, [
      ...metricTerms,
      if (settings.showRollingMean) DiveTerm.rollingAverage,
      if (settings.showLinearFit) ...[
        DiveTerm.overallTrend,
        DiveTerm.perYearRate,
      ],
      if (settings.aggregation != TrendAggregation.none) DiveTerm.rangeBand,
      if (gaps != TrendGapThreshold.off) DiveTerm.collapseGaps,
    ]),
    howToUse: l10n.info_insights_trendControls_howToUse,
  );
}
