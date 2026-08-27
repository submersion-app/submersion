import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v174 is the current schema version (exact-latest tripwire)', () {
    expect(AppDatabase.currentSchemaVersion, 174);
    expect(AppDatabase.migrationVersions, contains(174));
  });

  test('a fresh database has connected_accounts.diver_id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('connected_accounts')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('diver_id'));
  });

  test(
    'a database stranded before v174 gains diver_id via beforeOpen',
    () async {
      // Only the columns this migration touches are modelled. The beforeOpen
      // backstop must add diver_id even when onUpgrade never ran.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE connected_accounts (
            id TEXT NOT NULL PRIMARY KEY,
            kind TEXT NOT NULL,
            account_identifier TEXT
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('connected_accounts')")
          .get();
      expect(
        cols.map((c) => c.read<String>('name')).toSet(),
        contains('diver_id'),
      );
    },
  );
}
