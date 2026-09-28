import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
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
    Future<void> site(
      String id, {
      String? difficulty,
      double? lat,
      double? lon,
    }) => db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: id,
            difficulty: Value(difficulty),
            latitude: Value(lat),
            longitude: Value(lon),
            createdAt: now,
            updatedAt: now,
          ),
        );
    // Difficulty stored in the case the app once wrote it.
    await site('reef', difficulty: 'Advanced', lat: 12.1, lon: -68.2);
    await site('cave', difficulty: 'technical', lat: 20.5);
    await site('bare');
    await db
        .into(db.siteTypes)
        .insert(
          SiteTypesCompanion.insert(
            id: 'my-arch',
            name: 'Rock arch',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.siteSiteTypes)
        .insert(
          SiteSiteTypesCompanion.insert(
            id: 'sst1',
            siteId: 'cave',
            siteTypeId: 'my-arch',
            createdAt: now,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diverId: const Value('me'),
            siteId: const Value('reef'),
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  final sites = appQueryRegistry.entityFor(QuerySubject.sites);
  const names = MapNameResolver({
    QuerySubject.siteTypes: {'Rock arch': 'my-arch'},
  });
  final parser = QueryParser(
    appQueryRegistry,
    sites,
    ParseContext(prefs: kMetricPrefs, now: DateTime(2026, 9, 28), names: names),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, sites, appQueryRegistry), isEmpty);
    final q = compileQuery(node, sites, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('the registry entry is the site entity', () {
    expect(identical(sites, siteQueryEntity), isTrue);
  });

  test('difficulty matches whatever case it was stored in', () async {
    expect(await ids('difficulty = advanced'), {'reef'});
    expect(await ids('difficulty in [advanced, technical]'), {'reef', 'cave'});
  });

  test('coordinates:any needs both halves of the position', () async {
    expect(await ids('coordinates:any'), {'reef'});
    expect(await ids('coordinates:none'), {'cave', 'bare'});
  });

  test('dives, types and text search reach the related rows', () async {
    expect(await ids('dives:any'), {'reef'});
    expect(await ids('types = "Rock arch"'), {'cave'});
    expect(await ids('"cav"'), {'cave'});
  });
}
