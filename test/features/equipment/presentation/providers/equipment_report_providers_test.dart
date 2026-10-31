import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_report_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final ms = DateTime(2026).millisecondsSinceEpoch;

  final garage = EquipmentLocation(
    id: 'garage',
    name: 'Garage',
    kind: EquipmentLocationKind.storage,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> diver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(id: id, name: id, createdAt: ms, updatedAt: ms),
      );

  Future<void> item(
    String id, {
    String owner = 'me',
    String status = 'active',
    bool isActive = true,
    String? parent,
    double? price,
  }) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: ms,
          updatedAt: ms,
          diverId: Value(owner),
          status: Value(status),
          isActive: Value(isActive),
          parentEquipmentId: Value(parent),
          purchasePrice: Value(price),
        ),
      );

  Future<void> share(String equipmentId) => db
      .into(db.equipmentShares)
      .insert(
        EquipmentSharesCompanion.insert(
          id: 's-$equipmentId',
          equipmentId: equipmentId,
          diverId: 'me',
          createdAt: ms,
        ),
      );

  Future<void> record(String equipmentId, {double? cost}) => db
      .into(db.serviceRecords)
      .insert(
        ServiceRecordsCompanion.insert(
          id: 'r-$equipmentId',
          equipmentId: equipmentId,
          serviceCategory: 'annual',
          serviceDate: ms,
          createdAt: ms,
          updatedAt: ms,
        ).copyWith(cost: Value(cost)),
      );

  Future<void> trip(String id, {required List<String> packed}) async {
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: id,
            diverId: const Value('me'),
            name: 'Bonaire',
            startDate: ms,
            endDate: ms,
            createdAt: ms,
            updatedAt: ms,
          ),
        );
    for (final equipmentId in packed) {
      await db
          .into(db.tripEquipment)
          .insert(
            TripEquipmentCompanion.insert(
              id: '$id-$equipmentId',
              tripId: id,
              equipmentId: equipmentId,
              createdAt: ms,
            ),
          );
    }
  }

  Future<InventoryReport> inventory(InventoryReportOptions options) async {
    final provider = inventoryReportProvider(options);
    final sub = container.listen(provider.future, (_, _) {});
    addTearDown(sub.close);
    return sub.read();
  }

  Future<ServiceReport> service(ServiceReportOptions options) async {
    final provider = serviceReportProvider(options);
    final sub = container.listen(provider.future, (_, _) {});
    addTearDown(sub.close);
    return sub.read();
  }

  setUp(() async {
    db = await setUpTestDatabase();
    final overrides = await getBaseOverrides();
    container = ProviderContainer(
      overrides: [
        ...overrides,
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        currentEquipmentLocationsProvider.overrideWith(
          (ref) async => {'kept': garage},
        ),
      ].cast(),
    );
    addTearDown(container.dispose);
    await diver('me');
    await diver('them');
  });
  tearDown(tearDownTestDatabase);

  test('inventory loads owned gear and current locations', () async {
    await item('kept', price: 100);
    await item('sold', status: 'sold', isActive: false);
    await item('theirs', owner: 'them');
    await share('theirs');

    final report = await inventory(
      const InventoryReportOptions(grouping: InventoryGrouping.location),
    );

    expect(report.itemCount, 1);
    expect(report.groups.single.location, garage);
    expect(report.totals.single.value, 100);
  });

  test('all gear includes shared gear and drops lost gear', () async {
    await item('mine');
    await item('lost', status: 'lost');
    await item('theirs', owner: 'them');
    await share('theirs');

    final report = await service(const ServiceReportOptions());

    expect(report.noScheduleCount, 2);
  });

  test('a report with no gear is empty', () async {
    expect((await service(const ServiceReportOptions())).isEmpty, isTrue);
  });

  test('trip scope names the trip', () async {
    await item('reg');
    await trip('t1', packed: ['reg']);

    final report = await service(
      const ServiceReportOptions(scope: ServiceReportScope.trip, tripId: 't1'),
    );

    expect(report.scopeLabel, 'Bonaire');
    expect(report.noScheduleCount, 1);
  });

  test('trip scope keeps gear retired since the trip', () async {
    await item('old', status: 'retired', isActive: false);
    await trip('t1', packed: ['old']);

    final report = await service(
      const ServiceReportOptions(scope: ServiceReportScope.trip, tripId: 't1'),
    );

    expect(report.noScheduleCount, 1);
  });

  test("trip scope brings a retired assembly's installed part", () async {
    await item('set', status: 'retired', isActive: false);
    await item('first', parent: 'set');
    await record('first', cost: 10);
    await trip('t1', packed: ['set']);

    final report = await service(
      const ServiceReportOptions(scope: ServiceReportScope.trip, tripId: 't1'),
    );

    expect(report.history.single.item.id, 'first');
  });

  test('trip scope leaves wishlist gear out', () async {
    await item('wish', status: 'wanted', isActive: false);
    await trip('t1', packed: ['wish']);

    final report = await service(
      const ServiceReportOptions(scope: ServiceReportScope.trip, tripId: 't1'),
    );

    expect(report.isEmpty, isTrue);
  });

  test('a trip with no gear is empty', () async {
    await trip('t1', packed: const []);

    final report = await service(
      const ServiceReportOptions(scope: ServiceReportScope.trip, tripId: 't1'),
    );

    expect(report.isEmpty, isTrue);
  });

  test('one item on an assembly brings its parts', () async {
    await item('set');
    await item('first', parent: 'set');
    await item('other');
    await record('first', cost: 10);

    final report = await service(
      const ServiceReportOptions(scope: ServiceReportScope.item, itemId: 'set'),
    );

    expect(report.scopeLabel, 'set');
    expect(report.history.single.item.id, 'first');
    expect(report.noScheduleCount, 1);
  });

  test('one item leaves a wishlist part out', () async {
    await item('set');
    await item('wish', status: 'wanted', isActive: false, parent: 'set');
    await record('wish', cost: 10);

    final report = await service(
      const ServiceReportOptions(scope: ServiceReportScope.item, itemId: 'set'),
    );

    expect(report.history, isEmpty);
  });

  test('one item offers a retired item', () async {
    await item('old', status: 'retired', isActive: false);
    await record('old', cost: 10);

    final report = await service(
      const ServiceReportOptions(scope: ServiceReportScope.item, itemId: 'old'),
    );

    expect(report.history.single.item.id, 'old');
  });

  test('a shared item keeps its service cost', () async {
    await item('theirs', owner: 'them');
    await share('theirs');
    await record('theirs', cost: 75);

    final report = await service(const ServiceReportOptions());

    expect(report.history.single.rows.single.record.cost, 75);
  });

  test('history off skips the dive counts and blocks', () async {
    await item('a');
    await record('a', cost: 10);

    final report = await service(
      const ServiceReportOptions(includeHistory: false),
    );

    expect(report.history, isEmpty);
  });
}
