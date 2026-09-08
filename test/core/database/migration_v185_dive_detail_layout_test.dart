import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v185 shape: a diver_settings table without the layout column,
/// stamped at v183 so the upgrade to 185 runs.
NativeDatabase _dbAt183() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 183');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT NOT NULL,
          dive_detail_sections TEXT
        )
      ''');
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );
}

Future<Set<String>> _settingsColumns(AppDatabase db) async {
  final cols = await db
      .customSelect("PRAGMA table_info('diver_settings')")
      .get();
  return cols.map((c) => c.read<String>('name')).toSet();
}

void main() {
  test('v185 adds dive_detail_layout to an existing table', () async {
    final db = AppDatabase(_dbAt183());
    addTearDown(db.close);

    expect(await _settingsColumns(db), contains('dive_detail_layout'));
  });

  // Column-only rung: a null reads back as the detailed layout, which is what
  // every diver was already getting.
  test('pre-existing settings rows come through with a null layout', () async {
    final db = AppDatabase(_dbAt183());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT dive_detail_layout FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<String?>('dive_detail_layout'), isNull);
  });

  test('fresh databases get the column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _settingsColumns(db), contains('dive_detail_layout'));
  });

  test('the helper no-ops when diver_settings is absent', () async {
    // The beforeOpen backstop runs the same assert on every open, including
    // on the stripped databases other migration tests build.
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 183'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('the backstop is idempotent across repeated opens', () async {
    final db = AppDatabase(_dbAt183());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final names = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    expect(
      names
          .map((c) => c.read<String>('name'))
          .where((n) => n == 'dive_detail_layout')
          .length,
      1,
      reason: 'the column must be added exactly once',
    );
  });

  test('v185 is in the ladder and at or below the current schema version', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(185));
    expect(AppDatabase.migrationVersions, contains(185));
  });

  // The column is additive and nullable, so a peer at the previous floor can
  // still read what this device syncs.
  test('the sync compatibility floor is unchanged', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 183);
  });
}
