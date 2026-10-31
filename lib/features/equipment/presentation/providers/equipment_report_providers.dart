import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_gear_ids_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// The inventory for [options]. Read once per export and released.
final inventoryReportProvider = FutureProvider.autoDispose
    .family<InventoryReport, InventoryReportOptions>((ref, options) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final fallback = ref.watch(defaultCurrencyProvider);
      final loaded = await (
        ref.watch(allEquipmentProvider.future),
        ref.watch(equipmentComponentsIndexProvider.future),
        ref.watch(currentEquipmentLocationsProvider.future),
      ).wait;
      return buildInventoryReport(
        items: withAssemblyParents(loaded.$1, loaded.$2),
        locations: loaded.$3,
        options: options,
        diverId: diverId,
        fallbackCurrency: fallback,
      );
    });

/// The gear a service report covers, what its dues are judged against, and
/// the name printed under the title.
typedef _ServiceScope = ({
  List<EquipmentItem> gear,
  DateTime? tripEnd,
  String? label,
});

Future<_ServiceScope> _scopeOf(
  Ref ref,
  ServiceReportOptions options,
  List<EquipmentItem> all,
  ComponentsIndex index,
) async {
  switch (options.scope) {
    case ServiceReportScope.all:
      return (
        gear: all.where(isServiceable).toList(),
        tripEnd: null,
        label: null,
      );
    case ServiceReportScope.trip:
      final tripId = options.tripId!;
      final trip = await ref.watch(tripByIdProvider(tripId).future);
      final onTrip = await ref.watch(tripGearIdsProvider(tripId).future);
      return (
        gear: gearWithParts(onTrip, all, index),
        tripEnd: trip?.endDate,
        label: trip?.name,
      );
    case ServiceReportScope.item:
      final itemId = options.itemId!;
      return (
        gear: gearWithParts({itemId}, all, index),
        tripEnd: null,
        label: all.where((item) => item.id == itemId).firstOrNull?.name,
      );
  }
}

/// The service report for [options]. Read once per export and released.
final serviceReportProvider = FutureProvider.autoDispose
    .family<ServiceReport, ServiceReportOptions>((ref, options) async {
      final repository = ref.watch(equipmentRepositoryProvider);
      final recordRepository = ref.watch(serviceRecordRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      ref.invalidateSelfWhen(recordRepository.watchServiceRecordsChanges());
      final fallback = ref.watch(defaultCurrencyProvider);

      final stored = await ref.watch(allEquipmentProvider.future);
      final index = await ref.watch(equipmentComponentsIndexProvider.future);
      final scope = await _scopeOf(
        ref,
        options,
        withAssemblyParents(stored, index),
        index,
      );
      final ids = [for (final item in scope.gear) item.id];
      final clocks = await evaluateServiceClocksForIds(ref, ids);
      final kinds = await ref.watch(allServiceKindsByIdProvider.future);
      final records = options.includeHistory
          ? await recordRepository.getRecordsForEquipmentIds(ids)
          : const <String, List<ServiceRecord>>{};
      // The stored rows: exposure reads the parent as install history, which
      // is how a cell inherits the dives of the rebreather it sits in.
      final exposures = await repository.getItemExposures([
        for (final item in stored)
          if (records.containsKey(item.id)) item,
      ]);
      return buildServiceReport(
        gear: scope.gear,
        clocks: clocks,
        records: records,
        kindsById: kinds,
        diveCounts: {
          for (final entry in exposures.entries)
            entry.key: entry.value.samples.length,
        },
        options: options,
        fallbackCurrency: fallback,
        tripEnd: scope.tripEnd,
        scopeLabel: scope.label,
      );
    });
