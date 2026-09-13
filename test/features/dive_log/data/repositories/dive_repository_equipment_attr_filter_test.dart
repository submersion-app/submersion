import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repo;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> insertItem(
    String id,
    EquipmentType type, {
    required String key,
    String? text,
    double? num,
  }) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion(
            id: Value(id),
            name: Value(id),
            type: Value(type.name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion(
            id: Value('attr_${id}_$key'),
            equipmentId: Value(id),
            attrKey: Value(key),
            valueText: Value(text),
            valueNum: Value(num),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> linkGear(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion(
          diveId: Value(diveId),
          equipmentId: Value(equipmentId),
        ),
      );

  Future<Set<String>> listIds(DiveFilterState filter) async =>
      (await repo.getDiveSummaries(filter: filter)).map((s) => s.id).toSet();

  /// Three dives: a 7 mm suit, a 3 mm suit, and bare.
  Future<void> seedSuits() async {
    for (final d in ['suit7', 'suit3', 'bare']) {
      await insertDive(d);
    }
    await insertItem('w7', EquipmentType.wetsuit, key: 'thickness_mm', num: 7);
    await insertItem('w3', EquipmentType.wetsuit, key: 'thickness_mm', num: 3);
    await linkGear('suit7', 'w7');
    await linkGear('suit3', 'w3');
  }

  // A cylinder matched by the transmitter registry: linked through
  // dive_tanks.equipment_id only, never through dive_equipment.
  Future<void> linkTank(String diveId, String equipmentId) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value('tank-$diveId'),
          diveId: Value(diveId),
          equipmentId: Value(equipmentId),
        ),
      );

  test(
    'the paginated list and its count apply the suit thickness filter',
    () async {
      await seedSuits();
      final filter = DiveFilterState(
        equipmentAttrConditions: [
          EquipmentAttrCondition.suitThickness(min: 5.0),
        ],
      );
      expect(await listIds(filter), {'suit7'});
      expect(await repo.getDiveCount(filter: filter), 1);
    },
  );

  test('the paginated list filters by hose type', () async {
    await insertDive('hp');
    await insertDive('lp');
    await insertItem('h1', EquipmentType.hose, key: 'hose_type', text: 'hp');
    await insertItem('h2', EquipmentType.hose, key: 'hose_type', text: 'lp');
    await linkGear('hp', 'h1');
    await linkGear('lp', 'h2');
    const filter = DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(
          key: 'hose_type',
          choices: {'hp'},
          types: {EquipmentType.hose},
        ),
      ],
    );
    expect(await listIds(filter), {'hp'});
    expect(await repo.getDiveCount(filter: filter), 1);
  });

  test('the paginated list matches a registry-linked cylinder', () async {
    await insertDive('steel');
    await insertDive('alu');
    await insertItem(
      't1',
      EquipmentType.tank,
      key: 'tank_material',
      text: 'steel',
    );
    await insertItem(
      't2',
      EquipmentType.tank,
      key: 'tank_material',
      text: 'aluminum',
    );
    await linkTank('steel', 't1');
    await linkTank('alu', 't2');
    const filter = DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(
          key: 'tank_material',
          choices: {'steel'},
          types: {EquipmentType.tank},
        ),
      ],
    );
    expect(await listIds(filter), {'steel'});
  });

  test('Statistics, the list and the id query select the same dives', () async {
    await seedSuits();
    await insertDive('steel');
    await insertItem(
      't1',
      EquipmentType.tank,
      key: 'tank_material',
      text: 'steel',
    );
    await linkTank('steel', 't1');
    for (final conditions in [
      [EquipmentAttrCondition.suitThickness(min: 5.0)],
      [
        const EquipmentAttrCondition(
          key: 'tank_material',
          choices: {'steel'},
          types: {EquipmentType.tank},
        ),
      ],
    ]) {
      final filter = DiveFilterState(equipmentAttrConditions: conditions);
      final stats = buildFilteredDiveIdSubquery(filter);
      final statsIds =
          (await db
                  .customSelect(
                    stats.subquery,
                    variables: stats.params
                        .map((p) => Variable<Object>(p!))
                        .toList(),
                  )
                  .get())
              .map((r) => r.read<String>('id'))
              .toSet();
      final listed = await listIds(filter);
      final resolved = await repo.getDiveIdsMatchingEquipmentAttrs(conditions);
      expect(statsIds, isNotEmpty, reason: '$conditions');
      expect(listed, statsIds, reason: '$conditions');
      expect(resolved, statsIds, reason: '$conditions');
    }
  });

  test('the filter tick fires on an attribute-only write', () async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion(
            id: const Value('h'),
            name: const Value('h'),
            type: const Value('hose'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final events = <void>[];
    final sub = repo.watchEquipmentAttrFilterChanges().listen(events.add);
    addTearDown(sub.cancel);
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion(
            id: const Value('attr_h_hose_type'),
            equipmentId: const Value('h'),
            attrKey: const Value('hose_type'),
            valueText: const Value('hp'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 200),
    );
    expect(events, isNotEmpty);
  });
}
