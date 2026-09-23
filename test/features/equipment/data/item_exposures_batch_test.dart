import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// [EquipmentRepository.getItemExposures] is [getItemExposure] for many
/// items at once. It must agree with the single-item lookup on every join
/// path, because the service clocks read one and the reminders the other.
void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(logStatements: true));
    DatabaseService.instance.setTestDatabase(db);
    repo = EquipmentRepository();
  });
  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  final t1 = DateTime.utc(2026, 1, 10).millisecondsSinceEpoch;
  final t2 = DateTime.utc(2026, 2, 10).millisecondsSinceEpoch;
  final t3 = DateTime.utc(2026, 3, 10).millisecondsSinceEpoch;

  Future<void> insertDive(String id, int dateMs, {String mode = 'oc'}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: dateMs,
          createdAt: dateMs,
          updatedAt: dateMs,
        ).copyWith(runtime: const Value(3600), diveMode: Value(mode)),
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
    String? serial,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(id: id, diveId: diveId).copyWith(
          o2Percent: Value(o2),
          tankRole: Value(role),
          equipmentId: Value(equipmentId),
          regulatorEquipmentId: Value(regulatorId),
          transmitterSerial: Value(serial),
        ),
      );

  Future<EquipmentItem> part(
    String name,
    EquipmentType type,
    String parentId, {
    required DateTime installed,
    int? slot,
    bool fitted = true,
  }) => repo.createEquipment(
    EquipmentItem(
      id: '',
      name: name,
      type: type,
      parentEquipmentId: parentId,
      status: fitted ? EquipmentStatus.active : EquipmentStatus.retired,
      isActive: fitted,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: '',
          key: EquipmentAttrKeys.installedDate,
          valueNum: installed.millisecondsSinceEpoch.toDouble(),
        ),
        if (slot != null)
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.cellSlot,
            valueNum: slot.toDouble(),
          ),
      ],
    ),
  );

  /// Every join path the single-item query has, one item per path.
  Future<List<EquipmentItem>> seedEveryPath() async {
    Future<EquipmentItem> make(String name, EquipmentType type) =>
        repo.createEquipment(EquipmentItem(id: '', name: name, type: type));

    await insertDive('d1', t1);
    await insertDive('d2', t2);
    await insertDive('d3', t3, mode: 'ccr');

    final mask = await make('Mask', EquipmentType.mask);
    await link('d1', mask.id);
    await link('d2', mask.id);

    final cylinder = await make('AL80', EquipmentType.tank);
    await tank('k1', 'd1', o2: 32, equipmentId: cylinder.id);

    final reg = await make('Reg', EquipmentType.regulator);
    await tank('k2', 'd2', regulatorId: reg.id);

    final ccr = await make('JJ', EquipmentType.rebreather);
    for (final d in ['d1', 'd2', 'd3']) {
      await link(d, ccr.id);
    }
    await tank('k3', 'd3', o2: 100, role: 'oxygenSupply');

    // Slot 1 was replaced on t2: the old cell stops there, the new one
    // starts there, and only the new one is fitted.
    final oldCell = await part(
      'Old cell',
      EquipmentType.o2Cell,
      ccr.id,
      installed: DateTime.utc(2026, 1, 1),
      slot: 1,
      fitted: false,
    );
    final newCell = await part(
      'New cell',
      EquipmentType.o2Cell,
      ccr.id,
      installed: DateTime.fromMillisecondsSinceEpoch(t2, isUtc: true),
      slot: 1,
    );
    final battery = await part(
      'Battery',
      EquipmentType.battery,
      ccr.id,
      installed: DateTime.utc(2026, 1, 1),
    );

    final tx = await make('Tx', EquipmentType.transmitter);
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO transmitters (id, diver_id, transmitter_serial, label, '
      'tank_role, transmitter_equipment_id, created_at, updated_at) VALUES '
      "('r1', 'me', '180777', 'Left', 'backGas', '${tx.id}', 1, 1)",
    );
    await tank('k4', 'd2', serial: ' 180777 ');

    final idle = await make('Spare fins', EquipmentType.fins);

    return [mask, cylinder, reg, ccr, oldCell, newCell, battery, tx, idle];
  }

  /// The comparable face of an exposure: records holding lists compare by
  /// identity, so flatten everything to values.
  Object shape(ItemExposure e) => [
    e.parent?.id,
    [for (final c in e.fittedChildren) c.id]..sort(),
    e.isRebreather,
    [
      for (final s in e.samples)
        [
          s.diveId,
          s.date,
          s.updatedAt,
          s.durationSeconds,
          s.diveMode,
          s.waterType,
          s.maxDepth,
          s.minTemperature,
          s.contactO2Fraction,
        ],
    ],
  ];

  test('agrees with the single-item lookup on every join path', () async {
    final items = await seedEveryPath();
    final batched = await repo.getItemExposures(items);

    expect(batched.keys.toSet(), {for (final i in items) i.id});
    for (final item in items) {
      final single = await repo.getItemExposure(item);
      expect(
        shape(batched[item.id]!),
        shape(single),
        reason: '${item.name} disagrees with getItemExposure',
      );
    }
  });

  test(
    'the fixture exercises each path, so agreement means something',
    () async {
      final items = await seedEveryPath();
      final byName = {for (final i in items) i.name: i};
      final batched = await repo.getItemExposures(items);
      List<String> dives(String name) => [
        for (final s in batched[byName[name]!.id]!.samples) s.diveId,
      ];

      expect(dives('Mask'), ['d1', 'd2']);
      expect(dives('AL80'), ['d1']);
      expect(dives('Reg'), ['d2']);
      expect(dives('JJ'), ['d1', 'd2', 'd3']);
      expect(dives('Old cell'), ['d1'], reason: 'trimmed at its successor');
      expect(dives('New cell'), ['d2', 'd3'], reason: 'from its install date');
      expect(dives('Tx'), ['d2']);
      expect(dives('Spare fins'), isEmpty);
      expect(batched[byName['JJ']!.id]!.samples.last.contactO2Fraction, 1.0);
      expect(
        [for (final c in batched[byName['JJ']!.id]!.fittedChildren) c.name]
          ..sort(),
        ['Battery', 'New cell'],
      );
    },
  );

  test('costs the same statements for one item as for many', () async {
    final items = await seedEveryPath();

    Future<int> statementsFor(List<EquipmentItem> subset) async {
      final logged = <String>[];
      await runZoned(
        () => repo.getItemExposures(subset),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logged.add(line),
        ),
      );
      return logged.where((l) => l.startsWith('Drift: Sent')).length;
    }

    // The rebreather alone already has parts, so it pays the children's
    // attribute read too: one item and nine differ only in item count.
    final one = await statementsFor([
      items.firstWhere((i) => i.type == EquipmentType.rebreather),
    ]);
    final all = await statementsFor(items);
    expect(all, one);
    // Parents outside the set, children, their attributes, the samples.
    expect(all, lessThanOrEqualTo(4));
  });

  test('items beyond one statement still get their own samples', () async {
    // The owners go to SQL 200 at a time; a dropped or misaligned tail
    // chunk would leave the last items reading as never dived.
    await insertDive('d1', t1);
    await insertDive('d2', t2);
    final ids = [
      for (var i = 0; i < 201; i++) 'gear-${i.toString().padLeft(3, '0')}',
    ];
    await db.batch((b) {
      b.insertAll(db.equipment, [
        for (final id in ids)
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'mask',
            createdAt: 1,
            updatedAt: 1,
          ),
      ]);
      b.insertAll(db.diveEquipment, [
        for (final id in ids)
          DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: id),
        DiveEquipmentCompanion.insert(diveId: 'd2', equipmentId: ids.last),
      ]);
    });
    final items = await repo.getEquipmentByIds(ids);

    final batched = await repo.getItemExposures(items);

    List<String> dives(String id) => [
      for (final s in batched[id]!.samples) s.diveId,
    ];
    expect(batched, hasLength(201));
    expect(dives(ids.first), ['d1']);
    expect(dives(ids[199]), ['d1']);
    expect(dives(ids.last), ['d1', 'd2']);
  });

  test(
    'an unknown dive mode reads as open circuit, as the single query does',
    () async {
      await insertDive('d1', t1, mode: 'not-a-mode');
      final mask = await repo.createEquipment(
        const EquipmentItem(id: '', name: 'Mask', type: EquipmentType.mask),
      );
      await link('d1', mask.id);

      final batched = await repo.getItemExposures([mask]);
      final single = await repo.getItemExposure(mask);

      expect(batched[mask.id]!.samples.single.diveMode, DiveMode.oc);
      expect(shape(batched[mask.id]!), shape(single));
    },
  );

  test('a failed read throws rather than reading as no wear', () async {
    // Swallowing it would hand every clock an empty dive list, so gear
    // would look less worn than it is: the unsafe direction.
    final mask = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Mask', type: EquipmentType.mask),
    );
    await db.customStatement('DROP TABLE dive_sensor_summaries');

    await expectLater(repo.getItemExposures([mask]), throwsA(anything));
  });

  test('an empty list reads nothing', () async {
    expect(await repo.getItemExposures(const []), isEmpty);
  });
}
