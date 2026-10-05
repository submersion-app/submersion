import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String focusMetricLabel(FocusMetric metric, AppLocalizations l10n) =>
    switch (metric) {
      FocusMetric.rmv => l10n.insights_focus_metric_rmv,
      FocusMetric.sac => l10n.insights_focus_metric_sac,
      FocusMetric.maxDepth => l10n.insights_focus_metric_maxDepth,
      FocusMetric.bottomTime => l10n.insights_focus_metric_bottomTime,
      FocusMetric.weight => l10n.insights_focus_metric_weight,
      FocusMetric.waterTemp => l10n.insights_focus_metric_waterTemp,
    };

/// "Best" and "Worst" for gas consumption, where lower is better; "Lowest"
/// and "Highest" for metrics with no better end.
String focusModeLabel(
  FocusMode mode,
  FocusMetric metric,
  AppLocalizations l10n,
) => switch (mode) {
  FocusMode.lowest =>
    metric.lowerIsBetter
        ? l10n.insights_focus_mode_best
        : l10n.insights_focus_mode_lowest,
  FocusMode.highest =>
    metric.lowerIsBetter
        ? l10n.insights_focus_mode_worst
        : l10n.insights_focus_mode_highest,
  FocusMode.above => l10n.insights_focus_mode_above,
  FocusMode.below => l10n.insights_focus_mode_below,
};
