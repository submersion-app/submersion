import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  test('rung 289 creates the shared library tables', () async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'shared_libraries',
        'shared_library_members',
        'shared_library_memberships',
        'shared_site_states',
        'shared_site_suggestions',
      ]),
    );
  });

  test('dive_sites carries shared_library_id', () async {
    final cols = await db.customSelect("PRAGMA table_info('dive_sites')").get();
    expect(
      cols.map((r) => r.read<String>('name')),
      contains('shared_library_id'),
    );
  });

  test('rung 289 is on the ladder', () {
    // Later rungs follow it; only its presence is this feature's concern.
    expect(AppDatabase.migrationVersions, contains(289));
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(289));
  });

  Future<Set<String>> columnsOf(AppDatabase d, String table) async =>
      (await d.customSelect("PRAGMA table_info('$table')").get())
          .map((r) => r.read<String>('name'))
          .toSet();

  test('v289 carries keys, trust state and backups', () async {
    expect(
      await columnsOf(db, 'shared_library_memberships'),
      containsAll([
        'signing_public_key',
        'signing_private_key',
        'library_key_id',
        'library_key',
      ]),
    );
    expect(
      await columnsOf(db, 'shared_libraries'),
      containsAll([
        'roles_rejected',
        'pending_roles_json',
        'encrypted',
        'key_id',
        'last_auto_backup_at',
      ]),
    );
    expect(
      await columnsOf(db, 'shared_library_backups'),
      contains('backup_id'),
    );
    expect(
      await columnsOf(db, 'library_site_notes'),
      containsAll(['diver_id', 'site_id', 'notes', 'rating', 'hlc']),
    );
  });

  test('a database already at 290 gains them through the backstop', () async {
    // Built by an earlier build of this branch: the v289 tables without the
    // new columns, and no backups table.
    final nativeDb = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
          CREATE TABLE shared_libraries (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            connected_account_id TEXT NOT NULL,
            prefix TEXT NOT NULL DEFAULT '',
            format_version INTEGER NOT NULL DEFAULT 1,
            read_only_detected INTEGER NOT NULL DEFAULT 0,
            roles_json TEXT NOT NULL DEFAULT '{}',
            last_sync_at INTEGER,
            last_error TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        raw.execute('''
          CREATE TABLE shared_library_memberships (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT NOT NULL,
            library_id TEXT NOT NULL,
            member_id TEXT NOT NULL,
            display_name TEXT NOT NULL,
            library_name TEXT NOT NULL,
            backend_kind TEXT NOT NULL,
            location_hint TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
      },
    );
    final old = AppDatabase(nativeDb);
    addTearDown(old.close);
    expect(
      await columnsOf(old, 'shared_library_memberships'),
      containsAll(['signing_private_key', 'library_key']),
    );
    expect(
      await columnsOf(old, 'shared_libraries'),
      contains('pending_roles_json'),
    );
    expect(await columnsOf(old, 'shared_library_backups'), contains('pinned'));
    expect(await columnsOf(old, 'library_site_notes'), contains('notes'));
    expect(await columnsOf(old, 'shared_libraries'), contains('description'));
  });

  test('rung 291 adds the library description (issue #3389)', () async {
    expect(AppDatabase.migrationVersions, contains(291));
    expect(await columnsOf(db, 'shared_libraries'), contains('description'));
  });
}
