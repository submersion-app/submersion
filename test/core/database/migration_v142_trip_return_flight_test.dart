import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v142 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(142));
    expect(AppDatabase.migrationVersions, contains(142));
  });

  test('a fresh database has trips.return_flight_at', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('trips')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('return_flight_at'));
  });

  test(
    'a database stranded before v142 gains return_flight_at via beforeOpen',
    () async {
      // Only the columns this migration touches are modelled. The beforeOpen
      // backstop must add return_flight_at even when onUpgrade never ran
      // (v138/v140/v141 are reserved by parallel branches, so a DB can
      // arrive at an intermediate version without this column).
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE trips (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT,
            start_date INTEGER,
            end_date INTEGER
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db.customSelect("PRAGMA table_info('trips')").get();
      expect(
        cols.map((c) => c.read<String>('name')).toSet(),
        contains('return_flight_at'),
      );
    },
  );

  test('the assert is a no-op when the trips table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    // Opening must not throw on a minimal fixture.
    await db.customSelect('SELECT 1').get();
  });
}
