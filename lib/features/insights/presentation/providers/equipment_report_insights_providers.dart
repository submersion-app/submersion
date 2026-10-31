import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_usage_repository.dart';
import 'package:submersion/features/equipment/domain/reports/cost_of_ownership.dart';
import 'package:submersion/features/equipment/domain/reports/idle_gear.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final equipmentUsageRepositoryProvider = Provider<EquipmentUsageRepository>(
  (ref) => EquipmentUsageRepository(),
);

/// What the cost list ranks by.
final costMetricProvider = StateProvider<CostMetric>(
  (ref) => CostMetric.perDive,
);

/// The currency the cost section shows. Null is the one with the largest
/// total, which is also what a stale choice falls back to.
final costCurrencyProvider = StateProvider<String?>((ref) => null);

/// How long gear must sit before the idle list shows it.
final idlePeriodProvider = StateProvider<IdlePeriod>(
  (ref) => IdlePeriod.oneYear,
);

/// Cost of ownership across all of the diver's dives. Deliberately not the
/// Insights filter: what gear cost does not change with a date range, and
/// the section says so in its subtitle.
final costOfOwnershipProvider = FutureProvider<CostOfOwnership>((ref) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final records = ref.watch(serviceRecordRepositoryProvider);
  final usage = ref.watch(equipmentUsageRepositoryProvider);
  ref.invalidateSelfWhen(records.watchServiceRecordsChanges());
  ref.invalidateSelfWhen(usage.watchChanges());
  final fallback = ref.watch(defaultCurrencyProvider);

  final gear = await (
    ref.watch(allEquipmentProvider.future),
    ref.watch(equipmentComponentsIndexProvider.future),
  ).wait;
  final loaded = await (
    records.getRecordsForEquipmentIds([for (final i in gear.$1) i.id]),
    usage.getUsageTotals(diverId: diverId),
    usage.getStatsDiveCount(diverId: diverId),
  ).wait;
  return buildCostOfOwnership(
    items: withAssemblyParents(gear.$1, gear.$2),
    recordsByItem: loaded.$1,
    usage: loaded.$2,
    totalDives: loaded.$3,
    diverId: diverId,
    fallbackCurrency: fallback,
  );
});

/// Gear the diver owns and has not dived in the chosen period. Like cost, it
/// ignores the Insights filter: idle means idle across everything.
final idleGearProvider = FutureProvider<List<IdleRow>>((ref) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final period = ref.watch(idlePeriodProvider);
  final usage = ref.watch(equipmentUsageRepositoryProvider);
  ref.invalidateSelfWhen(usage.watchChanges());
  final loaded = await (
    ref.watch(allEquipmentProvider.future),
    ref.watch(equipmentComponentsIndexProvider.future),
    usage.getLastDiveDates(diverId: diverId),
  ).wait;
  return buildIdleGear(
    items: withAssemblyParents(loaded.$1, loaded.$2),
    lastDives: loaded.$3,
    diverId: diverId,
    period: period,
    now: DateTime.now(),
  );
});
