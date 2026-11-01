import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/global_search/data/global_search_plan.dart';
import 'package:submersion/features/global_search/data/global_search_repository.dart';
import 'package:submersion/features/global_search/data/global_search_sources.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';

import '../../../helpers/shared_items_fixture.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late GlobalSearchRepository repository;

  final context = ParseContext(
    prefs: kMetricPrefs,
    now: DateTime(2026, 10, 30),
    names: const MapNameResolver(<QuerySubject, Map<String, String>>{}),
  );

  /// The section for [kind], or an empty one.
  Future<GlobalSearchSection> search(
    GlobalSearchKind kind,
    String text, {
    String? diverId = 'me',
  }) {
    final plan = planGlobalSearch(text, context: context, diverId: diverId);
    return repository.search(
      plan.runs.firstWhere((r) => r.source.kind == kind),
      diverId: diverId,
    );
  }

  Future<Set<String>> ids(
    GlobalSearchKind kind,
    String text, {
    String? diverId = 'me',
  }) async => (await search(kind, text, diverId: diverId)).ids.toSet();

  setUp(() async {
    db = await setUpTestDatabase();
    repository = GlobalSearchRepository(db);
    await seedDivers(db, ['me', 'other']);
  });
  tearDown(tearDownTestDatabase);

  group('each kind finds its own record', () {
    test('dives, by a word and by their site', () async {
      await seedSite(db, 's1', owner: 'me', name: 'Salt Pier');
      await seedDive(db, 'd1', diver: 'me', siteId: 's1');
      final section = await search(GlobalSearchKind.dives, 'salt');
      expect(section.total, 1);
      expect(section.ids, ['d1']);
    });

    test('sites', () async {
      await seedSite(db, 's1', owner: 'me', name: 'Salt Pier');
      expect(await ids(GlobalSearchKind.sites, 'pier'), {'s1'});
    });

    test('trips', () async {
      await seedTrip(db, 't1', owner: 'me', name: 'Bonaire 2026');
      expect(await ids(GlobalSearchKind.trips, 'bonaire'), {'t1'});
    });

    test('equipment, by serial number and by tag', () async {
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, serial_number, "
        "created_at, updated_at) VALUES "
        "('e1', 'me', 'Primary reg', 'regulator', 'SN-9931', 1, 1)",
      );
      expect(await ids(GlobalSearchKind.equipment, 'sn-9931'), {'e1'});
    });

    test('equipment sets', () async {
      await db.customStatement(
        "INSERT INTO equipment_sets (id, diver_id, name, created_at, "
        "updated_at) VALUES ('q1', 'me', 'Cold water kit', 1, 1)",
      );
      expect(await ids(GlobalSearchKind.equipmentSets, 'cold'), {'q1'});
    });

    test('buddies, dive centers, certifications and courses', () async {
      await db.customStatement(
        "INSERT INTO buddies (id, diver_id, name, created_at, updated_at) "
        "VALUES ('b1', 'me', 'Robin Reef', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO dive_centers (id, diver_id, name, created_at, "
        "updated_at) VALUES ('c1', 'me', 'Reef Divers', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO certifications (id, diver_id, name, agency, created_at, "
        "updated_at) VALUES ('z1', 'me', 'Reef Rescue', 'padi', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO courses (id, diver_id, name, agency, start_date, "
        "created_at, updated_at) VALUES "
        "('k1', 'me', 'Reef Ecology', 'padi', 1, 1, 1)",
      );
      expect(await ids(GlobalSearchKind.buddies, 'reef'), {'b1'});
      expect(await ids(GlobalSearchKind.diveCenters, 'reef'), {'c1'});
      expect(await ids(GlobalSearchKind.certifications, 'reef'), {'z1'});
      expect(await ids(GlobalSearchKind.courses, 'reef'), {'k1'});
    });

    test('species, across every diver', () async {
      await db.customStatement(
        "INSERT INTO species (id, common_name, category) VALUES "
        "('x1', 'Zebra Blenny Test', 'fish')",
      );
      expect(
        await ids(GlobalSearchKind.species, 'zebra blenny'),
        contains('x1'),
      );
    });

    test('documents, plans and tracks read every match', () async {
      await db.customStatement(
        "INSERT INTO documents (id, diver_id, type, title, created_at, "
        "updated_at) VALUES ('m1', 'me', 'other', 'Wreck permit', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO dive_plans (id, diver_id, name, created_at, updated_at) "
        "VALUES ('p1', 'me', 'Wreck plan', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO gps_tracks (id, start_time, end_time, name, created_at, "
        "updated_at) VALUES ('g1', 1000, 2000, 'Wreck boat day', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO nav_tracks (id, diver_id, source, name, start_time, "
        "end_time, point_count, points, created_at, updated_at) VALUES "
        "('n1', 'me', 'file', 'Wreck loop', 1000, 2000, 0, x'', 1, 1)",
      );
      expect(await ids(GlobalSearchKind.documents, 'wreck'), {'m1'});
      expect(await ids(GlobalSearchKind.divePlans, 'wreck'), {'p1'});
      expect(await ids(GlobalSearchKind.gpsTracks, 'wreck'), {'g1'});
      expect(await ids(GlobalSearchKind.underwaterRoutes, 'wreck'), {'n1'});
    });
  });

  group('a field query', () {
    test('finds a record with no list of its own', () async {
      final expiry = DateTime(2027, 3, 1).millisecondsSinceEpoch;
      await db.customStatement(
        "INSERT INTO documents (id, diver_id, type, title, expiry_date, "
        "created_at, updated_at) VALUES "
        "('due', 'me', 'insurance', 'DAN', $expiry, 1, 1), "
        "('none', 'me', 'map', 'Pier', NULL, 1, 1)",
      );
      expect(await ids(GlobalSearchKind.documents, 'expires < 2028'), {'due'});
      expect(await ids(GlobalSearchKind.documents, 'type = map'), {'none'});
    });

    test('still keeps to the diver', () async {
      await db.customStatement(
        "INSERT INTO documents (id, diver_id, type, title, created_at, "
        "updated_at) VALUES ('theirs', 'other', 'map', 'Pier', 1, 1)",
      );
      expect(await ids(GlobalSearchKind.documents, 'type = map'), isEmpty);
    });
  });

  group('shows what the list would', () {
    test('dives are the active diver\'s', () async {
      await seedSite(db, 's1', owner: 'me', name: 'Salt Pier');
      await seedDive(db, 'mine', diver: 'me', siteId: 's1');
      await seedDive(db, 'theirs', diver: 'other', siteId: 's1');
      expect(await ids(GlobalSearchKind.dives, 'salt'), {'mine'});
    });

    test('a site: own or shared, never hidden or another diver\'s', () async {
      await seedSite(db, 'own', owner: 'me', name: 'Reef own');
      await seedSite(
        db,
        'shared',
        owner: 'other',
        shared: true,
        name: 'Reef s',
      );
      await seedSite(db, 'private', owner: 'other', name: 'Reef p');
      await seedSite(db, 'gone', owner: 'other', shared: true, name: 'Reef g');
      await db.customStatement(
        "INSERT INTO site_hides (id, diver_id, site_id, created_at) "
        "VALUES ('h1', 'me', 'gone', 1)",
      );
      expect(await ids(GlobalSearchKind.sites, 'reef'), {'own', 'shared'});
    });

    test('a trip: own or shared, never another diver\'s', () async {
      await seedTrip(db, 'own', owner: 'me', name: 'Reef own');
      await seedTrip(
        db,
        'shared',
        owner: 'other',
        shared: true,
        name: 'Reef s',
      );
      await seedTrip(db, 'private', owner: 'other', name: 'Reef p');
      expect(await ids(GlobalSearchKind.trips, 'reef'), {'own', 'shared'});
    });

    test('equipment: own or shared with me', () async {
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('own', 'me', 'Reg one', 'regulator', 1, 1), "
        "('lent', 'other', 'Reg two', 'regulator', 1, 1), "
        "('kept', 'other', 'Reg three', 'regulator', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO equipment_shares (id, equipment_id, diver_id, "
        "created_at) VALUES ('a1', 'lent', 'me', 1)",
      );
      expect(await ids(GlobalSearchKind.equipment, 'reg'), {'own', 'lent'});
    });

    test('a GPS recording still in progress is left out', () async {
      await db.customStatement(
        'INSERT INTO gps_tracks (id, start_time, end_time, name, created_at, '
        "updated_at) VALUES ('done', 1, 2, 'Boat a', 1, 1), "
        "('live', 1, NULL, 'Boat b', 1, 1)",
      );
      expect(await ids(GlobalSearchKind.gpsTracks, 'boat'), {'done'});
    });

    test('a document is found by its owner and its tags', () async {
      await seedTrip(db, 't1', owner: 'me', name: 'Bonaire 2026');
      await seedSite(db, 's1', owner: 'me', name: 'Salt Pier');
      await seedDive(db, 'd1', diver: 'me', siteId: 's1');
      await db.customStatement(
        "INSERT INTO tags (id, diver_id, name, created_at, updated_at) "
        "VALUES ('t9', 'me', 'Insurance docs', 1, 1)",
      );
      await db.customStatement(
        'INSERT INTO documents (id, diver_id, trip_id, dive_id, type, title, '
        "created_at, updated_at) VALUES "
        "('trip', 'me', 't1', NULL, 'other', 'A', 1, 1), "
        "('dive', 'me', NULL, 'd1', 'other', 'B', 1, 1), "
        "('tag', 'me', NULL, NULL, 'other', 'C', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO document_tags (id, document_id, tag_id, created_at) "
        "VALUES ('x1', 'tag', 't9', 1)",
      );
      expect(await ids(GlobalSearchKind.documents, 'bonaire'), {'trip'});
      expect(await ids(GlobalSearchKind.documents, 'salt'), {'dive'});
      expect(await ids(GlobalSearchKind.documents, 'insurance'), {'tag'});
    });

    test('a route with no owner shows to every diver', () async {
      await db.customStatement(
        "INSERT INTO nav_tracks (id, diver_id, source, name, start_time, "
        "end_time, point_count, points, created_at, updated_at) VALUES "
        "('free', NULL, 'file', 'Loop a', 1, 2, 0, x'', 1, 1), "
        "('kept', 'other', 'file', 'Loop b', 1, 2, 0, x'', 1, 1)",
      );
      expect(await ids(GlobalSearchKind.underwaterRoutes, 'loop'), {'free'});
    });

    test(
      'routes keep the Tracks list order: unlinked first, then newest',
      () async {
        await seedDive(db, 'd1', diver: 'me');
        await db.customStatement(
          "INSERT INTO nav_tracks (id, diver_id, dive_id, source, name, "
          "start_time, end_time, point_count, points, created_at, updated_at) "
          "VALUES "
          "('linked', 'me', 'd1', 'file', 'Loop a', 9, 10, 0, x'', 1, 1), "
          "('older', 'me', NULL, 'file', 'Loop b', 1, 2, 0, x'', 1, 1), "
          "('newer', 'me', NULL, 'file', 'Loop c', 5, 6, 0, x'', 1, 1)",
        );
        final section = await search(GlobalSearchKind.underwaterRoutes, 'loop');
        expect(section.ids, ['newer', 'older', 'linked']);
      },
    );

    test('no diver reads every row', () async {
      await seedSite(db, 'a', owner: 'me', name: 'Reef a');
      await seedSite(db, 'b', owner: 'other', name: 'Reef b');
      expect(await ids(GlobalSearchKind.sites, 'reef', diverId: null), {
        'a',
        'b',
      });
    });
  });

  group('sections', () {
    test('a preview counts past its limit', () async {
      for (var i = 0; i < kGlobalSearchPreviewLimit + 2; i++) {
        await seedSite(db, 's$i', owner: 'me', name: 'Reef $i');
      }
      final section = await search(GlobalSearchKind.sites, 'reef');
      expect(section.ids, hasLength(kGlobalSearchPreviewLimit));
      expect(section.total, kGlobalSearchPreviewLimit + 2);
    });

    test('a source with no list reads every match', () async {
      for (var i = 0; i < kGlobalSearchPreviewLimit + 2; i++) {
        await db.customStatement(
          'INSERT INTO equipment_sets (id, diver_id, name, created_at, '
          "updated_at) VALUES ('q$i', 'me', 'Kit $i', 1, 1)",
        );
      }
      final section = await search(GlobalSearchKind.equipmentSets, 'kit');
      expect(section.ids, hasLength(kGlobalSearchPreviewLimit + 2));
      expect(section.total, kGlobalSearchPreviewLimit + 2);
    });

    test('dives come back newest first', () async {
      await seedSite(db, 's1', owner: 'me', name: 'Salt Pier');
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'old',
              diverId: const Value('me'),
              diveDateTime: 1000,
              siteId: const Value('s1'),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'new',
              diverId: const Value('me'),
              diveDateTime: 2000,
              siteId: const Value('s1'),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final section = await search(GlobalSearchKind.dives, 'salt');
      expect(section.ids, ['new', 'old']);
    });

    test('a bare number finds that dive with no text match', () async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'd500',
              diverId: const Value('me'),
              diveNumber: const Value(500),
              diveDateTime: 1000,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final section = await search(GlobalSearchKind.dives, '500');
      expect(section.ids, ['d500']);
    });

    test('a translated name finds a built-in species', () async {
      await db.customStatement(
        "INSERT OR IGNORE INTO species (id, common_name, category) VALUES "
        "('sp_whale_shark', 'Whale Shark', 'shark')",
      );
      expect(
        await ids(GlobalSearchKind.species, 'Walhai'),
        contains('sp_whale_shark'),
      );
    });
  });
}
