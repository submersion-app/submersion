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

    test('rows another diver shares are in the index, like the lists', () async {
      final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;
      // Shared with every profile by flag (sites and trips) or with one
      // profile by a share row (equipment), as VisibilityFilter reads them.
      await db.customStatement(
        "INSERT INTO dive_sites (id, diver_id, name, is_shared, created_at, "
        "updated_at) VALUES ('s-shared', 'other', 'Blue Hole', 1, $now, $now), "
        "('s-private', 'other', 'Secret Reef', 0, $now, $now)",
      );
      await db.customStatement(
        "INSERT INTO trips (id, diver_id, name, start_date, end_date, "
        "is_shared, created_at, updated_at) VALUES ('t-shared', 'other', "
        "'Club Trip', $now, $now, 1, $now, $now)",
      );
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('g-lent', 'other', 'Loaner BCD', 'bcd', $now, "
        "$now)",
      );
      await db.customStatement(
        "INSERT INTO equipment_shares (id, equipment_id, diver_id, "
        "created_at) VALUES ('sh1', 'g-lent', 'me', $now)",
      );
      final index = await QueryNameIndexLoader(db).load(diverId: 'me');
      expect(index.resolve(QuerySubject.sites, 'blue hole')?.id, 's-shared');
      expect(index.labelOf(QuerySubject.sites, 's-private'), isNull);
      expect(index.resolve(QuerySubject.trips, 'club trip')?.id, 't-shared');
      expect(index.resolve(QuerySubject.equipment, 'loaner bcd')?.id, 'g-lent');
    });

    test('the tables it reads are the ten ref tables and the share table', () {
      expect(QueryNameIndexLoader.tables, {
        'equipment_shares',
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
