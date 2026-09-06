import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database.dart';

/// Pre-v194 shape: no provenance table at all. That is every database the
/// fleet is carrying today, and the population issue #1568 stranded.
void main() {
  test('v194 creates database_provenance with the frozen shape', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 193'),
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final columns = await db
        .customSelect("PRAGMA table_info('database_provenance')")
        .get();
    final byName = {
      for (final column in columns)
        column.read<String>('name'): column.read<String>('type'),
    };

    // The shape is frozen: a key/value pair, both TEXT, key as the primary
    // key. Builds that ship from this rung onward only know how to read this,
    // so a future rung must add KEYS, never columns.
    expect(byName.keys, unorderedEquals(['key', 'value']));
    expect(byName['key'], 'TEXT');
    expect(byName['value'], 'TEXT');
    expect(
      columns
          .singleWhere((c) => c.read<String>('name') == 'key')
          .read<int>('pk'),
      1,
    );
  });

  test('the rung is idempotent when the table already exists', () async {
    // An interrupted upgrade, or a database that reached this rung from a
    // parallel branch, already has the table. createTable is IF NOT EXISTS,
    // so the rung must skip rather than fail on a duplicate.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 193');
        rawDb.execute(
          'CREATE TABLE database_provenance ('
          'key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
        );
        rawDb.execute(
          "INSERT INTO database_provenance (key, value) "
          "VALUES ('app_version', '1.7.7.8064')",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final rows = await db
        .customSelect('SELECT key, value FROM database_provenance')
        .get();
    expect(rows.single.data['value'], '1.7.7.8064');
  });

  test('migration list includes v194 and the schema is at 194', () {
    expect(AppDatabase.currentSchemaVersion, 194);
    expect(AppDatabase.migrationVersions, contains(194));
  });

  test('the beforeOpen backstop recreates a table that went missing', () async {
    // A parallel-branch version collision can leave a database already AT or
    // past 194 without ever having run the rung. That matters more here than
    // for the other table backstops: an older build reads this table out of a
    // newer file, so a database that never got it could never explain itself.
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);

    final created = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    await created.customSelect('SELECT 1').get();
    await created.customStatement('DROP TABLE database_provenance');
    await created.close();

    final reopened = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(reopened.close);
    await reopened.customSelect('SELECT 1').get();

    final tables = await reopened
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'database_provenance'",
        )
        .get();
    expect(tables, hasLength(1));
  });
}
