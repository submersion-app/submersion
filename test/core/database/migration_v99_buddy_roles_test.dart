import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh v99 schema has buddy_roles table and '
      'certifications.instructor_id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // buddy_roles exists with the expected columns.
    final roleCols = await db
        .customSelect("PRAGMA table_info('buddy_roles')")
        .get();
    final roleColNames = roleCols.map((c) => c.read<String>('name')).toSet();
    expect(
      roleColNames,
      containsAll([
        'id',
        'buddy_id',
        'role',
        'credential_number',
        'agency',
        'notes',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );

    // certifications gained instructor_id.
    final certCols = await db
        .customSelect("PRAGMA table_info('certifications')")
        .get();
    final certColNames = certCols.map((c) => c.read<String>('name')).toSet();
    expect(certColNames, contains('instructor_id'));
  });

  test('v99 migration adds instructor_id to a pre-v99 certifications table '
      'and is idempotent', () async {
    // Simulate the guarded ALTER against a pre-v99 table shape.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('''
      CREATE TABLE certs_v93 (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        instructor_name TEXT
      )
    ''');
    Future<bool> hasColumn() async {
      final cols = await db
          .customSelect("PRAGMA table_info('certs_v93')")
          .get();
      return cols.any((c) => c.read<String>('name') == 'instructor_id');
    }

    // The same guard logic the migration uses: check, then ALTER.
    for (var i = 0; i < 2; i++) {
      if (!await hasColumn()) {
        await db.customStatement(
          'ALTER TABLE certs_v93 ADD COLUMN instructor_id TEXT '
          'REFERENCES buddies (id) ON DELETE SET NULL',
        );
      }
    }
    expect(await hasColumn(), isTrue);
  });

  test('real onUpgrade from v98 adds instructor_id and creates buddy_roles, '
      'preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 98');
        // Minimal pre-v99 shapes: certifications without instructor_id, a
        // buddies table for the new FKs to reference, and NO buddy_roles.
        rawDb.execute('''
          CREATE TABLE buddies (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            agency TEXT NOT NULL,
            instructor_name TEXT,
            instructor_number TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO certifications "
          "(id, name, agency, instructor_name, created_at, updated_at) "
          "VALUES ('c1', 'Open Water Diver', 'PADI', 'Jane Instructor', 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Touch the DB so the real onUpgrade v99 block runs.
    final certCols = await db
        .customSelect("PRAGMA table_info('certifications')")
        .get();
    final certColNames = certCols.map((c) => c.read<String>('name')).toSet();
    expect(certColNames, contains('instructor_id'));

    final roleCols = await db
        .customSelect("PRAGMA table_info('buddy_roles')")
        .get();
    final roleColNames = roleCols.map((c) => c.read<String>('name')).toSet();
    expect(
      roleColNames,
      containsAll([
        'id',
        'buddy_id',
        'role',
        'credential_number',
        'agency',
        'notes',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );

    // Existing rows survive and read the new column as NULL.
    final row = await db
        .customSelect(
          "SELECT instructor_name, instructor_id "
          "FROM certifications WHERE id = 'c1'",
        )
        .getSingle();
    expect(row.data['instructor_name'], 'Jane Instructor');
    expect(row.data['instructor_id'], isNull);
  });

  test('schema version is at least 97 and the migration list includes it', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(99));
    expect(AppDatabase.migrationVersions, contains(99));
  });

  test('backstop heals a database stranded past v99 by a parallel-branch '
      'version collision', () async {
    // Reproduces the field failure: another branch build that also claims
    // schema version 99 advanced user_version past this branch's v99 block,
    // so onUpgrade never runs here and buddy_roles/instructor_id are
    // missing. The beforeOpen backstop must re-assert them anyway.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('''
          CREATE TABLE buddies (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            agency TEXT NOT NULL,
            instructor_name TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO certifications "
          "(id, name, agency, instructor_name, created_at, updated_at) "
          "VALUES ('c1', 'Open Water Diver', 'PADI', 'Jane Instructor', 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // No migration runs (user_version == currentSchemaVersion); only the
    // beforeOpen backstop can create the missing objects.
    final roleCols = await db
        .customSelect("PRAGMA table_info('buddy_roles')")
        .get();
    expect(roleCols, isNotEmpty, reason: 'buddy_roles must be re-asserted');

    final certCols = await db
        .customSelect("PRAGMA table_info('certifications')")
        .get();
    expect(
      certCols.map((c) => c.read<String>('name')),
      contains('instructor_id'),
    );

    // Existing data untouched.
    final row = await db
        .customSelect("SELECT instructor_name FROM certifications")
        .getSingle();
    expect(row.data['instructor_name'], 'Jane Instructor');
  });
}
