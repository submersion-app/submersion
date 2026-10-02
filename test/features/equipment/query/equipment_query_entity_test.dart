import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/query/equipment_attr_condition_query.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000; // 2025-01-01

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
    Future<void> item(String id, String type) => db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: type,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await item('suit', 'wetsuit');
    await item('reg', 'regulator');
    await item('tank', 'cylinder');
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 't1',
            name: 'Travel',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.equipmentTags)
        .insert(
          EquipmentTagsCompanion.insert(
            id: 'et1',
            equipmentId: 'suit',
            tagId: 't1',
            createdAt: now,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diverId: const Value('me'),
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'reg'),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'dt1',
            diveId: 'd1',
            equipmentId: const Value('tank'),
          ),
        );
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion.insert(
            id: 'a1',
            equipmentId: 'suit',
            attrKey: 'thickness_mm',
            valueNum: const Value(5),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  final equipment = appQueryRegistry.entityFor(QuerySubject.equipment);
  final parser = QueryParser(
    appQueryRegistry,
    equipment,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 9, 28),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, equipment, appQueryRegistry), isEmpty);
    final q = compileQuery(node, equipment, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('tags, dives and attributes reach the related rows', () async {
    expect(await ids('tags:any'), {'suit'});
    // The gear union: a cylinder matched through dive_tanks counts too.
    expect(await ids('dives:any'), {'reg', 'tank'});
    expect(await ids('attributes[key = thickness_mm AND valueNum >= 5]'), {
      'suit',
    });
  });

  test('equipmentAttrConditionNode keeps the dive lowering unchanged', () {
    final node = equipmentAttrConditionNode(
      EquipmentAttrCondition.suitThickness(min: 5),
    );
    expect(node, isA<AndNode>());
    expect((node as AndNode).children, hasLength(2));
  });
}
