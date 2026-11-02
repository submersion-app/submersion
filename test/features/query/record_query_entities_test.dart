import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../helpers/shared_items_fixture.dart';
import '../../helpers/test_database.dart';

/// The records with no list query of their own, which global search reads
/// (#3882): each answers field queries as a list's entity does.
void main() {
  late AppDatabase db;

  Future<Set<String>> ids(QuerySubject subject, String text) async {
    final entity = appQueryRegistry.entityFor(subject);
    final parsed = QueryParser(
      appQueryRegistry,
      entity,
      ParseContext(
        prefs: kMetricPrefs,
        now: DateTime(2026, 10, 30),
        names: const MapNameResolver({
          QuerySubject.sites: {'salt pier': 's1'},
          QuerySubject.tags: {'wreck': 'tag1'},
        }),
      ),
    ).parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$text: $parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, entity, appQueryRegistry), isEmpty);
    final q = compileQuery(node, entity, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['me']);
    await seedSite(db, 's1', owner: 'me', name: 'Salt Pier');
    await seedDive(db, 'd1', diver: 'me', siteId: 's1');
  });
  tearDown(tearDownTestDatabase);

  group('equipment sets', () {
    setUp(() async {
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('e1', 'me', 'Drysuit', 'drysuit', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO equipment_sets (id, diver_id, name, description, "
        "is_default, created_at, updated_at) VALUES "
        "('cold', 'me', 'Cold', 'For the quarry', 1, 1, 1), "
        "('warm', 'me', 'Warm', '', 0, 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO equipment_set_items (set_id, equipment_id) "
        "VALUES ('cold', 'e1')",
      );
    });

    test('read their fields', () async {
      const s = QuerySubject.equipmentSets;
      expect(await ids(s, 'name ~ col'), {'cold'});
      expect(await ids(s, 'description ~ quarry'), {'cold'});
      expect(await ids(s, 'default = true'), {'cold'});
      expect(await ids(s, 'itemCount >= 1'), {'cold'});
    });

    test('reach their gear', () async {
      const s = QuerySubject.equipmentSets;
      expect(await ids(s, 'items.name ~ dry'), {'cold'});
      expect(await ids(s, 'items:none'), {'warm'});
    });
  });

  group('documents', () {
    final expiry = DateTime(2027, 3, 1).millisecondsSinceEpoch;
    final issued = DateTime(2025, 3, 1).millisecondsSinceEpoch;

    setUp(() async {
      await db.customStatement(
        "INSERT INTO documents (id, diver_id, site_id, type, title, issuer, "
        "reference_number, issue_date, expiry_date, is_primary, notes, "
        "created_at, updated_at) VALUES "
        "('ins', 'me', NULL, 'insurance', 'DAN', 'DAN Europe', 'A-1', "
        "$issued, $expiry, 1, 'Annual', 1, 1), "
        "('map', 'me', 's1', 'map', 'Pier map', NULL, NULL, NULL, NULL, 0, "
        "'', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO tags (id, diver_id, name, created_at, updated_at) "
        "VALUES ('tag1', 'me', 'Wreck', 1, 1)",
      );
      await db.customStatement(
        "INSERT INTO document_tags (id, document_id, tag_id, created_at) "
        "VALUES ('dt1', 'map', 'tag1', 1)",
      );
    });

    test('read their fields', () async {
      const s = QuerySubject.documents;
      expect(await ids(s, 'title ~ map'), {'map'});
      expect(await ids(s, 'type = insurance'), {'ins'});
      expect(await ids(s, 'issuer ~ europe'), {'ins'});
      expect(await ids(s, 'referenceNumber = "A-1"'), {'ins'});
      expect(await ids(s, 'notes ~ annual'), {'ins'});
      expect(await ids(s, 'primary = true'), {'ins'});
    });

    test('read dates on the local calendar, under their short names', () async {
      const s = QuerySubject.documents;
      expect(await ids(s, 'expires < 2028'), {'ins'});
      expect(await ids(s, 'expires > 2028'), isEmpty);
      expect(await ids(s, 'issued < 2026'), {'ins'});
      expect(await ids(s, 'expiryDate:none'), {'map'});
    });

    test('reach their tags and what they are filed under', () async {
      const s = QuerySubject.documents;
      expect(await ids(s, 'tags = "Wreck"'), {'map'});
      expect(await ids(s, 'site = "Salt Pier"'), {'map'});
      expect(await ids(s, 'site:none'), {'ins'});
    });
  });

  group('dive plans', () {
    final planned = DateTime(2026, 6, 1, 9).millisecondsSinceEpoch ~/ 1000;

    setUp(() async {
      await db.customStatement(
        "INSERT INTO dive_plans (id, diver_id, name, notes, mode, site_id, "
        "start_date_time, summary_max_depth, summary_runtime_seconds, "
        "created_at, updated_at) VALUES "
        "('deep', 'me', 'Deep', 'Stage drop', 'ccr', 's1', $planned, 45, "
        "3600, 1, 1), "
        "('easy', 'me', 'Easy', '', 'oc', NULL, NULL, 12, 1800, 1, 1)",
      );
    });

    test('read their fields', () async {
      const s = QuerySubject.divePlans;
      expect(await ids(s, 'name ~ dee'), {'deep'});
      expect(await ids(s, 'notes ~ stage'), {'deep'});
      expect(await ids(s, 'mode = ccr'), {'deep'});
      expect(await ids(s, 'depth > 30m'), {'deep'});
      expect(await ids(s, 'runtime >= 60'), {'deep'});
      expect(await ids(s, 'site = "Salt Pier"'), {'deep'});
    });

    test('read a start stored in seconds as a calendar day', () async {
      const s = QuerySubject.divePlans;
      expect(await ids(s, 'date < 2027'), {'deep'});
      expect(await ids(s, 'date > 2027'), isEmpty);
      expect(await ids(s, 'date:none'), {'easy'});
    });
  });

  group('GPS tracks', () {
    final start = DateTime.utc(2026, 6, 1, 9).millisecondsSinceEpoch;
    const hour = 3600000;

    setUp(() async {
      await db.customStatement(
        "INSERT INTO gps_tracks (id, start_time, end_time, device_name, "
        "source, source_ref, name, trim_start_time, trim_end_time, "
        "created_at, updated_at) VALUES "
        "('boat', $start, ${start + 2 * hour}, 'Pixel', 'phone', NULL, "
        "'Boat day', NULL, NULL, 1, 1), "
        "('file', $start, ${start + 3 * hour}, NULL, 'gpx', 'reef.gpx', "
        "NULL, ${start + hour}, ${start + 2 * hour}, 1, 1)",
      );
    });

    test('read their fields', () async {
      const s = QuerySubject.gpsTracks;
      expect(await ids(s, 'name ~ boat'), {'boat'});
      expect(await ids(s, 'deviceName ~ pixel'), {'boat'});
      expect(await ids(s, 'file ~ reef'), {'file'});
      expect(await ids(s, 'source = gpx'), {'file'});
      expect(await ids(s, 'date < 2027'), {'boat', 'file'});
    });

    test('measure the trimmed recording', () async {
      const s = QuerySubject.gpsTracks;
      expect(await ids(s, 'duration > 90'), {'boat'});
      expect(await ids(s, 'duration < 90'), {'file'});
    });
  });

  group('underwater routes', () {
    final start = DateTime.utc(2026, 6, 1, 9).millisecondsSinceEpoch;

    setUp(() async {
      await db.customStatement(
        "INSERT INTO nav_tracks (id, diver_id, dive_id, site_id, source, "
        "source_ref, device_name, name, start_time, end_time, point_count, "
        "total_distance, max_depth, duration_seconds, points, created_at, "
        "updated_at) VALUES "
        "('loop', 'me', 'd1', 's1', 'seacraft_enc', 'loop.enc', 'Seacraft', "
        "'Loop', $start, ${start + 1000}, 0, 800, 31, 2400, x'', 1, 1), "
        "('spare', 'me', NULL, NULL, 'suunto_route', NULL, NULL, NULL, "
        "$start, ${start + 1000}, 0, 100, 8, 600, x'', 1, 1)",
      );
    });

    test('read their fields', () async {
      const s = QuerySubject.navTracks;
      expect(await ids(s, 'name ~ loop'), {'loop'});
      expect(await ids(s, 'deviceName ~ sea'), {'loop'});
      expect(await ids(s, 'file ~ loop'), {'loop'});
      expect(await ids(s, 'source ~ suunto'), {'spare'});
      expect(await ids(s, 'date < 2027'), {'loop', 'spare'});
      expect(await ids(s, 'depth > 30m'), {'loop'});
      expect(await ids(s, 'distance > 500m'), {'loop'});
      expect(await ids(s, 'duration > 30'), {'loop'});
    });

    test('reach their dive and site', () async {
      const s = QuerySubject.navTracks;
      expect(await ids(s, 'site = "Salt Pier"'), {'loop'});
      expect(await ids(s, 'dive:none'), {'spare'});
    });
  });
}
