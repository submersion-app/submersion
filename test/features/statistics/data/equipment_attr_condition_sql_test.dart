import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
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
    String? key,
    String? text,
    double? num,
    bool custom = false,
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
    if (key == null) return;
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion(
            id: Value('attr_${id}_$key'),
            equipmentId: Value(id),
            attrKey: Value(key),
            isCustom: Value(custom),
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

  Future<Set<String>> idsMatching(
    List<EquipmentAttrCondition> conditions,
  ) async {
    final parts = [
      for (final c in conditions)
        equipmentAttrConditionSql(c, diveIdRef: 'dives.id'),
    ];
    final rows = await db
        .customSelect(
          'SELECT id FROM dives WHERE ${parts.map((p) => p.sql).join(' AND ')}',
          variables: [
            for (final p in parts) ...p.params.map((v) => Variable<Object>(v)),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  const hp = EquipmentAttrCondition(
    key: 'hose_type',
    choices: {'hp'},
    types: {EquipmentType.hose},
  );

  test('binds every value in placeholder order', () {
    final result = equipmentAttrConditionSql(
      const EquipmentAttrCondition(
        key: 'k',
        choices: {'b', 'a'},
        min: 1,
        max: 2,
        types: {EquipmentType.hose, EquipmentType.bcd},
      ),
      diveIdRef: 'd.id',
    );
    expect(result.params, ['bcd', 'hose', 'k', 'a', 'b', 1.0, 2.0]);
    expect(result.sql, contains('de.dive_id = d.id'));
    expect(result.sql, contains('dt.dive_id = d.id'));
    expect(result.sql, isNot(contains("'hose'")));
  });

  test('a choice matches gear linked through dive_equipment', () async {
    for (final d in ['d1', 'd2', 'd3']) {
      await insertDive(d);
    }
    await insertItem(
      'hpHose',
      EquipmentType.hose,
      key: 'hose_type',
      text: 'hp',
    );
    await insertItem(
      'lpHose',
      EquipmentType.hose,
      key: 'hose_type',
      text: 'lp',
    );
    await linkGear('d1', 'hpHose');
    await linkGear('d2', 'lpHose');
    expect(await idsMatching([hp]), {'d1'});
  });

  test('choices are ORed', () async {
    for (final d in ['d1', 'd2', 'd3']) {
      await insertDive(d);
    }
    await insertItem('a', EquipmentType.hose, key: 'hose_type', text: 'hp');
    await insertItem('b', EquipmentType.hose, key: 'hose_type', text: 'lpi');
    await insertItem('c', EquipmentType.hose, key: 'hose_type', text: 'lp');
    await linkGear('d1', 'a');
    await linkGear('d2', 'b');
    await linkGear('d3', 'c');
    expect(
      await idsMatching([
        const EquipmentAttrCondition(key: 'hose_type', choices: {'hp', 'lpi'}),
      ]),
      {'d1', 'd2'},
    );
  });

  test('a registry-linked cylinder matches through dive_tanks', () async {
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
    expect(
      await idsMatching([
        const EquipmentAttrCondition(
          key: 'tank_material',
          choices: {'steel'},
          types: {EquipmentType.tank},
        ),
      ]),
      {'steel'},
    );
  });

  test('suit thickness skips hoods and rows with no number', () async {
    for (final d in ['suit', 'hood', 'legacy']) {
      await insertDive(d);
    }
    await insertItem('w', EquipmentType.wetsuit, key: 'thickness_mm', num: 5);
    await insertItem('h', EquipmentType.hood, key: 'thickness_mm', num: 5);
    await insertItem(
      'l',
      EquipmentType.wetsuit,
      key: 'thickness_mm',
      text: 'thin',
    );
    await linkGear('suit', 'w');
    await linkGear('hood', 'h');
    await linkGear('legacy', 'l');
    expect(
      await idsMatching([EquipmentAttrCondition.suitThickness(min: 4, max: 6)]),
      {'suit'},
    );
  });

  test('custom rows never match', () async {
    await insertDive('d1');
    await insertItem(
      'h',
      EquipmentType.hose,
      key: 'hose_type',
      text: 'hp',
      custom: true,
    );
    await linkGear('d1', 'h');
    expect(await idsMatching([hp]), isEmpty);
  });

  test('a key-only condition means "has this attribute"', () async {
    await insertDive('d1');
    await insertDive('d2');
    await insertItem('h', EquipmentType.hose, key: 'hose_type', text: 'lp');
    await insertItem('g', EquipmentType.hose);
    await linkGear('d1', 'h');
    await linkGear('d2', 'g');
    expect(
      await idsMatching([const EquipmentAttrCondition(key: 'hose_type')]),
      {'d1'},
    );
  });

  test('two conditions AND together', () async {
    await insertDive('both');
    await insertDive('hoseOnly');
    await insertItem('h1', EquipmentType.hose, key: 'hose_type', text: 'hp');
    await insertItem('h2', EquipmentType.hose, key: 'hose_type', text: 'hp');
    await insertItem('w', EquipmentType.wetsuit, key: 'thickness_mm', num: 7);
    await linkGear('both', 'h1');
    await linkGear('both', 'w');
    await linkGear('hoseOnly', 'h2');
    expect(
      await idsMatching([hp, EquipmentAttrCondition.suitThickness(min: 5)]),
      {'both'},
    );
  });
}
