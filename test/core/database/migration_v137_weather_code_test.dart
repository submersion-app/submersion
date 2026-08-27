import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v137 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(137));
    expect(AppDatabase.migrationVersions, contains(137));
  });

  test('a fresh database has dives.weather_code', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('weather_code'));
  });

  test(
    'a database stranded before v137 gains weather_code via beforeOpen',
    () async {
      // Only the columns this migration touches are modelled. The beforeOpen
      // backstop must add weather_code even when onUpgrade never ran.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            weather_source TEXT,
            weather_description TEXT
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db.customSelect("PRAGMA table_info('dives')").get();
      expect(
        cols.map((c) => c.read<String>('name')).toSet(),
        contains('weather_code'),
      );
    },
  );

  test(
    'generated openMeteo descriptions are cleared, manual ones kept',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            weather_source TEXT,
            weather_description TEXT
          )
        ''');
          rawDb.execute(
            "INSERT INTO dives (id, weather_source, weather_description) "
            "VALUES ('a', 'openMeteo', 'Clear, 24C, light breeze from North')",
          );
          rawDb.execute(
            "INSERT INTO dives (id, weather_source, weather_description) "
            "VALUES ('b', 'manual', 'Glassy, no wind')",
          );
          rawDb.execute(
            "INSERT INTO dives (id, weather_source, weather_description) "
            "VALUES ('c', NULL, 'Imported from logbook')",
          );
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      await db.clearGeneratedWeatherDescriptionsForTesting();

      final rows = await db
          .customSelect('SELECT id, weather_description FROM dives ORDER BY id')
          .get();

      // Ours: regenerated at display time, so the frozen English is cleared.
      expect(rows[0].data['weather_description'], isNull);
      // Theirs: user data, left verbatim.
      expect(rows[1].data['weather_description'], 'Glassy, no wind');
      expect(rows[2].data['weather_description'], 'Imported from logbook');
    },
  );

  test('the clear is a no-op when the dives table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    // Must not throw on a minimal fixture.
    await db.clearGeneratedWeatherDescriptionsForTesting();
  });
}
