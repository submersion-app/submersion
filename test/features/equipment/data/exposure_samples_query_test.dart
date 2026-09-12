import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(
    String id, {
    required int dateMs,
    int? runtime = 3600,
    int? bottomTime,
    String mode = 'oc',
    String? waterType,
    double? maxDepth,
    double? waterTemp,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: dateMs,
          createdAt: dateMs,
          updatedAt: dateMs,
        ).copyWith(
          runtime: Value(runtime),
          bottomTime: Value(bottomTime),
          diveMode: Value(mode),
          waterType: Value(waterType),
          maxDepth: Value(maxDepth),
          waterTemp: Value(waterTemp),
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
    double o2 = 21,
    String role = 'backGas',
    String? equipmentId,
    String? regulatorId,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(id: id, diveId: diveId).copyWith(
          o2Percent: Value(o2),
          tankRole: Value(role),
          equipmentId: Value(equipmentId),
          regulatorEquipmentId: Value(regulatorId),
        ),
      );

  final t1 = DateTime.utc(2026, 1, 10).millisecondsSinceEpoch;
  final t2 = DateTime.utc(2026, 2, 10).millisecondsSinceEpoch;
  final t3 = DateTime.utc(2026, 3, 10).millisecondsSinceEpoch;

  test('dive header fields ride on the sample', () async {
    final mask = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Mask', type: EquipmentType.mask),
    );
    await insertDive(
      'd1',
      dateMs: t1,
      runtime: 2700,
      mode: 'ccr',
      waterType: 'salt',
      maxDepth: 42.5,
      waterTemp: 7.0,
    );
    await link('d1', mask.id);

    final s = (await repo.getExposureSamplesForEquipment(mask.id)).single;
    expect(s.date, DateTime.fromMillisecondsSinceEpoch(t1, isUtc: true));
    expect(s.durationSeconds, 2700);
    expect(s.diveMode, DiveMode.ccr);
    expect(s.waterType, WaterType.salt);
    expect(s.maxDepth, 42.5);
    expect(s.minTemperature, 7.0);
    expect(s.contactO2Fraction, isNull, reason: 'a mask touches no gas');
  });

  test(
    'the length is the first positive of runtime, then bottom time',
    () async {
      // A hand-logged dive can store a zero runtime beside a real bottom
      // time. Counting it as zero hours would push a service interval later
      // than the gear's real use, so the next positive figure stands in, as
      // the trip history reads it.
      final reg = await repo.createEquipment(
        const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
      );
      final lengths = {
        'zero': (0, 2400),
        'negative': (-60, 1200),
        'null': (null, 1800),
        'runtime': (3000, 2400),
        'neither': (0, null),
      };
      var day = 1;
      for (final MapEntry(key: id, value: (runtime, bottom))
          in lengths.entries) {
        await insertDive(
          id,
          dateMs: DateTime.utc(2026, 4, day++).millisecondsSinceEpoch,
          runtime: runtime,
          bottomTime: bottom,
        );
        await link(id, reg.id);
      }

      final samples = await repo.getExposureSamplesForEquipment(reg.id);
      expect(
        {for (final s in samples) s.diveId: s.durationSeconds},
        {
          'zero': 2400,
          'negative': 1200,
          'null': 1800,
          'runtime': 3000,
          'neither': 0,
        },
      );
    },
  );

  test(
    'a tank item, a regulator and a rebreather each see their gas',
    () async {
      final cylinder = await repo.createEquipment(
        const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank),
      );
      final reg = await repo.createEquipment(
        const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
      );
      final unit = await repo.createEquipment(
        const EquipmentItem(id: '', name: 'JJ', type: EquipmentType.rebreather),
      );
      await insertDive('d1', dateMs: t1, mode: 'ccr');
      await tank(
        't-back',
        'd1',
        o2: 21,
        equipmentId: cylinder.id,
        regulatorId: reg.id,
      );
      await tank('t-deco', 'd1', o2: 80, regulatorId: reg.id);
      await tank('t-dil', 'd1', o2: 18, role: 'diluent');
      await tank('t-o2', 'd1', o2: 100, role: 'oxygenSupply');
      await link('d1', unit.id);

      expect(
        (await repo.getExposureSamplesForEquipment(
          cylinder.id,
        )).single.contactO2Fraction,
        closeTo(0.21, 1e-9),
      );
      expect(
        (await repo.getExposureSamplesForEquipment(
          reg.id,
        )).single.contactO2Fraction,
        closeTo(0.80, 1e-9),
        reason: 'the regulator takes the max over the cylinders naming it',
      );
      expect(
        (await repo.getExposureSamplesForEquipment(
          unit.id,
          rebreatherContact: true,
        )).single.contactO2Fraction,
        closeTo(1.0, 1e-9),
      );
    },
  );

  test(
    'a CCR dive with no supply cylinders still counts as O2 contact',
    () async {
      final unit = await repo.createEquipment(
        const EquipmentItem(id: '', name: 'JJ', type: EquipmentType.rebreather),
      );
      await insertDive('d1', dateMs: t1, mode: 'ccr');
      await link('d1', unit.id);
      expect(
        (await repo.getExposureSamplesForEquipment(
          unit.id,
          rebreatherContact: true,
        )).single.contactO2Fraction,
        1.0,
      );
      await insertDive('d2', dateMs: t2, mode: 'oc');
      await link('d2', unit.id);
      final byDate = await repo.getExposureSamplesForEquipment(
        unit.id,
        rebreatherContact: true,
      );
      expect(byDate.last.contactO2Fraction, isNull);
    },
  );

  test('a child inherits the parent dives from its install date', () async {
    final unit = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'JJ', type: EquipmentType.rebreather),
    );
    await insertDive('d1', dateMs: t1);
    await insertDive('d2', dateMs: t2);
    await insertDive('d3', dateMs: t3);
    for (final d in ['d1', 'd2', 'd3']) {
      await link(d, unit.id);
    }
    final samples = await repo.getExposureSamplesForEquipment(
      'cell-1',
      parentEquipmentId: unit.id,
      installedSince: DateTime.fromMillisecondsSinceEpoch(t2, isUtc: true),
    );
    expect(samples.map((s) => s.date.millisecondsSinceEpoch), [t2, t3]);
  });

  test('only a current summary overrides the dive header', () async {
    // A summary whose source stamp no longer matches the dive, or from an
    // older algorithm, is stale: the sweep will rebuild it, and until
    // then the header's depth and temperature are the truth.
    final mask = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Mask', type: EquipmentType.mask),
    );
    Future<void> summarised(
      String id, {
      required int sourceUpdatedAt,
      int engineVersion = 1,
    }) => db
        .into(db.diveSensorSummaries)
        .insert(
          DiveSensorSummariesCompanion.insert(
            diveId: id,
            engineVersion: engineVersion,
            sourceUpdatedAt: sourceUpdatedAt,
            computedAt: 1,
          ).copyWith(
            maxDepth: const Value(40.0),
            minTemperature: const Value(5.0),
          ),
        );
    await insertDive('current', dateMs: t1, maxDepth: 30, waterTemp: 12);
    await insertDive('edited', dateMs: t1 + 1, maxDepth: 30, waterTemp: 12);
    await insertDive('older', dateMs: t1 + 2, maxDepth: 30, waterTemp: 12);
    for (final id in ['current', 'edited', 'older']) {
      await link(id, mask.id);
    }
    await summarised('current', sourceUpdatedAt: t1);
    // The dive changed after its summary was built.
    await summarised('edited', sourceUpdatedAt: t1 - 5);
    await summarised('older', sourceUpdatedAt: t1 + 2, engineVersion: 0);

    final byDive = {
      for (final s in await repo.getExposureSamplesForEquipment(mask.id))
        s.diveId: s,
    };
    expect(byDive['current']!.maxDepth, 40.0);
    expect(byDive['current']!.minTemperature, 5.0);
    expect(byDive['edited']!.maxDepth, 30.0);
    expect(byDive['edited']!.minTemperature, 12.0);
    expect(byDive['older']!.maxDepth, 30.0);
  });

  test('a dive linked three ways is one sample', () async {
    final cylinder = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'AL80', type: EquipmentType.tank),
    );
    await insertDive('d1', dateMs: t1);
    await link('d1', cylinder.id);
    await tank('t1', 'd1', o2: 32, equipmentId: cylinder.id);
    await tank('t2', 'd1', o2: 36, regulatorId: cylinder.id);
    final samples = await repo.getExposureSamplesForEquipment(cylinder.id);
    expect(samples, hasLength(1));
    expect(samples.single.contactO2Fraction, closeTo(0.36, 1e-9));
  });

  test(
    'a transmitter item has the dives its registered serials were on',
    () async {
      // The registry links a transmitter to the gear item it is; that link
      // writes no dive_equipment row, so the item's dives are the tanks that
      // carried one of its serials. Only its diver's, and a blank or all-zero
      // serial matches nothing.
      final tx = await repo.createEquipment(
        const EquipmentItem(
          id: '',
          name: 'Tx',
          type: EquipmentType.transmitter,
        ),
      );
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('me', 'Me', 1, 1), ('buddy', 'Buddy', 1, 1)",
      );
      await db.customStatement(
        'INSERT INTO transmitters (id, diver_id, transmitter_serial, label, '
        'tank_role, transmitter_equipment_id, created_at, updated_at) VALUES '
        "('r1', 'me', ' 180777 ', 'Left', 'backGas', '${tx.id}', 1, 1), "
        "('r2', 'me', '000', 'Unset', 'backGas', '${tx.id}', 1, 1)",
      );
      for (final (id, date, diver) in [
        ('mine', t1, 'me'),
        ('logged', t2, 'me'),
        ('buddys', t3, 'buddy'),
        ('zeros', DateTime.utc(2026, 4, 10).millisecondsSinceEpoch, 'me'),
      ]) {
        await insertDive(id, dateMs: date);
        await db.customStatement(
          "UPDATE dives SET diver_id = '$diver' WHERE id = '$id'",
        );
      }
      await db.customStatement(
        'INSERT INTO dive_tanks (id, dive_id, transmitter_serial) VALUES '
        "('a', 'mine', '180777'), ('b', 'logged', '180777 '), "
        "('c', 'buddys', '180777'), ('z', 'zeros', '000')",
      );
      // Also logged as dive gear: still one sample.
      await link('logged', tx.id);

      final samples = await repo.getExposureSamplesForEquipment(tx.id);
      expect(samples.map((s) => s.diveId), ['mine', 'logged']);
    },
  );

  test('the samples come from exactly one statement', () async {
    await tearDownTestDatabase();
    db = AppDatabase(NativeDatabase.memory(logStatements: true));
    DatabaseService.instance.setTestDatabase(db);
    repo = EquipmentRepository();
    final reg = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    await insertDive('d1', dateMs: t1);
    await tank('t1', 'd1', regulatorId: reg.id);

    final logged = <String>[];
    await runZoned(
      () => repo.getExposureSamplesForEquipment(
        reg.id,
        parentEquipmentId: 'none',
        rebreatherContact: true,
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    // drift prints one "Drift: Sent ..." entry per statement; the zone hands
    // a multi-line statement over line by line, so count the prefix.
    expect(logged.where((l) => l.startsWith('Drift: Sent')), hasLength(1));
  });

  test('every sample names its dive and carries the dive stamp', () async {
    final reg = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    await insertDive('d1', dateMs: 1000);
    await insertDive('d2', dateMs: 2000);
    await link('d1', reg.id);
    await link('d2', reg.id);
    final samples = await repo.getExposureSamplesForEquipment(reg.id);
    expect(samples.map((s) => s.diveId), ['d1', 'd2']);
    // insertDive stamps updated_at with the dive date.
    expect(samples.map((s) => s.updatedAt), [1000, 2000]);
  });
}
