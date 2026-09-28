import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    // Custom ids, clear of the seeded built-in catalog.
    await sql(
      'INSERT INTO species (id, common_name, scientific_name, category, '
      'taxonomy_class, is_built_in) VALUES '
      "('t_whale', 'Test Whale', 'Testus maximus', 'mammal', 'Mammalia', 0), "
      "('t_coral', 'Test Coral', NULL, 'coral', 'Anthozoa', 1)",
    );
    await sql(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('s1', 'Reef', $now, $now)",
    );
    await sql(
      'INSERT INTO site_species (id, site_id, species_id, created_at) '
      "VALUES ('ss1', 's1', 't_coral', $now)",
    );
    await sql(
      'INSERT INTO dives (id, dive_date_time, max_depth, created_at, '
      "updated_at) VALUES ('d1', $now, 18, $now, $now)",
    );
    await sql(
      'INSERT INTO sightings (id, dive_id, species_id, count) '
      "VALUES ('g1', 'd1', 't_whale', 3)",
    );
  });
  tearDown(tearDownTestDatabase);

  final species = appQueryRegistry.entityFor(QuerySubject.species);
  final parser = QueryParser(
    appQueryRegistry,
    species,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 9, 28),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, species, appQueryRegistry), isEmpty);
    final q = compileQuery(node, species, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    // Only this test's rows; the seeded catalog is not the subject here.
    return {
      for (final r in rows)
        if (r.read<String>('id').startsWith('t_')) r.read<String>('id'),
    };
  }

  test(
    'category, built-in, sightings, sites and dives are queryable',
    () async {
      expect(await ids('category = mammal'), {'t_whale'});
      expect(await ids('builtIn = true'), {'t_coral'});
      expect(await ids('sightings.count >= 3'), {'t_whale'});
      expect(await ids('sites:any'), {'t_coral'});
      expect(await ids('dives.maxDepth > 10'), {'t_whale'});
      expect(await ids('"anthozoa"'), {'t_coral'});
      expect(await ids('"testus"'), {'t_whale'});
    },
  );
}
