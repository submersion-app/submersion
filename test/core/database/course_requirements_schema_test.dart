import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../helpers/test_database.dart';

Future<Set<String>> _columns(String table) async {
  final db = DatabaseService.instance.database;
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.data['name'] as String).toSet();
}

Future<void> _seedCourseFixture() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO dives (id, diver_id, dive_date_time, created_at, updated_at) "
    "VALUES ('dive-1', 'diver-1', 2000, 1000, 1000)",
  );
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('v121 course requirement schema', () {
    test('course_requirements has the expected columns', () async {
      final cols = await _columns('course_requirements');
      expect(
        cols,
        containsAll({
          'id',
          'course_id',
          'name',
          'kind',
          'target_count',
          'completed_at',
          'sort_order',
          'notes',
          'created_at',
          'updated_at',
          'hlc',
        }),
      );
    });

    test(
      'course_requirement_dives has the expected columns and no hlc',
      () async {
        final cols = await _columns('course_requirement_dives');
        expect(
          cols,
          containsAll({'id', 'requirement_id', 'dive_id', 'created_at'}),
        );
        expect(cols, isNot(contains('hlc')));
      },
    );

    test('deleting a course cascades requirements and links', () async {
      final db = DatabaseService.instance.database;
      await _seedCourseFixture();
      await db.customStatement(
        "INSERT INTO course_requirements (id, course_id, name, kind, "
        "target_count, sort_order, created_at, updated_at) "
        "VALUES ('req-1', 'course-1', 'Deep adventure dive', 'dive', 1, 0, "
        "1000, 1000)",
      );
      await db.customStatement(
        "INSERT INTO course_requirement_dives (id, requirement_id, dive_id, "
        "created_at) VALUES ('link-1', 'req-1', 'dive-1', 1000)",
      );

      await db.customStatement("DELETE FROM courses WHERE id = 'course-1'");

      final reqs = await db
          .customSelect('SELECT COUNT(*) AS c FROM course_requirements')
          .getSingle();
      final links = await db
          .customSelect('SELECT COUNT(*) AS c FROM course_requirement_dives')
          .getSingle();
      expect(reqs.data['c'], 0);
      expect(links.data['c'], 0);
    });
  });
}
