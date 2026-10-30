import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_course_identity.dart';
import 'package:submersion/core/database/dive_course_links_schema.dart';

/// v288 (issue #2515): the dive_courses junction, its seed from the
/// representative dives.course_id, and the certification side becoming the
/// truth for a course's certifications.
void main() {
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 283');
      rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
      rawDb.execute(
        'CREATE TABLE courses (id TEXT PRIMARY KEY, diver_id TEXT, '
        'name TEXT, agency TEXT, start_date INTEGER, '
        'certification_id TEXT, created_at INTEGER, updated_at INTEGER)',
      );
      rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY, course_id TEXT)');
      rawDb.execute(
        'CREATE TABLE certifications (id TEXT PRIMARY KEY, name TEXT, '
        'issue_date INTEGER, course_id TEXT, updated_at INTEGER)',
      );
      rawDb.execute(
        "INSERT INTO courses VALUES ('c1','d','AN','tdi',100,'k1',0,0)",
      );
      rawDb.execute(
        "INSERT INTO courses VALUES ('c2','d','DP','tdi',200,'k2',0,0)",
      );
      rawDb.execute("INSERT INTO dives VALUES ('v1','c1')");
      rawDb.execute("INSERT INTO dives VALUES ('v2',NULL)");
      // k1 is linked only from the course side. k2 already points at c1, so
      // the certification side wins and c2 loses it.
      rawDb.execute("INSERT INTO certifications VALUES ('k1','AN',1,NULL,0)");
      rawDb.execute("INSERT INTO certifications VALUES ('k2','DP',2,'c1',0)");
      // An older app version only half-unlinked (#2515): swapping c3's card
      // from k5 to k4 rewrote c3 at 100 and left k5 pointing at it.
      rawDb.execute(
        "INSERT INTO courses VALUES ('c3','d','Swap','padi',300,'k4',0,100)",
      );
      rawDb.execute(
        "INSERT INTO certifications VALUES ('k4','New',4,NULL,100)",
      );
      rawDb.execute("INSERT INTO certifications VALUES ('k5','Old',5,'c3',50)");
      // Clearing c5's card rewrote c5 at 100 and left k8 pointing at it.
      rawDb.execute(
        "INSERT INTO courses VALUES ('c5','d','Clear','padi',500,NULL,0,100)",
      );
      rawDb.execute(
        "INSERT INTO certifications VALUES ('k8','Gone',8,'c5',50)",
      );
      // A device already on v288 linked two cards to c4: both written at or
      // after the course, so both are real links.
      rawDb.execute(
        "INSERT INTO courses VALUES ('c4','d','Multi','tdi',400,'k6',0,100)",
      );
      rawDb.execute("INSERT INTO certifications VALUES ('k6','A',6,'c4',100)");
      rawDb.execute("INSERT INTO certifications VALUES ('k7','B',7,'c4',120)");
    },
  );

  Future<List<Map<String, Object?>>> rows(AppDatabase db, String sql) async => [
    for (final r in await db.customSelect(sql).get()) r.data,
  ];

  test('v288 is in the ladder and leaves the sync floor alone', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(288));
    expect(AppDatabase.migrationVersions, contains(288));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(288));
  });

  test('creates dive_courses with its columns', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final cols = await rows(db, 'PRAGMA table_info(dive_courses)');
    expect(
      {for (final c in cols) c['name']},
      {'id', 'dive_id', 'course_id', 'created_at', 'hlc'},
    );
  });

  test('seeds one deterministic link per dive course', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final links = await rows(db, 'SELECT * FROM dive_courses');
    expect(links, hasLength(1));
    expect(links.single['id'], diveCourseLinkId('v1', 'c1'));
    expect(links.single['dive_id'], 'v1');
    expect(links.single['course_id'], 'c1');
    expect(links.single['hlc'], isNull);
  });

  test('the seed is idempotent', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(await seedDiveCourseLinks(db), 0);
    expect(await rows(db, 'SELECT id FROM dive_courses'), hasLength(1));
  });

  test('the pair is unique', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await expectLater(
      db.customStatement(
        'INSERT INTO dive_courses (id, dive_id, course_id, created_at) '
        "VALUES ('other', 'v1', 'c1', 0)",
      ),
      throwsA(anything),
    );
  });

  test(
    'certification side becomes the truth, representatives follow',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      expect(
        await rows(db, 'SELECT id, course_id FROM certifications ORDER BY id'),
        [
          {'id': 'k1', 'course_id': 'c1'},
          {'id': 'k2', 'course_id': 'c1'},
          {'id': 'k4', 'course_id': 'c3'},
          {'id': 'k5', 'course_id': null},
          {'id': 'k6', 'course_id': 'c4'},
          {'id': 'k7', 'course_id': 'c4'},
          {'id': 'k8', 'course_id': null},
        ],
      );
      expect(
        await rows(db, 'SELECT id, certification_id FROM courses ORDER BY id'),
        [
          {'id': 'c1', 'certification_id': 'k1'},
          {'id': 'c2', 'certification_id': null},
          {'id': 'c3', 'certification_id': 'k4'},
          {'id': 'c4', 'certification_id': 'k6'},
          {'id': 'c5', 'certification_id': null},
        ],
      );
    },
  );

  test('the link id is stable for a pair and differs across pairs', () {
    expect(diveCourseLinkId('v1', 'c1'), diveCourseLinkId('v1', 'c1'));
    expect(diveCourseLinkId('v1', 'c1'), isNot(diveCourseLinkId('v1', 'c2')));
    expect(diveCourseLinkId('v1', 'c1'), isNot(diveCourseLinkId('c1', 'v1')));
  });

  test('a fresh database has the table and the unique index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final idx = await rows(
      db,
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name = 'idx_dive_courses_dive_course_unique'",
    );
    expect(idx, hasLength(1));
  });

  test(
    'beforeOpen heals a database already at 288 without the table',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA user_version = 288');
            rawDb.execute('CREATE TABLE courses (id TEXT PRIMARY KEY)');
            rawDb.execute(
              'CREATE TABLE dives (id TEXT PRIMARY KEY, course_id TEXT)',
            );
            rawDb.execute("INSERT INTO courses VALUES ('c1')");
            rawDb.execute("INSERT INTO dives VALUES ('v1','c1')");
          },
        ),
      );
      addTearDown(db.close);
      expect(await rows(db, 'SELECT id FROM dive_courses'), hasLength(1));
    },
  );
}
