import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v110 drops the inline buddy certification columns but preserves the '
      'migrated cert row', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 109');
        // buddies still has the inline columns at v109.
        rawDb.execute('''
          CREATE TABLE buddies (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
            email TEXT, phone TEXT, certification_level TEXT,
            certification_agency TEXT, photo_path TEXT,
            notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
        rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, buddy_id TEXT,
            name TEXT NOT NULL, agency TEXT NOT NULL, level TEXT,
            card_number TEXT, issue_date INTEGER, expiry_date INTEGER,
            instructor_name TEXT, instructor_number TEXT, instructor_id TEXT,
            photo_front_path TEXT, photo_back_path TEXT, photo_front BLOB,
            photo_back BLOB, course_id TEXT, notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO buddies (id, name, created_at, updated_at) "
          "VALUES ('b1', 'Sarah', 0, 0)",
        );
        rawDb.execute(
          "INSERT INTO certifications (id, buddy_id, name, agency, level, "
          "created_at, updated_at) VALUES ('buddycert-b1', 'b1', '2 Star', "
          "'cmas', 'cmas2StarDiver', 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final buddyCols = await db
        .customSelect("PRAGMA table_info('buddies')")
        .get();
    final names = buddyCols.map((c) => c.read<String>('name')).toSet();
    expect(names, isNot(contains('certification_level')));
    expect(names, isNot(contains('certification_agency')));

    // The migrated cert row survives the column drop.
    final cert = await db
        .customSelect("SELECT * FROM certifications WHERE buddy_id = 'b1'")
        .getSingle();
    expect(cert.data['level'], 'cmas2StarDiver');
  });

  test('v110 safety copy migrates a still-inline buddy cert before dropping '
      '(covers a collision that reached v109 without the copy)', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 109');
        rawDb.execute('''
          CREATE TABLE buddies (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
            email TEXT, phone TEXT, certification_level TEXT,
            certification_agency TEXT, photo_path TEXT,
            notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
        rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, buddy_id TEXT,
            name TEXT NOT NULL, agency TEXT NOT NULL, level TEXT,
            card_number TEXT, issue_date INTEGER, expiry_date INTEGER,
            instructor_name TEXT, instructor_number TEXT, instructor_id TEXT,
            photo_front_path TEXT, photo_back_path TEXT, photo_front BLOB,
            photo_back BLOB, course_id TEXT, notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO buddies (id, name, certification_level, "
          "certification_agency, created_at, updated_at) "
          "VALUES ('b9', 'Uncopied', 'rescue', 'padi', 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cert = await db
        .customSelect("SELECT * FROM certifications WHERE buddy_id = 'b9'")
        .getSingle();
    expect(cert.data['level'], 'rescue');
    expect(cert.data['id'], 'buddycert-b9');
  });

  test('version ladder includes 110', () {
    // Relaxed when v111 (#583) landed; the exact-latest tripwire moved to the
    // newest migration's test.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(110));
    expect(AppDatabase.migrationVersions, contains(110));
  });
}
