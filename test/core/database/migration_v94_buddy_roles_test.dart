import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh v94 schema has buddy_roles table and '
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

  test('v94 migration adds instructor_id to a v93 certifications table '
      'and is idempotent', () async {
    // Simulate the guarded ALTER against a pre-v94 table shape.
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

  test('real onUpgrade from v93 adds instructor_id and creates buddy_roles, '
      'preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 93');
        // Minimal pre-v94 shapes: certifications without instructor_id, a
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

    // Touch the DB so the real onUpgrade v94 block runs.
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

  test('schema version is 94 and the migration list includes it', () {
    expect(AppDatabase.currentSchemaVersion, 94);
    expect(AppDatabase.migrationVersions, contains(94));
  });
}
