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
      "VALUES ('ann', 'Ann', $now, $now), ('bob', 'Bob', $now, $now)",
    );
    await sql(
      'INSERT INTO courses (id, diver_id, name, agency, start_date, '
      "created_at, updated_at) VALUES ('aow', 'me', 'AOW', 'padi', $now, "
      '$now, $now)',
    );
    await sql(
      'INSERT INTO certifications (id, diver_id, buddy_id, instructor_id, '
      'course_id, name, agency, level, card_number, created_at, updated_at) '
      "VALUES ('c1', 'me', NULL, NULL, 'aow', 'Open Water', 'padi', "
      "'openWater', 'PX-1', $now, $now), "
      "('c2', NULL, 'ann', 'bob', NULL, 'Rescue', 'ssi', 'rescue', NULL, "
      '$now, $now), '
      "('c3', 'me', NULL, NULL, NULL, 'Old card', 'other', 'mysteryLevel', "
      'NULL, $now, $now)',
    );
  });
  tearDown(tearDownTestDatabase);

  final certs = appQueryRegistry.entityFor(QuerySubject.certifications);
  final parser = QueryParser(
    appQueryRegistry,
    certs,
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
    expect(validateQuery(node, certs, appQueryRegistry), isEmpty);
    final q = compileQuery(node, certs, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test(
    'agency and level are enums; owner, instructor, course are hops',
    () async {
      expect(await ids('agency = padi'), {'c1'});
      expect(await ids('level in [rescue, openWater]'), {'c1', 'c2'});
      expect(await ids('buddy.name = Ann'), {'c2'});
      expect(await ids('instructor.name = Bob'), {'c2'});
      expect(await ids('course.name = AOW'), {'c1'});
      expect(await ids('"px-1"'), {'c1'});
    },
  );

  test('the course hop reads either stored link direction', () async {
    // The link can be stored on the course side only (an import or a sync);
    // the certification detail page shows it, so the query must find it.
    await db.customStatement(
      'INSERT INTO courses (id, diver_id, name, agency, start_date, '
      "certification_id, created_at, updated_at) VALUES ('res', 'me', "
      "'Rescue course', 'ssi', $now, 'c2', $now, $now)",
    );
    expect(await ids('course.name = "Rescue course"'), {'c2'});
    expect(await ids('course.name = AOW'), {'c1'});
  });

  test('an unknown stored level is set but equals nothing', () async {
    expect(await ids('level:any'), {'c1', 'c2', 'c3'});
    expect(await ids('level = other'), isEmpty);
  });

  test('an enum field refuses a value outside the enum', () {
    final parsed = parser.parse('level = notALevel');
    final errors = parsed is ParseOk
        ? validateQuery(parsed.node, certs, appQueryRegistry)
        : const ['parse refused'];
    expect(errors, isNotEmpty);
  });
}
