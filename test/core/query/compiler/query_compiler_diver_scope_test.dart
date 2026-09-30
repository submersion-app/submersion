import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/sql_templates.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

import '../../../helpers/test_database.dart';

/// A diver-scoped compile reads only the active diver's dives wherever a
/// query reaches dives from another root: a hop into them ("sites where I
/// dived deeper than 20 m") and a count or date over them ("sites I dived
/// more than twice"). A shared site holds several divers' dives, and the
/// lists count only their own diver's.
void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

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
    // A site the partner owns and shares: their two deep dives, my one
    // shallow dive.
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: const Value('reef'),
            name: const Value('Reef'),
            diverId: const Value('other'),
            isShared: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final (id, diver, depth) in [
      ('p1', 'other', 30.0),
      ('p2', 'other', 25.0),
      ('m1', 'me', 5.0),
    ]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diverId: Value(diver),
              siteId: const Value('reef'),
              maxDepth: Value(depth),
              diveDateTime: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> sites(QueryNode node, {String? diverId}) {
    final compiled = compileQuery(
      node,
      siteQueryEntity,
      appQueryRegistry,
      diverId: diverId,
    );
    expect(
      countPlaceholders(compiled.where),
      compiled.params.length,
      reason: compiled.where,
    );
    return QueryIdSetRunner(db).ids(compiled);
  }

  final deepDive = ScopedNode(
    FieldPath(const ['dives']),
    ConditionNode(
      FieldPath(const ['depth']),
      QueryOp.gte,
      const NumberValue(20, null),
    ),
  );
  final twice = ConditionNode(
    FieldPath(const ['diveCount']),
    QueryOp.gte,
    const NumberValue(2, null),
  );

  group('a hop into dives', () {
    test('reads only the active diver\'s dives', () async {
      expect(await sites(deepDive, diverId: 'me'), isEmpty);
      expect(await sites(deepDive, diverId: 'other'), {'reef'});
    });

    test('with no diver reads every diver\'s, as before', () async {
      expect(await sites(deepDive), {'reef'});
    });
  });

  group('a count over dives', () {
    test('counts only the active diver\'s dives', () async {
      expect(await sites(twice, diverId: 'me'), isEmpty);
      expect(await sites(twice, diverId: 'other'), {'reef'});
    });

    test('with no diver counts every diver\'s, as before', () async {
      expect(await sites(twice), {'reef'});
    });

    test('"never dived" is about the active diver', () async {
      final none = ConditionNode(
        FieldPath(const ['diveCount']),
        QueryOp.isEmpty,
        null,
      );
      expect(await sites(none, diverId: 'me'), isEmpty);
      await (db.delete(db.dives)..where((d) => d.id.equals('m1'))).go();
      expect(await sites(none, diverId: 'me'), {'reef'});
    });
  });

  test('every value still binds to its own placeholder', () async {
    // The scope's bind sits between other values: a count compared twice
    // (!=), a date read twice (a day), a text list, a relation id and a
    // scoped group. A bind out of order would compare the wrong value.
    final day = DateTime.utc(2026, 6, 1);
    final q = AndNode([
      ConditionNode(
        FieldPath(const ['name']),
        QueryOp.inList,
        ListValue(const [StringValue('Reef')]),
      ),
      ConditionNode(
        FieldPath(const ['diveCount']),
        QueryOp.neq,
        const NumberValue(7, null),
      ),
      ConditionNode(
        FieldPath(const ['lastDived']),
        QueryOp.eq,
        DateValue(DateTime(day.year, day.month, day.day)),
      ),
      ConditionNode(
        FieldPath(const ['diveCount']),
        QueryOp.between,
        ListValue(const [NumberValue(1, null), NumberValue(1, null)]),
      ),
      ScopedNode(
        FieldPath(const ['dives']),
        ConditionNode(
          FieldPath(const ['depth']),
          QueryOp.lte,
          const NumberValue(10, null),
        ),
      ),
      // A relation id reached through the scoped hop binds after it.
      ConditionNode(
        FieldPath(const ['dives', 'site']),
        QueryOp.eq,
        const RefValue('reef', 'Reef'),
      ),
    ]);
    expect(await sites(q, diverId: 'me'), {'reef'});
    expect(await sites(q, diverId: 'other'), isEmpty);
  });
}
