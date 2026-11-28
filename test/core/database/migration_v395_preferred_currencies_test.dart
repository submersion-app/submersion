import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v395: diver_settings.preferred_currency_codes, the currencies each
/// diver lists first in the currency pickers (issue #4997). Nullable, no
/// backfill, so the sync floor holds.
void main() {
  /// A database at [version] whose diver_settings holds one row, with the
  /// column already present when [withColumn] is set.
  NativeDatabase setupDb(int version, {bool withColumn = false}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          rawDb.execute(
            'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
            'diver_id TEXT NOT NULL'
            '${withColumn ? ', preferred_currency_codes TEXT' : ''})',
          );
          rawDb.execute(
            withColumn
                ? 'INSERT INTO diver_settings '
                      '(id, diver_id, preferred_currency_codes) '
                      """VALUES ('s1', 'd1', '["BRL","EUR"]')"""
                : "INSERT INTO diver_settings (id, diver_id) "
                      "VALUES ('s1', 'd1')",
          );
        },
      );

  test('v395 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(395));
    expect(AppDatabase.migrationVersions, contains(395));
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(395));
  });

  test('upgrading from v394 adds a null preferred_currency_codes and keeps '
      'the row', () async {
    final db = AppDatabase(setupDb(394));
    addTearDown(db.close);
    final row = await db
        .customSelect(
          'SELECT diver_id, preferred_currency_codes FROM diver_settings',
        )
        .getSingle();
    expect(row.read<String>('diver_id'), 'd1');
    expect(row.read<String?>('preferred_currency_codes'), isNull);
  });

  // The rung re-runs on a database that already gained the column, and the
  // beforeOpen backstop runs on every open: neither may touch the choice.
  for (final version in [394, 395]) {
    test('a database at v$version already carrying the column keeps its '
        'preferred currencies', () async {
      final db = AppDatabase(setupDb(version, withColumn: true));
      addTearDown(db.close);
      final row = await db
          .customSelect('SELECT preferred_currency_codes FROM diver_settings')
          .getSingle();
      expect(row.read<String?>('preferred_currency_codes'), '["BRL","EUR"]');
    });
  }
}
