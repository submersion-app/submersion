import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/conditions/condition_bands.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Every in-scope dive's condition columns (issue #3118). Keyed on the diver
/// and the Insights filter only, so a unit change does not re-query.
final conditionsRowsProvider = FutureProvider<List<ConditionsRow>>((ref) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(insightsFilterProvider);
  return repository.getConditionsRows(diverId: diverId, filter: filter);
});

/// The unit choices the condition bands are defined in.
final conditionsUnitsProvider = Provider<ConditionsUnits>(
  (ref) => ConditionsUnits(
    temperature: ref.watch(settingsProvider.select((s) => s.temperatureUnit)),
    depth: ref.watch(settingsProvider.select((s) => s.depthUnit)),
  ),
);

/// Every condition statistic, re-binned when the units change.
final conditionsStatsProvider = FutureProvider<ConditionsStats>((ref) async {
  final units = ref.watch(conditionsUnitsProvider);
  final rows = await ref.watch(conditionsRowsProvider.future);
  return ConditionsStats.fromRows(rows, units);
});
