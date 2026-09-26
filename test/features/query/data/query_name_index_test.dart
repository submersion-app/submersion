import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/features/query/data/query_name_index.dart';

import '../../../helpers/test_database.dart';
import '../../dive_log/query/dive_query_fixture.dart';

void main() {
  group('QueryNameIndex', () {
    const index = QueryNameIndex({
      QuerySubject.sites: [
        RefValue('s1', 'Salt Pier'),
        RefValue('s2', 'Hilma Hooker'),
      ],
    });

    test('resolve is exact, trimmed and case-insensitive', () {
      expect(
        index.resolve(QuerySubject.sites, 'salt pier'),
        const RefValue('s1', 'Salt Pier'),
      );
      expect(index.resolve(QuerySubject.sites, '  Hilma Hooker '), isNotNull);
      expect(index.resolve(QuerySubject.sites, 'Salt'), isNull);
      expect(index.resolve(QuerySubject.buddies, 'Salt Pier'), isNull);
    });

    test('candidates rank by similarity and labelOf finds by id', () {
      expect(index.candidates(QuerySubject.sites, 'salt peer'), ['Salt Pier']);
      expect(index.labelOf(QuerySubject.sites, 's2'), 'Hilma Hooker');
      expect(index.labelOf(QuerySubject.sites, 'nope'), isNull);
      expect(index.entries(QuerySubject.trips), isEmpty);
    });
  });

  group('QueryNameIndexLoader', () {
    late AppDatabase db;
    setUp(() async {
      db = await setUpTestDatabase();
      await seedQueryFixture(db);
    });
    tearDown(tearDownTestDatabase);

    test(
      'loads every ref subject, scoped to the diver plus unowned rows',
      () async {
        final index = await QueryNameIndexLoader(db).load(diverId: 'me');
        expect(
          index.entries(QuerySubject.sites).map((r) => r.label),
          containsAll(['Salt Pier', 'Hilma Hooker', 'Cenote']),
        );
        expect(
          index.entries(QuerySubject.buddies).map((r) => r.id),
          containsAll(['b1', 'b2']),
        );
        expect(index.resolve(QuerySubject.sites, 'cenote')?.id, 's3');
        // Every subject answers, even with no rows.
        for (final s in QueryNameIndexLoader.refSubjects) {
          expect(index.entries(s), isA<List<RefValue>>());
        }
      },
    );

    test('another diver\'s private rows stay out of the index', () async {
      final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;
      await db.customStatement(
        "INSERT INTO buddies (id, diver_id, name, created_at, updated_at) "
        "VALUES ('b-other', 'other', 'Zed', $now, $now)",
      );
      final index = await QueryNameIndexLoader(db).load(diverId: 'me');
      expect(index.labelOf(QuerySubject.buddies, 'b-other'), isNull);
      final theirs = await QueryNameIndexLoader(db).load(diverId: 'other');
      expect(theirs.labelOf(QuerySubject.buddies, 'b-other'), 'Zed');
    });

    test('the tables it reads are the ten ref tables', () {
      expect(QueryNameIndexLoader.tables, {
        'dive_sites',
        'trips',
        'dive_centers',
        'dive_computers',
        'courses',
        'buddies',
        'tags',
        'dive_types',
        'equipment',
        'species',
      });
    });
  });
}
