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
      'INSERT INTO buddies (id, name, email, phone, created_at, updated_at) '
      "VALUES ('ann', 'Ann', 'ann@reef.test', '555-0100', $now, $now), "
      "('bob', 'Bob', NULL, NULL, $now, $now)",
    );
    await sql(
      'INSERT INTO dives (id, dive_date_time, max_depth, created_at, '
      "updated_at) VALUES ('d1', $now, 32, $now, $now)",
    );
    await sql(
      'INSERT INTO dive_buddies (id, dive_id, buddy_id, created_at) '
      "VALUES ('db1', 'd1', 'ann', $now)",
    );
  });
  tearDown(tearDownTestDatabase);

  final buddies = appQueryRegistry.entityFor(QuerySubject.buddies);
  final parser = QueryParser(
    appQueryRegistry,
    buddies,
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
    expect(validateQuery(node, buddies, appQueryRegistry), isEmpty);
    final q = compileQuery(node, buddies, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('dives and text search are queryable', () async {
    expect(await ids('dives:any'), {'ann'});
    expect(await ids('dives:none'), {'bob'});
    expect(await ids('dives.maxDepth > 30'), {'ann'});
    expect(await ids('"reef.test"'), {'ann'});
    expect(await ids('"0100"'), {'ann'});
    expect(await ids('"bo"'), {'bob'});
  });
}
