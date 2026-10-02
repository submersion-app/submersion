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
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', $now, $now)",
    );
    await sql(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('ian', 'Ian', $now, $now)",
    );
    await sql(
      'INSERT INTO courses (id, diver_id, name, agency, start_date, '
      'completion_date, instructor_id, certification_id, location, '
      'created_at, updated_at) VALUES '
      "('aow', 'me', 'AOW', 'padi', $now, $now, 'ian', NULL, 'Bonaire Dive', "
      '$now, $now), '
      "('tec', 'me', 'Tec 40', 'tdi', $now, NULL, NULL, 'cTec', NULL, $now, "
      '$now)',
    );
    await sql(
      'INSERT INTO certifications (id, diver_id, course_id, name, agency, '
      "created_at, updated_at) VALUES ('cAow', 'me', 'aow', 'AOW card', "
      "'padi', $now, $now), ('cTec', 'me', NULL, 'Tec card', 'tdi', $now, "
      '$now)',
    );
    await sql(
      'INSERT INTO dives (id, dive_date_time, course_id, created_at, '
      "updated_at) VALUES ('d1', $now, 'aow', $now, $now)",
    );
  });
  tearDown(tearDownTestDatabase);

  final courses = appQueryRegistry.entityFor(QuerySubject.courses);
  final parser = QueryParser(
    appQueryRegistry,
    courses,
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
    expect(validateQuery(node, courses, appQueryRegistry), isEmpty);
    final q = compileQuery(node, courses, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('agency, instructor, certification and dives are queryable', () async {
    expect(await ids('agency = tdi'), {'tec'});
    expect(await ids('instructor.name = Ian'), {'aow'});
    // Either link direction finds the certification.
    expect(await ids('certification.name = "AOW card"'), {'aow'});
    expect(await ids('certification.name = "Tec card"'), {'tec'});
    expect(await ids('dives:any'), {'aow'});
    expect(await ids('completionDate:none'), {'tec'});
    expect(await ids('"bonaire"'), {'aow'});
  });
}
