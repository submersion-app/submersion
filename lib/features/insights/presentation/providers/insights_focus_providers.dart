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

/// Per-dive values of [metric], from the same repository series the trend
/// charts draw, with the same filter and exclusion scope.
final focusMetricSeriesProvider =
    FutureProvider.family<List<TrendDataPoint>, FocusMetric>((
      ref,
      metric,
    ) async {
      keepInsightsProviderAlive(ref);
      final repository = ref.watch(insightsRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(insightsFilterProvider);
      return switch (metric) {
        FocusMetric.rmv => repository.getSacVolumePerDive(
          diverId: diverId,
          filter: filter,
        ),
        FocusMetric.sac => repository.getSacPressurePerDive(
          diverId: diverId,
          filter: filter,
        ),
        FocusMetric.maxDepth => repository.getDepthPerDive(
          diverId: diverId,
          filter: filter,
        ),
        FocusMetric.bottomTime => repository.getBottomTimePerDive(
          diverId: diverId,
          filter: filter,
        ),
        FocusMetric.weight => repository.getWeightPerDive(
          diverId: diverId,
          filter: filter,
        ),
        FocusMetric.waterTemp => repository.getWaterTempPerDive(
          diverId: diverId,
          filter: filter,
        ),
      };
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
  keepInsightsProviderAlive(ref);
  final repository = ref.watch(insightsRepositoryProvider);
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
