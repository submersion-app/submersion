import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String focusMetricLabel(FocusMetric metric, AppLocalizations l10n) =>
    switch (metric) {
      FocusMetric.rmv => l10n.insights_focus_metric_rmv,
      FocusMetric.sac => l10n.insights_focus_metric_sac,
      FocusMetric.maxDepth => l10n.insights_focus_metric_maxDepth,
      FocusMetric.runtime => l10n.insights_focus_metric_runtime,
      FocusMetric.bottomTime => l10n.insights_focus_metric_bottomTime,
      FocusMetric.weight => l10n.insights_focus_metric_weight,
      FocusMetric.waterTemp => l10n.insights_focus_metric_waterTemp,
      FocusMetric.gasUsed => l10n.insights_focus_metric_gasUsed,
      FocusMetric.avgDepth => l10n.insights_focus_metric_avgDepth,
      FocusMetric.surfaceInterval => l10n.insights_focus_metric_surfaceInterval,
      FocusMetric.airTemp => l10n.insights_focus_metric_airTemp,
      FocusMetric.visibility => l10n.insights_focus_metric_visibility,
      FocusMetric.altitude => l10n.insights_focus_metric_altitude,
      FocusMetric.cns => l10n.insights_focus_metric_cns,
      FocusMetric.otu => l10n.insights_focus_metric_otu,
    };

/// The heading a metric sits under in the sentence builder's menu.
String focusMetricGroupLabel(FocusMetricGroup group, AppLocalizations l10n) =>
    switch (group) {
      FocusMetricGroup.gas => l10n.insights_focus_metricGroup_gas,
      FocusMetricGroup.depthTime => l10n.insights_focus_metricGroup_depthTime,
      FocusMetricGroup.conditions => l10n.insights_focus_metricGroup_conditions,
      FocusMetricGroup.exposure => l10n.insights_focus_metricGroup_exposure,
      FocusMetricGroup.kit => l10n.insights_focus_metricGroup_kit,
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
