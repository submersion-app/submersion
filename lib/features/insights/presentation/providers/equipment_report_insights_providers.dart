import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/reports/cost_of_ownership.dart';
import 'package:submersion/features/equipment/domain/reports/idle_gear.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_report_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
  final equipment = ref.watch(equipmentRepositoryProvider);
  final records = ref.watch(serviceRecordRepositoryProvider);
  final usage = ref.watch(equipmentUsageRepositoryProvider);
  ref.invalidateSelfWhen(equipment.watchEquipmentChanges());
  ref.invalidateSelfWhen(records.watchServiceRecordsChanges());
  ref.invalidateSelfWhen(usage.watchChanges());
  ref.invalidateSelfWhen(
    ref.read(equipmentShareRepositoryProvider).watchChanges(),
  );
  final fallback = ref.watch(defaultCurrencyProvider);

  final items = await equipment.getAllEquipment(diverId: diverId);
  final loaded = await (
    records.getRecordsForEquipmentIds([for (final i in items) i.id]),
    usage.getUsageTotals(diverId: diverId),
    usage.getStatsDiveCount(diverId: diverId),
  ).wait;
  return buildCostOfOwnership(
    items: items,
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
  final equipment = ref.watch(equipmentRepositoryProvider);
  final usage = ref.watch(equipmentUsageRepositoryProvider);
  ref.invalidateSelfWhen(equipment.watchEquipmentChanges());
  ref.invalidateSelfWhen(usage.watchChanges());
  ref.invalidateSelfWhen(
    ref.read(equipmentShareRepositoryProvider).watchChanges(),
  );
  final loaded = await (
    equipment.getAllEquipment(diverId: diverId),
    usage.getLastDiveDates(diverId: diverId),
  ).wait;
  return buildIdleGear(
    items: loaded.$1,
    lastDives: loaded.$2,
    diverId: diverId,
    period: period,
    now: DateTime.now(),
  );
});
