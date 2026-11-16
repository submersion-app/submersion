import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

/// The `myRole` relation (#4409): a dive's own roles by name, read by the
/// rule `DiveRoleSet.resolve` applies, so a secondary role matches and a
/// junction an older version's scalar outdates does not.
void main() {
  late AppDatabase db;
  final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;
  const caveGuide = 'c0000000-0000-4000-8000-000000000001';
  const theirRole = 'c0000000-0000-4000-8000-000000000002';

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    // Another diver's custom role: not borrowed by a dive of mine, as
    // resolveDiveRole reads it.
    await db
        .into(db.diveRoles)
        .insert(
          DiveRolesCompanion.insert(
            id: theirRole,
            diverId: const Value('other'),
            name: 'Their Role',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveRoles)
        .insert(
          DiveRolesCompanion.insert(
            id: caveGuide,
            diverId: const Value('me'),
            name: 'Cave Guide',
            createdAt: now,
            updatedAt: now,
          ),
        );
    Future<void> dive(
      String id,
      String? role, [
      List<String> junction = const [],
    ]) async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diverId: const Value('me'),
              diveDateTime: now,
              diverRole: Value(role),
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (final (i, roleId) in junction.indexed) {
        await db
            .into(db.diveDiverRoles)
            .insert(
              DiveDiverRolesCompanion.insert(
                id: '$id-$i',
                diveId: id,
                roleId: roleId,
                createdAt: now,
              ),
            );
      }
    }

    await dive('unset', null);
    await dive('blank', '');
    await dive('instructor', 'instructor');
    await dive('guide', 'diveGuide', ['diveGuide', 'safetyDiver']);
    // An older version changed the scalar to Buddy after the junction.
    await dive('staleJunction', 'buddy', ['instructor', 'buddy']);
    await dive('cave', caveGuide, [caveGuide]);
    await dive('foreign', theirRole, [theirRole]);
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  final parser = QueryParser(
    appQueryRegistry,
    dives,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 10, 25),
      names: const MapNameResolver({
        QuerySubject.diveRoles: {
          'Instructor': 'instructor',
          'Safety Diver': 'safetyDiver',
          'Buddy': 'buddy',
          'Cave Guide': caveGuide,
          'Their Role': theirRole,
        },
      }),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, dives, appQueryRegistry), isEmpty);
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE d.diver_id = ? AND ${q.where}',
          variables: [
            const Variable<String>('me'),
            ...q.params.map((p) => Variable(p)),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('myRole names the relation and role the field', () {
    final rel = resolvePath(appQueryRegistry, dives, FieldPath(['myRole']));
    expect(rel.error, isNull);
    expect(rel.terminalRelation?.key, 'myRole');
    final field = resolvePath(appQueryRegistry, dives, FieldPath(['role']));
    expect(field.field?.key, 'role');
  });

  test('a secondary role matches', () async {
    expect(await ids('myRole = "Safety Diver"'), {'guide'});
  });

  test('a junction the scalar outdates does not match', () async {
    expect(await ids('myRole = Instructor'), {'instructor'});
    expect(await ids('myRole = Buddy'), {'staleJunction'});
  });

  test('another diver\'s custom role is not my role', () async {
    expect(await ids('myRole = "Their Role"'), isEmpty);
  });

  test('a custom role matches by its name', () async {
    expect(await ids('myRole = "Cave Guide"'), {'cave'});
  });

  test('Explore\'s name form matches a secondary role, any case', () async {
    // Explore lowers `myRole: "safety diver"` to myRole.name in [...].
    final node = ConditionNode(
      FieldPath(['myRole', 'name']),
      QueryOp.inList,
      ListValue(const [StringValue('safety diver')]),
    );
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE d.diver_id = ? AND ${q.where}',
          variables: [
            const Variable<String>('me'),
            ...q.params.map((p) => Variable(p)),
          ],
        )
        .get();
    expect(rows.map((r) => r.read<String>('id')).toSet(), {'guide'});
  });

  test(
    'myRole:none and myRole:any keep what role:none and role:any kept',
    () async {
      expect(await ids('myRole:none'), await ids('role:none'));
      expect(await ids('myRole:any'), await ids('role:any'));
      expect(await ids('myRole:none'), {'unset', 'blank'});
    },
  );
}
