import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';

import '../../../../helpers/test_database.dart';
import 'record_harness.dart';

/// `query` can ask for thousands of summaries, so the roots that would read
/// one row per id list everything the diver sees instead. A repeated id takes
/// a loader past the limit without seeding that many rows.
void main() {
  late AppDatabase db;
  const t = kSeedTime;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedTwoDivers(db);
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'row',
            name: 'Row',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion.insert(
            id: 'row',
            name: 'Row',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(
            id: 'row',
            diverId: kDiverA,
            name: 'Row',
            agency: 'padi',
            startDate: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 'row',
            name: 'Row',
            startDate: t,
            endDate: t,
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'row',
            commonName: 'Row',
            category: 'fish',
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  for (final root in ['buddies', 'centers', 'courses', 'trips', 'species']) {
    test('$root loads a long page from its list', () async {
      final entry = RecordCatalog(RecordRepositories()).named(root);

      final documents = await entry.read(
        List.filled(kLoadEachMaxIds + 1, 'row'),
        const RecordLoad(include: {}, diverId: kDiverA),
      );

      expect(documents.keys, ['row']);
    });
  }
}
