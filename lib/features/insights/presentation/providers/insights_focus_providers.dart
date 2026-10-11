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
        case FocusMetric.gasUsed:
        case FocusMetric.avgDepth:
        case FocusMetric.surfaceInterval:
        case FocusMetric.airTemp:
        case FocusMetric.visibility:
        case FocusMetric.altitude:
        case FocusMetric.cns:
        case FocusMetric.otu:
          final repository = ref.watch(insightsRepositoryProvider);
          ref.invalidateSelfWhen(repository.watchInsightsChanges());
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
            FocusMetric.gasUsed => repository.getGasUsedPerDive(
              diverId: diverId,
              filter: filter,
            ),
            FocusMetric.avgDepth => repository.getAvgDepthPerDive(
              diverId: diverId,
              filter: filter,
            ),
            FocusMetric.surfaceInterval => repository.getSurfaceIntervalPerDive(
              diverId: diverId,
              filter: filter,
            ),
            FocusMetric.airTemp => repository.getAirTempPerDive(
              diverId: diverId,
              filter: filter,
            ),
            FocusMetric.visibility => repository.getVisibilityPerDive(
              diverId: diverId,
              filter: filter,
            ),
            FocusMetric.altitude => repository.getAltitudePerDive(
              diverId: diverId,
              filter: filter,
            ),
            FocusMetric.cns => repository.getCnsPerDive(
              diverId: diverId,
              filter: filter,
            ),
            FocusMetric.otu => repository.getOtuPerDive(
              diverId: diverId,
              filter: filter,
            ),
            _ => throw StateError('handled above'),
          };
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

/// The population mean of the selected metric, in storage units: the value
/// a threshold field starts from so the page never opens on an empty box.
/// Null when no dive has the metric.
final focusThresholdDefaultProvider = FutureProvider<double?>((ref) async {
  final metric = ref.watch(focusSelectionProvider.select((s) => s.metric));
  final series = await ref.watch(focusMetricSeriesProvider(metric).future);
  if (series.isEmpty) return null;
  return series.fold<double>(0, (sum, p) => sum + p.value) / series.length;
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

/// [focusFactorRowsProvider]'s rows by dive id, mapped once per load rather
/// than on every rebuild of the page that reads them.
final focusFactorRowsByIdProvider = Provider<Map<String, FocusFactorRow>>((
  ref,
) {
  final rows = ref.watch(focusFactorRowsProvider).value ?? const [];
  return Map.unmodifiable({for (final r in rows) r.diveId: r});
});

/// The group's factors against the dives that have the metric.
final focusFactorReportProvider = FutureProvider<FocusFactorReport>((
  ref,
) async {
  final selection = ref.watch(focusSelectionProvider);
  final group = await ref.watch(focusGroupProvider.future);
  // Awaited so the map below holds the loaded rows, not a prior load's.
  await ref.watch(focusFactorRowsProvider.future);
  final byId = ref.watch(focusFactorRowsByIdProvider);
  List<FocusFactorRow> pick(Iterable<TrendDataPoint> points) => [
    for (final p in points) ?byId[p.diveId],
  ];
  return FocusFactorAnalyzer.analyze(
    group: pick(group.members),
    baseline: pick(group.population),
    metric: selection.metric,
  );
});
