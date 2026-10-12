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

/// `course` on dives reads the dive_courses junction (#2515).
void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', $now, $now)",
    );
    await sql(
      'INSERT INTO courses (id, diver_id, name, agency, start_date, '
      "created_at, updated_at) VALUES ('an', 'me', 'Advanced Nitrox', 'tdi', "
      "$now, $now, $now), ('dp', 'me', 'Deco Procedures', 'tdi', $now, $now, "
      '$now)',
    );
    await sql(
      'INSERT INTO dives (id, diver_id, dive_date_time, course_id, '
      "created_at, updated_at) VALUES ('v1', 'me', $now, 'an', $now, $now), "
      "('v2', 'me', $now, NULL, $now, $now)",
    );
    await sql(
      'INSERT INTO dive_courses (id, dive_id, course_id, created_at) VALUES '
      "('l1', 'v1', 'an', $now), ('l2', 'v1', 'dp', $now)",
    );
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  final parser = QueryParser(
    appQueryRegistry,
    dives,
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
    expect(validateQuery(node, dives, appQueryRegistry), isEmpty);
    final q = compileQuery(node, dives, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('a dive in two courses matches either course', () async {
    expect(await ids('course.name = "Advanced Nitrox"'), {'v1'});
    expect(await ids('course.name = "Deco Procedures"'), {'v1'});
  });

  test('course:none finds the dive with no course', () async {
    expect(await ids('course:none'), {'v2'});
  });
}
