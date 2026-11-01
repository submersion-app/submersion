import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_usage_repository.dart';
import 'package:submersion/features/equipment/domain/reports/cost_of_ownership.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentUsageRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = EquipmentUsageRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'them',
            name: 'them',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<void> item(String id) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'other',
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> dive(
    String id, {
    int day = 1,
    int? runtime,
    int? bottomTime,
    bool excluded = false,
    bool planned = false,
    String diver = 'me',
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: DateTime.utc(2026, 1, day).millisecondsSinceEpoch,
          createdAt: 1,
          updatedAt: 1,
          diverId: Value(diver),
          runtime: Value(runtime),
          bottomTime: Value(bottomTime),
          excludedFromStats: Value(excluded),
          isPlanned: Value(planned),
        ),
      );

  Future<void> link(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: equipmentId),
      );

  Future<void> tank(
    String id,
    String diveId, {
    String? cylinder,
    String? regulator,
    String? extras,
    String? serial,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(id: id, diveId: diveId).copyWith(
          equipmentId: Value(cylinder),
          regulatorEquipmentId: Value(regulator),
          extraRegulatorIds: Value(extras),
          transmitterSerial: Value(serial),
        ),
      );

  group('getUsageTotals', () {
    test(
      'gear linked only through a tank counts a dive and its hours',
      () async {
        await item('al80');
        await dive('d1', runtime: 3600);
        await tank('k1', 'd1', cylinder: 'al80');

        final usage = await repository.getUsageTotals(diverId: 'me');
        expect(usage['al80'], const GearUsageTotals(diveCount: 1, hours: 1));
      },
    );

    test('a tank regulator and an extra regulator count', () async {
      await item('r1');
      await item('r2');
      await dive('d1', runtime: 1800);
      await tank('k1', 'd1', regulator: 'r1', extras: '["r2"]');

      final usage = await repository.getUsageTotals(diverId: 'me');
      expect(usage['r1']?.diveCount, 1);
      expect(usage['r2']?.diveCount, 1);
    });

    test('a registered transmitter serial counts', () async {
      await item('tx');
      await dive('d1', runtime: 1800);
      await tank('k1', 'd1', serial: 'A1');
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: 't1',
              label: 't1',
              tankRole: 'backGas',
              createdAt: 1,
              updatedAt: 1,
              diverId: const Value('me'),
              transmitterSerial: const Value('A1'),
              transmitterEquipmentId: const Value('tx'),
            ),
          );

      final usage = await repository.getUsageTotals(diverId: 'me');
      expect(usage['tx']?.diveCount, 1);
    });

    test('a dive linked three ways counts once, hours once', () async {
      await item('reg');
      await dive('d1', runtime: 3600);
      await link('d1', 'reg');
      await tank('k1', 'd1', regulator: 'reg');
      await tank('k2', 'd1', regulator: 'reg');

      final usage = await repository.getUsageTotals(diverId: 'me');
      expect(usage['reg'], const GearUsageTotals(diveCount: 1, hours: 1));
    });

    test(
      'runtime wins, then bottom time, zero runtime falls through',
      () async {
        await item('a');
        await dive('d1', runtime: 3600, bottomTime: 1800);
        await dive('d2', runtime: 0, bottomTime: 1800);
        await dive('d3');
        await link('d1', 'a');
        await link('d2', 'a');
        await link('d3', 'a');

        final usage = await repository.getUsageTotals(diverId: 'me');
        expect(usage['a'], const GearUsageTotals(diveCount: 3, hours: 1.5));
      },
    );

    test('excluded and planned dives are left out', () async {
      await item('a');
      await dive('d1', runtime: 3600);
      await dive('d2', runtime: 3600, excluded: true);
      await dive('d3', runtime: 3600, planned: true);
      await link('d1', 'a');
      await link('d2', 'a');
      await link('d3', 'a');

      final usage = await repository.getUsageTotals(diverId: 'me');
      expect(usage['a']?.diveCount, 1);
    });

    test("another diver's dives are left out", () async {
      await item('a');
      await dive('d1', runtime: 3600, diver: 'them');
      await link('d1', 'a');

      expect(await repository.getUsageTotals(diverId: 'me'), isEmpty);
    });
  });

  group('getLastDiveDates', () {
    test('keeps an excluded dive and drops a planned one', () async {
      await item('a');
      await dive('d1', day: 1);
      await dive('d2', day: 2, excluded: true);
      await dive('d3', day: 3, planned: true);
      await link('d1', 'a');
      await link('d2', 'a');
      await link('d3', 'a');

      final last = await repository.getLastDiveDates(diverId: 'me');
      expect(last['a'], DateTime.utc(2026, 1, 2));
    });

    test('reads as the wall clock, flagged UTC', () async {
      await item('a');
      await dive('d1', day: 5);
      await link('d1', 'a');

      final last = await repository.getLastDiveDates(diverId: 'me');
      expect(last['a']!.isUtc, isTrue);
      expect(last['a']!.day, 5);
    });
  });

  group('getStatsDiveCount', () {
    test('counts only dives that count toward statistics', () async {
      await dive('d1');
      await dive('d2', excluded: true);
      await dive('d3', planned: true);
      await dive('d4', diver: 'them');

      expect(await repository.getStatsDiveCount(diverId: 'me'), 1);
    });
  });

  test('watchChanges fires when a gear link changes', () async {
    await item('a');
    await dive('d1');
    final tick = expectLater(repository.watchChanges(), emits(anything));
    await link('d1', 'a');
    await tick;
  });
}
