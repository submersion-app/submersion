import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/loaded_service_clocks.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../../helpers/test_database.dart';

/// A planned dive has not happened, so it has put no wear on the gear linked
/// to it (issue #3932). An actual dive left out of statistics still has, so
/// only the plan drops out: the item page's rows, the exposure both queries
/// read and the clocks that exposure drives all describe real use.
void main() {
  late AppDatabase db;
  late EquipmentRepository repo;
  late EquipmentItem item;

  final actualDate = DateTime.utc(2026, 10, 30, 9);
  final planDate = DateTime.utc(2026, 11, 30, 9);
  final now = DateTime.utc(2026, 10, 30, 12);

  Future<void> addDive(
    String id,
    DateTime date, {
    bool planned = false,
    bool excludedFromStats = false,
    String? tripId,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: date.millisecondsSinceEpoch,
          createdAt: 1,
          updatedAt: 1,
        ).copyWith(
          runtime: const Value(3600),
          isPlanned: Value(planned),
          excludedFromStats: Value(excludedFromStats),
          tripId: Value(tripId),
        ),
      );

  Future<void> link(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: equipmentId),
      );

  Future<void> addTrip(String id) => db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: id,
          name: id,
          startDate: 1,
          endDate: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  /// Item-page exposure and the list-wide read, which must agree (their SQL
  /// is written twice).
  Future<List<List<String>>> exposedDiveIds(EquipmentItem of) async {
    final single = await repo.getItemExposure(of);
    final batched = await repo.getItemExposures([of]);
    return [
      [for (final s in single.samples) s.diveId],
      [for (final s in batched[of.id]!.samples) s.diveId],
    ];
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    item = await repo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Regulator',
        type: EquipmentType.regulator,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  test('the Dives and Dive Time rows leave a plan out', () async {
    await addDive('actual', actualDate);
    await addDive('plan', planDate, planned: true);
    await link('actual', item.id);
    await link('plan', item.id);

    expect(await repo.getDiveCountForEquipment(item.id), 1);
    expect(await repo.getDiveTimeForEquipment(item.id), 3600);
  });

  test(
    'a plan never carried out does not count once its date passes',
    () async {
      await addDive(
        'late',
        actualDate.subtract(const Duration(days: 7)),
        planned: true,
      );
      await link('late', item.id);

      expect(await repo.getDiveCountForEquipment(item.id), 0);
      expect(await repo.getDiveTimeForEquipment(item.id), 0);
      expect(await exposedDiveIds(item), [<String>[], <String>[]]);
    },
  );

  test('a dive excluded from statistics still wears the item', () async {
    await addDive('practice', actualDate, excludedFromStats: true);
    await addDive('plan', planDate, planned: true);
    await link('practice', item.id);
    await link('plan', item.id);

    expect(await repo.getDiveCountForEquipment(item.id), 1);
    expect(await repo.getDiveTimeForEquipment(item.id), 3600);
    expect(await exposedDiveIds(item), [
      ['practice'],
      ['practice'],
    ]);
  });

  test('exposure leaves a plan out on every link path', () async {
    await addDive('actual', actualDate);
    await link('actual', item.id);

    await addDive('listed', planDate, planned: true);
    await link('listed', item.id);

    await addDive('cylinder', planDate, planned: true);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k1',
            diveId: 'cylinder',
          ).copyWith(equipmentId: Value(item.id)),
        );

    await addDive('first-regulator', planDate, planned: true);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k2',
            diveId: 'first-regulator',
          ).copyWith(regulatorEquipmentId: Value(item.id)),
        );

    await addDive('extra-regulator', planDate, planned: true);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k3',
            diveId: 'extra-regulator',
          ).copyWith(extraRegulatorIds: Value('["${item.id}"]')),
        );

    await addDive('transmitted', planDate, planned: true);
    await db.customStatement(
      'INSERT INTO transmitters (id, transmitter_serial, label, tank_role, '
      'transmitter_equipment_id, created_at, updated_at) VALUES '
      "('r1', '180777', 'Left', 'backGas', '${item.id}', 1, 1)",
    );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k4',
            diveId: 'transmitted',
          ).copyWith(transmitterSerial: const Value('180777')),
        );

    expect(await repo.getDiveCountForEquipment(item.id), 1);
    expect(await exposedDiveIds(item), [
      ['actual'],
      ['actual'],
    ]);
  });

  test('a part does not inherit its parent\'s planned dives', () async {
    final part = await repo.createEquipment(
      EquipmentItem(
        id: '',
        name: 'First stage',
        type: EquipmentType.regulator,
        parentEquipmentId: item.id,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.installedDate,
            valueNum: DateTime.utc(2026).millisecondsSinceEpoch.toDouble(),
          ),
        ],
      ),
    );
    await addDive('actual', actualDate);
    await addDive('plan', planDate, planned: true);
    await link('actual', item.id);
    await link('plan', item.id);

    expect(await exposedDiveIds(part), [
      ['actual'],
      ['actual'],
    ]);
  });

  test('a plan counts as soon as it is logged', () async {
    await addDive('plan', planDate, planned: true);
    await link('plan', item.id);
    expect(await repo.getDiveCountForEquipment(item.id), 0);

    await (db.update(db.dives)..where((t) => t.id.equals('plan'))).write(
      const DivesCompanion(isPlanned: Value(false)),
    );

    expect(await repo.getDiveCountForEquipment(item.id), 1);
    expect(await repo.getDiveTimeForEquipment(item.id), 3600);
    expect(await exposedDiveIds(item), [
      ['plan'],
      ['plan'],
    ]);
  });

  test('the History card leaves a plan out', () async {
    await addDive('actual', actualDate);
    await addDive('plan', planDate, planned: true);
    await link('actual', item.id);
    await link('plan', item.id);

    final usage = await repo.getUsageByDiver(item);

    expect([for (final u in usage) u.diveId], ['actual']);
  });

  test('the Trips row reads the trips the item has been used on', () async {
    await addTrip('been');
    await addTrip('upcoming');
    await addDive('actual', actualDate, tripId: 'been');
    await addDive('plan', planDate, planned: true, tripId: 'upcoming');
    await link('actual', item.id);
    await link('plan', item.id);

    expect(await repo.getTripCountForEquipment(item.id), 1);
    expect(await repo.getTripIdsForEquipment(item.id), ['been']);
  });

  test(
    'the Trips row reaches a trip through a tank, as the Dives row does',
    () async {
      await addTrip('been');
      await addDive('actual', actualDate, tripId: 'been');
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 'k1',
              diveId: 'actual',
            ).copyWith(regulatorEquipmentId: Value(item.id)),
          );

      expect(await repo.getDiveCountForEquipment(item.id), 1);
      expect(await repo.getTripCountForEquipment(item.id), 1);
      expect(await repo.getTripIdsForEquipment(item.id), ['been']);
    },
  );

  test('the Trips row refreshes when a plan on the trip is logged', () async {
    await addTrip('upcoming');
    await addDive('plan', planDate, planned: true, tripId: 'upcoming');
    await link('plan', item.id);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final count = container.listen(
      equipmentTripCountProvider(item.id),
      (_, _) {},
    );
    addTearDown(count.close);
    final ids = container.listen(equipmentTripIdsProvider(item.id), (_, _) {});
    addTearDown(ids.close);
    expect(await container.read(equipmentTripCountProvider(item.id).future), 0);
    expect(await container.read(equipmentTripIdsProvider(item.id).future), []);

    await (db.update(db.dives)..where((t) => t.id.equals('plan'))).write(
      const DivesCompanion(isPlanned: Value(false)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(await container.read(equipmentTripCountProvider(item.id).future), 1);
    expect(await container.read(equipmentTripIdsProvider(item.id).future), [
      'upcoming',
    ]);
  });

  group('a two-dive service clock', () {
    final kind = ServiceKind(
      id: 'kind',
      name: 'Service',
      createdAt: actualDate,
      updatedAt: actualDate,
    );
    final schedule = ServiceSchedule(
      id: 'clock',
      equipmentId: '',
      serviceKindId: 'kind',
      intervalDives: 2,
      anchorDate: DateTime.utc(2026, 10),
      createdAt: actualDate,
      updatedAt: actualDate,
    );

    ServiceClockStatus evaluate(ItemExposure exposure) =>
        evaluateLoadedServiceClocks(
          item,
          schedules: [schedule.copyWith(equipmentId: item.id)],
          kindsById: {'kind': kind},
          records: const [],
          exposure: exposure,
          thresholds: ExposureThresholds.defaults,
          dueSoonWindowDays: 30,
          now: now,
        ).single;

    test('a plan linked to the item does not make it overdue', () async {
      await addDive('actual', actualDate);
      await addDive('plan', planDate, planned: true);
      await link('actual', item.id);
      await link('plan', item.id);

      final single = evaluate(await repo.getItemExposure(item));
      final batched = evaluate((await repo.getItemExposures([item]))[item.id]!);

      for (final clock in [single, batched]) {
        expect(clock.severity, ServiceClockSeverity.dueSoon);
        expect(clock.usageByUnit.values.single.since, 1);
      }
    });

    test('the logged dive that reaches the limit does', () async {
      await addDive('first', actualDate);
      await addDive('second', actualDate.add(const Duration(hours: 1)));
      await link('first', item.id);
      await link('second', item.id);

      final clock = evaluate(await repo.getItemExposure(item));

      expect(clock.severity, ServiceClockSeverity.overdue);
    });
  });
}
