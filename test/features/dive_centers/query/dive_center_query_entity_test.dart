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
    await sql(
      'INSERT INTO dive_centers (id, name, city, country, affiliations, '
      'rating, latitude, longitude, created_at, updated_at) VALUES '
      "('reef', 'Reef Divers', 'Kralendijk', 'Bonaire', 'PADI,SSI', 4, 12.1, "
      '-68.2, $now, $now), '
      "('lake', 'Lake Club', 'Zug', 'Switzerland', 'CMAS', 2, NULL, NULL, "
      '$now, $now)',
    );
    await sql(
      'INSERT INTO dives (id, dive_date_time, dive_center_id, max_depth, '
      "created_at, updated_at) VALUES ('d1', $now, 'reef', 25, $now, $now)",
    );
  });
  tearDown(tearDownTestDatabase);

  final centers = appQueryRegistry.entityFor(QuerySubject.centers);
  final parser = QueryParser(
    appQueryRegistry,
    centers,
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
    expect(validateQuery(node, centers, appQueryRegistry), isEmpty);
    final q = compileQuery(node, centers, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('rating, affiliations, coordinates and dives are queryable', () async {
    expect(await ids('rating >= 3'), {'reef'});
    expect(await ids('affiliations ~ ssi'), {'reef'});
    expect(await ids('coordinates:none'), {'lake'});
    expect(await ids('dives.maxDepth > 20'), {'reef'});
    expect(await ids('dives:none'), {'lake'});
    expect(await ids('"zug"'), {'lake'});
  });
}
