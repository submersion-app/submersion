import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Pre-v188 divers shape: insurance provider, policy and expiry, but no way
/// to record the insurer's own phone numbers (issue #1522).
const _preV188Divers = '''
  CREATE TABLE divers (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    medical_notes TEXT NOT NULL DEFAULT '',
    insurance_provider TEXT,
    insurance_policy_number TEXT,
    insurance_expiry_date INTEGER,
    notes TEXT NOT NULL DEFAULT '',
    is_default INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
''';

const _seedDiver =
    "INSERT INTO divers "
    "(id, name, insurance_provider, insurance_policy_number, "
    "created_at, updated_at) "
    "VALUES ('d1', 'Alice Alpha', 'ARENA', 'POL-1', 100, 100)";

void main() {
  test('v188 adds both insurance phone columns, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 187');
        rawDb.execute(_preV188Divers);
        rawDb.execute(_seedDiver);
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db.customSelect("PRAGMA table_info('divers')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('insurance_emergency_phone'));
    expect(names, contains('insurance_phone'));

    final row = await db
        .customSelect(
          'SELECT name, insurance_provider, insurance_emergency_phone, '
          "insurance_phone FROM divers WHERE id = 'd1'",
        )
        .getSingle();
    expect(row.data['name'], 'Alice Alpha');
    expect(row.data['insurance_provider'], 'ARENA');
    expect(
      row.data['insurance_emergency_phone'],
      isNull,
      reason: 'nothing in an old database can tell us the insurer hotline',
    );
    expect(row.data['insurance_phone'], isNull);
  });

  test('v188 is the current schema version and is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 188);
    expect(AppDatabase.migrationVersions, contains(188));
  });

  test('v188 is idempotent when both columns already exist', () async {
    // An interrupted upgrade, or a database that reached this version number
    // from a parallel branch, leaves the columns already added. The PRAGMA
    // guard must skip the ALTER rather than fail on a duplicate column.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 187');
        rawDb.execute(_preV188Divers);
        rawDb.execute(
          'ALTER TABLE divers ADD COLUMN insurance_emergency_phone TEXT',
        );
        rawDb.execute('ALTER TABLE divers ADD COLUMN insurance_phone TEXT');
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final names = (await db.customSelect("PRAGMA table_info('divers')").get())
        .map((c) => c.read<String>('name'))
        .toList();
    expect(names.where((n) => n == 'insurance_emergency_phone'), hasLength(1));
    expect(names.where((n) => n == 'insurance_phone'), hasLength(1));
  });

  test('v188 adds the missing column when only one landed', () async {
    // The two ALTERs are guarded independently, so an upgrade interrupted
    // between them must still finish on the next open.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 187');
        rawDb.execute(_preV188Divers);
        rawDb.execute(
          'ALTER TABLE divers ADD COLUMN insurance_emergency_phone TEXT',
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final names = (await db.customSelect("PRAGMA table_info('divers')").get())
        .map((c) => c.read<String>('name'))
        .toSet();
    expect(names, contains('insurance_emergency_phone'));
    expect(names, contains('insurance_phone'));
  });

  test('the helper no-ops when divers is absent', () async {
    // Partial-schema case: migration tests instantiate databases without
    // unrelated tables, and unguarded DDL would fail with "no such table".
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 187');
        // Deliberately no divers table at all.
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final result = await db.customSelect('SELECT 1 AS ok').getSingle();
    expect(result.data['ok'], 1);
  });
}
