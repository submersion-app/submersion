import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_analyzer.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_group.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The diver's Dive focus choice, for the session (issue #1611).
final focusSelectionProvider = StateProvider<FocusSelection>(
  (ref) => const FocusSelection(),
);

/// Per-dive values of [metric]: the trend charts' own providers where one
/// exists for the metric, so a dive's value here is its value on that chart
/// and both pages share one cached query.
///
/// RMV and SAC read the repository directly: the gas page's
/// `sacTrendProvider` follows the page's lane toggle, while Dive focus names
/// its lane in the metric.
final focusMetricSeriesProvider =
    FutureProvider.family<List<TrendDataPoint>, FocusMetric>((
      ref,
      metric,
    ) async {
      switch (metric) {
        case FocusMetric.maxDepth:
          return ref.watch(depthProgressionTrendProvider.future);
        case FocusMetric.bottomTime:
          return ref.watch(bottomTimeTrendProvider.future);
        case FocusMetric.weight:
          return ref.watch(weightTrendProvider.future);
        case FocusMetric.waterTemp:
          return ref.watch(waterTempTrendProvider.future);
        case FocusMetric.rmv:
        case FocusMetric.sac:
          final repository = ref.watch(insightsRepositoryProvider);
          ref.invalidateSelfWhen(repository.watchInsightsChanges());
          final diverId = ref.watch(currentDiverIdProvider);
          final filter = ref.watch(insightsFilterProvider);
          return metric == FocusMetric.rmv
              ? repository.getSacVolumePerDive(diverId: diverId, filter: filter)
              : repository.getSacPressurePerDive(
                  diverId: diverId,
                  filter: filter,
                );
      }
    });

/// The dives the current selection picks.
final focusGroupProvider = FutureProvider<FocusGroup>((ref) async {
  final selection = ref.watch(focusSelectionProvider);
  final series = await ref.watch(
    focusMetricSeriesProvider(selection.metric).future,
  );
  return selectFocusGroup(series, selection);
});

/// Factor rows for every in-scope dive.
final focusFactorRowsProvider = FutureProvider<List<FocusFactorRow>>((
  ref,
) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(insightsFilterProvider);
  final scale = ref.watch(settingsProvider.select((s) => s.visibilityScale));
  return repository.getFocusFactorRows(
    diverId: diverId,
    filter: filter,
    visibilityScale: scale,
  );
});

/// The group's factors against the dives that have the metric.
final focusFactorReportProvider = FutureProvider<FocusFactorReport>((
  ref,
) async {
  final selection = ref.watch(focusSelectionProvider);
  final group = await ref.watch(focusGroupProvider.future);
  final rows = await ref.watch(focusFactorRowsProvider.future);
  final byId = {for (final r in rows) r.diveId: r};
  List<FocusFactorRow> pick(Iterable<TrendDataPoint> points) => [
    for (final p in points) ?byId[p.diveId],
  ];
  return FocusFactorAnalyzer.analyze(
    group: pick(group.members),
    baseline: pick(group.population),
    metric: selection.metric,
  );
});
