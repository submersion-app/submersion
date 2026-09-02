import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v171 adds `trip_day_weather`: fetched historical weather for trip days
/// whose dives supply none of their own (surface days and dive-free itinerary
/// days). Its own table rather than columns on `trips` or `trip_itinerary_days`
/// because HLC conflicts resolve per row, and an automatic derived write must
/// not race the diver's hand edits on the same row.
NativeDatabase _dbAt164() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 164');
      rawDb.execute('''
        CREATE TABLE trips (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          start_date INTEGER NOT NULL,
          end_date INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute(
        "INSERT INTO trips (id, name, start_date, end_date, created_at, "
        "updated_at) VALUES ('t1', 'Bonaire', 0, 0, 0, 0)",
      );
    },
  );
}

Future<Set<String>> _columnsOf(AppDatabase db, String table) async {
  final cols = await db.customSelect("PRAGMA table_info('$table')").get();
  return cols.map((c) => c.read<String>('name')).toSet();
}

void main() {
  test('v171 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(171));
    expect(AppDatabase.migrationVersions, contains(171));
  });

  test('a fresh database has trip_day_weather with every column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(
      await _columnsOf(db, 'trip_day_weather'),
      containsAll(<String>{
        'id',
        'trip_id',
        'date',
        'latitude',
        'longitude',
        'air_temp',
        'cloud_cover',
        'precipitation',
        'wind_speed',
        'wind_direction',
        'humidity',
        'surface_pressure',
        'weather_code',
        'weather_source',
        'fetched_at',
        'created_at',
        'updated_at',
        'hlc',
      }),
    );
  });

  test('the weather payload columns are all nullable', () async {
    // A fetch that resolves only some fields must still store a row; every
    // reading is independently optional.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('trip_day_weather')")
        .get();
    for (final name in <String>[
      'air_temp',
      'cloud_cover',
      'precipitation',
      'wind_speed',
      'wind_direction',
      'humidity',
      'surface_pressure',
      'weather_code',
    ]) {
      final column = cols.firstWhere((c) => c.read<String>('name') == name);
      expect(column.read<int>('notnull'), 0, reason: '$name must be nullable');
    }
  });

  test('one row per trip and date', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('PRAGMA foreign_keys = OFF');

    Future<void> insert(String id) => db.customStatement(
      'INSERT INTO trip_day_weather '
      '(id, trip_id, date, latitude, longitude, weather_source, '
      'fetched_at, created_at, updated_at) '
      "VALUES ('$id', 't1', 1000, 1.0, 2.0, 'openMeteo', 1, 1, 1)",
    );

    await insert('a');
    // Two devices that both fetch the same day must converge on one row
    // rather than accumulating duplicates.
    await expectLater(insert('b'), throwsA(anything));
  });

  test('a database at v164 gains the table and keeps its rows', () async {
    final db = AppDatabase(_dbAt164());
    addTearDown(db.close);

    expect(await _columnsOf(db, 'trip_day_weather'), isNotEmpty);
    final trip = await db
        .customSelect("SELECT name FROM trips WHERE id = 't1'")
        .getSingle();
    expect(trip.read<String>('name'), 'Bonaire');
  });

  test('a database stranded at a parallel-branch v171 gains the table via '
      'beforeOpen', () async {
    // Stamped AT 171 but without the table: the onUpgrade block never runs,
    // so only the beforeOpen backstop can create it.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 171');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _columnsOf(db, 'trip_day_weather'), isNotEmpty);
  });
}
