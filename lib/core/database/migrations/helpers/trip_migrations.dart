part of '../app_database_migrations.dart';

/// Trips, trip weather and trip cylinders.
extension TripMigrations on AppDatabase {
  /// v129: quality_findings table for the Data Quality Assistant.
  /// Idempotent so it is safe to call from both onUpgrade and the
  /// beforeOpen backstop.
  /// v171: fetched per-day trip weather.
  ///
  /// Idempotent, so it doubles as the beforeOpen backstop for a database
  /// stranded at 171 by a parallel branch that never created the table.
  Future<void> _assertTripDayWeatherSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS trip_day_weather (
        id TEXT NOT NULL PRIMARY KEY,
        trip_id TEXT NOT NULL REFERENCES trips (id),
        date INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        air_temp REAL,
        cloud_cover TEXT,
        precipitation TEXT,
        wind_speed REAL,
        wind_direction TEXT,
        humidity REAL,
        surface_pressure REAL,
        weather_code INTEGER,
        weather_source TEXT NOT NULL DEFAULT 'openMeteo',
        fetched_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    // The day is the identity: two devices that both fetch it must converge
    // on one row rather than accumulating duplicates.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_day_weather_trip_date '
      'ON trip_day_weather (trip_id, date)',
    );
  }

  /// Idempotent DDL for the v142 return-flight column. Called from the v142
  /// onUpgrade step and the beforeOpen backstop, matching the
  /// _assertWeatherCodeColumn pattern so a schema-version collision cannot
  /// strand a database without it. Self-guarding when the table is absent
  /// (minimal migration-test fixtures).
  Future<void> _assertTripReturnFlightColumn() async {
    final cols = await customSelect("PRAGMA table_info('trips')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('return_flight_at')) {
      await customStatement(
        'ALTER TABLE trips ADD COLUMN return_flight_at INTEGER',
      );
    }
  }

  /// Idempotent creation of the v232 trip cylinder tables and the
  /// dive_tanks.trip_cylinder_id link (issue #2325). Called from the v232
  /// rung and the beforeOpen backstop.
  ///
  /// Skipped on a partial migration-test fixture that lacks a parent table,
  /// so a fixture written for an older rung does not gain tables whose
  /// foreign keys point nowhere, nor a link column with no parent. The
  /// column is added after the tables so its reference has a target.
  Future<void> _assertTripCylindersSchema() async {
    for (final parent in const ['trips', 'equipment', 'dive_centers']) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(tripCylinders);
    await Migrator(this).createTable(tripCylinderEvents);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_trip_cylinders_trip_id '
      'ON trip_cylinders(trip_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_trip_cylinder_events_cylinder_id '
      'ON trip_cylinder_events(trip_cylinder_id)',
    );
    await _addColumnIfMissing(
      'dive_tanks',
      'trip_cylinder_id',
      'TEXT REFERENCES trip_cylinders(id) ON DELETE SET NULL',
    );
    if (await _tableExists('dive_tanks')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_dive_tanks_trip_cylinder '
        'ON dive_tanks(trip_cylinder_id)',
      );
    }
  }

  /// The trip_equipment table and its item index (v248, issue #2338).
  /// Called from the v248 rung and the beforeOpen backstop. Skipped on a
  /// partial migration-test fixture that lacks a parent table.
  Future<void> _assertTripEquipmentSchema() async {
    for (final parent in const ['trips', 'equipment']) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(tripEquipment);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_trip_equipment_equipment '
      'ON trip_equipment(equipment_id)',
    );
  }
}
