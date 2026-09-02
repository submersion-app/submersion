import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/profile_series_pack.dart';

import '../../helpers/legacy_profile_fixtures.dart';

/// The v182 backstop packs on every open. A legacy row it cannot pack, or a
/// series table it cannot insert into, must never turn into a database that
/// cannot open: the ladder is where a packing failure is visible and retried,
/// the backstop is a self-heal that has to stay best-effort.
void main() {
  test('a series table missing a column an INDEX names does not fail the '
      'open', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    seedParents(raw);
    seedProfiles(raw);
    // Missing is_primary, which the schema self-heal's own index names.
    // CREATE TABLE IF NOT EXISTS is a no-op against a table of any shape,
    // so the DDL reaches CREATE INDEX ... (dive_id, is_primary) and SQLite
    // raises "no such column". The column the sibling test omits, samples,
    // is named by no index, so only this shape reaches that statement.
    raw.execute('''
      CREATE TABLE dive_profile_series (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        computer_id TEXT,
        source_id TEXT,
        samples BLOB NOT NULL
      )
    ''');

    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('a series table missing a column does not fail the open', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    seedParents(raw);
    seedProfiles(raw);
    // A pre-existing dive_profile_series without its samples column: the
    // IF NOT EXISTS DDL leaves it alone and every packer INSERT fails.
    raw.execute('''
      CREATE TABLE dive_profile_series (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        computer_id TEXT,
        source_id TEXT,
        is_primary INTEGER NOT NULL DEFAULT 1
      )
    ''');

    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('a legacy row with a null timestamp is skipped, counted, and does not '
      'fail the open', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    raw.execute('PRAGMA user_version = 182');
    raw.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
    raw.execute('CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)');
    raw.execute('''
      CREATE TABLE dive_data_sources (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        computer_id TEXT,
        is_primary INTEGER NOT NULL DEFAULT 0,
        imported_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute(
      'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
      'dive_id TEXT NOT NULL)',
    );
    // timestamp and depth nullable on purpose: a restored or hand-repaired
    // legacy table can hold such rows and the packer must step over them.
    raw.execute('''
      CREATE TABLE dive_profiles (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        computer_id TEXT,
        source_id TEXT,
        is_primary INTEGER NOT NULL DEFAULT 1,
        timestamp INTEGER,
        depth REAL
      )
    ''');
    raw.execute("INSERT INTO dives (id) VALUES ('d1')");
    raw.execute(
      "INSERT INTO dive_profiles (id, dive_id, timestamp, depth) VALUES "
      "('p1', 'd1', 0, 1.0), ('p2', 'd1', NULL, 2.0), ('p3', 'd1', 10, NULL), "
      "('p4', 'd1', 20, 3.0)",
    );

    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final row = await db
        .customSelect('SELECT sample_count FROM dive_profile_series')
        .getSingle();
    expect(row.read<int>('sample_count'), 2, reason: 'p2 and p3 are skipped');
    // A second explicit pack reports nothing new and no skipped rows,
    // because the dive already has a series row and is not revisited.
    final again = await packLegacyProfileRows(db, nowMs: 1);
    expect(again.profileSeries, 0);
    expect(again.skippedRows, 0);
  });
}
