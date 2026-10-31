import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/services/trip_gear_scope.dart';
import 'package:submersion/features/trips/presentation/providers/trip_gear_ids_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// The inventory for [options]. Read once per export and released.
final inventoryReportProvider = FutureProvider.autoDispose
    .family<InventoryReport, InventoryReportOptions>((ref, options) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final repository = ref.watch(equipmentRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      ref.invalidateSelfWhen(
        ref.read(equipmentShareRepositoryProvider).watchChanges(),
      );
      final fallback = ref.watch(defaultCurrencyProvider);
      final locations = await ref.watch(
        currentEquipmentLocationsProvider.future,
      );
      final items = await repository.getAllEquipment(diverId: diverId);
      return buildInventoryReport(
        items: items,
        locations: locations,
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
      // Everything but wishlist gear, not just active gear: a past trip must
      // keep what has been retired since, and gearOnTrip walks up the parents
      // only inside the list it is given.
      final known = [
        for (final item in all)
          if (!item.isWanted) item,
      ];
      return (
        gear: gearOnTrip(known, onTrip),
        tripEnd: trip?.endDate,
        label: trip?.name,
      );
    case ServiceReportScope.item:
      final itemId = options.itemId!;
      final ids = withInstalledParts(itemId, all);
      return (
        gear: [
          for (final item in all)
            if (ids.contains(item.id)) item,
        ],
        tripEnd: null,
        label: all.where((item) => item.id == itemId).firstOrNull?.name,
      );
  }
}

/// The service report for [options]. Read once per export and released.
final serviceReportProvider = FutureProvider.autoDispose
    .family<ServiceReport, ServiceReportOptions>((ref, options) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final repository = ref.watch(equipmentRepositoryProvider);
      final recordRepository = ref.watch(serviceRecordRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      ref.invalidateSelfWhen(recordRepository.watchServiceRecordsChanges());
      ref.invalidateSelfWhen(
        ref.read(equipmentShareRepositoryProvider).watchChanges(),
      );
      final fallback = ref.watch(defaultCurrencyProvider);

      final all = await repository.getAllEquipment(diverId: diverId);
      final scope = await _scopeOf(ref, options, all);
      final ids = [for (final item in scope.gear) item.id];
      final clocks = await evaluateServiceClocksForIds(ref, ids);
      final kinds = await ref.watch(allServiceKindsByIdProvider.future);
      final records = options.includeHistory
          ? await recordRepository.getRecordsForEquipmentIds(ids)
          : const <String, Never>{};
      final counted = records.keys.toList();
      final counts = await Future.wait([
        for (final id in counted)
          repository.getDiveCountForEquipment(id, diverId: diverId),
      ]);
      return buildServiceReport(
        gear: scope.gear,
        clocks: clocks,
        records: records,
        kindsById: kinds,
        diveCounts: {
          for (final (index, id) in counted.indexed) id: counts[index],
        },
        options: options,
        fallbackCurrency: fallback,
        tripEnd: scope.tripEnd,
        scopeLabel: scope.label,
      );
    });
