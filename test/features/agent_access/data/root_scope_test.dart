import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/features/agent_access/data/root_scope.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

import '../../../helpers/test_database.dart';

void main() {
  const t = 1700000000000;

  group('rootScopeFor', () {
    test('dives scope is a plain diver_id equality', () {
      final scope = rootScopeFor(diveQueryEntity, 'me')!;
      expect(scope.sql, 'r0.diver_id = ?');
      expect(scope.params, ['me']);
    });

    test('buddies use the alias given', () {
      final scope = rootScopeFor(buddyQueryEntity, 'me', alias: 'b')!;
      expect(scope.sql, 'b.diver_id = ?');
    });

    test('species has no scope', () {
      expect(rootScopeFor(speciesQueryEntity, 'me'), isNull);
    });

    test(
      'sites, trips and equipment bind the viewer for every placeholder',
      () {
        for (final entity in [
          siteQueryEntity,
          tripQueryEntity,
          equipmentQueryEntity,
        ]) {
          final scope = rootScopeFor(entity, 'me')!;
          final placeholders = '?'.allMatches(scope.sql).length;
          expect(placeholders, greaterThan(1), reason: entity.subject.name);
          expect(
            scope.params.length,
            placeholders,
            reason: entity.subject.name,
          );
          expect(scope.params.every((p) => p == 'me'), isTrue);
          expect(scope.sql.trimLeft(), isNot(startsWith('AND')));
          expect(scope.sql.trimLeft(), isNot(startsWith('WHERE')));
        }
      },
    );
  });

  group('rootScopeFor against a database', () {
    late AppDatabase db;

    Future<void> site(String id, String owner, {bool shared = false}) => db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: id,
            createdAt: t,
            updatedAt: t,
            diverId: Value(owner),
            isShared: Value(shared),
          ),
        );

    setUp(() async {
      db = await setUpTestDatabase();
      for (final id in ['A', 'B', 'C']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
      await site('own', 'B');
      await site('shared-to-b', 'A');
      await db
          .into(db.siteShares)
          .insert(
            SiteSharesCompanion.insert(
              id: 's1',
              siteId: 'shared-to-b',
              diverId: 'B',
              createdAt: t,
            ),
          );
      await site('shared-all-hidden', 'C', shared: true);
      await db
          .into(db.siteHides)
          .insert(
            SiteHidesCompanion.insert(
              id: 'h1',
              siteId: 'shared-all-hidden',
              diverId: 'B',
              createdAt: t,
            ),
          );
      await site('private-of-c', 'C');
    });
    tearDown(tearDownTestDatabase);

    test(
      'sites scope sees own and shared sites and hides hidden ones',
      () async {
        final compiled = compileQuery(null, siteQueryEntity, appQueryRegistry);
        final ids = await QueryIdSetRunner(
          db,
        ).ids(compiled, scope: rootScopeFor(siteQueryEntity, 'B'));
        expect(ids, containsAll(['own', 'shared-to-b']));
        expect(ids, isNot(contains('shared-all-hidden')));
        expect(ids, isNot(contains('private-of-c')));
      },
    );
  });
}
