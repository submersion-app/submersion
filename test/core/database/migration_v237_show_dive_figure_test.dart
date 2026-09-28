import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v237: diver_settings.show_dive_figure, the diver-wide switch for the
/// diver figure in the dive detail equipment card (issue #2326). Off by
/// default for every diver; kept below main's v239, so a database already
/// past it gains the column through the beforeOpen backstop.
void main() {
  Future<Set<String>> settingsColumns(AppDatabase db) async {
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  NativeDatabase strandedAt(int? userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      if (userVersion != null) {
        rawDb.execute('PRAGMA user_version = $userVersion');
      }
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
    },
  );

  test('v237 is in the ladder, between v234 and v239', () {
    // Relaxed once v239 (regulator part service kinds) landed on top; the
    // newest rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(237));
    const ladder = AppDatabase.migrationVersions;
    expect(ladder, contains(237));
    expect(ladder.indexOf(237), greaterThan(ladder.indexOf(234)));
    expect(ladder.indexOf(237), lessThan(ladder.indexOf(239)));
  });

  test('the column is additive and did not move the sync floor', () {
    // An older reader ignores the column. v240 raised the floor later, for
    // its own reasons.
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      greaterThanOrEqualTo(224),
    );
  });

  test('a fresh database has the switch, off', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'show_dive_figure',
    );
    expect(column.read<int>('notnull'), 1);
    expect(column.read<String?>('dflt_value'), contains('0'));
  });

  test('a database stranded before v237 gains the column', () async {
    final db = AppDatabase(strandedAt(null));
    addTearDown(db.close);
    expect(await settingsColumns(db), contains('show_dive_figure'));
  });

  test(
    'a database already past v237 (at main v239) regains it via beforeOpen',
    () async {
      final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
      addTearDown(db.close);
      expect(await settingsColumns(db), contains('show_dive_figure'));
    },
  );
}
