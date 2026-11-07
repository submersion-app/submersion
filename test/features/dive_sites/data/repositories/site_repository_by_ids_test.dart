import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';

import '../../../../helpers/drift_statement_log.dart';
import '../../../../helpers/test_database.dart';

/// The site list read for a handful of ids (issue #4247): Global Search
/// draws up to five sites and must not pay for every site in the library.
void main() {
  late SiteRepository repository;
  late db.AppDatabase database;

  Future<void> seed() async {
    await database.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) "
      "VALUES ('t1', 'To try', 0, 0, 0, 1)",
    );
    for (final id in const ['site-a', 'site-b', 'site-c']) {
      await repository.createSite(
        DiveSite(id: id, name: id),
        classification: const SiteClassification(
          typeIds: ['wreck'],
          tagIds: ['t1'],
        ),
      );
      final ms = DateTime.utc(2024, 3, 5).millisecondsSinceEpoch;
      await database
          .into(database.dives)
          .insert(
            db.DivesCompanion(
              id: Value('dive-$id'),
              diveDateTime: Value(ms),
              siteId: Value(id),
              maxDepth: const Value(20),
              createdAt: Value(ms),
              updatedAt: Value(ms),
            ),
          );
      await database
          .into(database.siteFeatures)
          .insert(
            db.SiteFeaturesCompanion(
              id: Value('feature-$id'),
              siteId: Value(id),
              type: const Value('mooring'),
              latitude: const Value(0),
              longitude: const Value(0),
              createdAt: const Value(1),
              updatedAt: const Value(1),
            ),
          );
    }
  }

  setUp(() async {
    database = await setUpStatementLoggingTestDatabase();
    repository = SiteRepository();
    await withoutStatementLog(seed);
  });

  tearDown(tearDownTestDatabase);

  test('holds what the list holds for those sites, and no others', () async {
    final list = await withoutStatementLog(repository.getSitesWithDiveCounts);

    final scoped = await withoutStatementLog(
      () => repository.getSitesWithDiveCounts(ids: const ['site-c', 'site-a']),
    );

    expect(
      scoped.toSet(),
      list.where((e) => e.site.id != 'site-b').toSet(),
      reason: 'counts, features, types and tags match the list',
    );
    expect(scoped.first.diveCount, 1);
    expect(scoped.first.featureTypes, ['mooring']);
    expect(scoped.first.tags.single.name, 'To try');
  });

  test('every statement it sends is narrowed to the ids', () async {
    final sent = await wholeStatementsOf(
      () => repository.getSitesWithDiveCounts(ids: const ['site-a']),
    );

    expect(sent, isNotEmpty);
    for (final statement in sent) {
      expect(statement, contains('site-a'), reason: statement);
    }
  });

  test('reads nothing for no ids', () async {
    final sent = await statementsOf(() async {
      expect(await repository.getSitesWithDiveCounts(ids: const []), isEmpty);
      expect(await repository.getAllSites(ids: const []), isEmpty);
    });

    expect(sent, isEmpty);
  });
}
