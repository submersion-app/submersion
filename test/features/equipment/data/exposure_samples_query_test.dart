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
    int runtime = 3600,
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
}
