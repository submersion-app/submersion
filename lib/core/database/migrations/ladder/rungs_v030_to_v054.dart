part of '../app_database_migrations.dart';

/// The rungs that take a database to schema versions 30 to 54.
extension RungsV30ToV54 on AppDatabase {
  Future<void> _rungsV30ToV54(
    Migrator m,
    int from,
    Future<void> Function() reportProgress,
  ) async {
    if (from < 30) {
      // Wearable integration (v2.0) - Apple Watch, Garmin, Suunto import
      // Add wearable source tracking to dives table
      await customStatement(
        'ALTER TABLE dives ADD COLUMN wearable_source TEXT',
      );
      await customStatement('ALTER TABLE dives ADD COLUMN wearable_id TEXT');
      // Add heart rate source tracking to dive_profiles table
      await customStatement(
        'ALTER TABLE dive_profiles ADD COLUMN heart_rate_source TEXT',
      );
    }
    if (from < 30) await reportProgress();
    if (from < 31) {
      // Performance indexes for 5000+ dives
      // Primary query: dives by diver, ordered by date
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_diver_datetime
            ON dives(diver_id, dive_date_time DESC)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_diver_entrytime
            ON dives(diver_id, entry_time DESC)
          ''');
      // FK lookups for batch loading in getAllDives()
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_site_id
            ON dives(site_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_trip_id
            ON dives(trip_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_dive_center_id
            ON dives(dive_center_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_course_id
            ON dives(course_id)
          ''');
      // Favorite filter
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dives_favorite
            ON dives(diver_id, is_favorite)
          ''');
      // Child table lookups for batch loading
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_tanks_dive_id
            ON dive_tanks(dive_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_equipment_dive_id
            ON dive_equipment(dive_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_weights_dive_id
            ON dive_weights(dive_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_tags_dive_id
            ON dive_tags(dive_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_tags_tag_id
            ON dive_tags(tag_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_buddies_dive_id
            ON dive_buddies(dive_id)
          ''');
    }
    if (from < 31) await reportProgress();
    if (from < 32) {
      // Add taxonomy class and built-in flag to species table
      await customStatement(
        'ALTER TABLE species ADD COLUMN taxonomy_class TEXT',
      );
      await customStatement(
        'ALTER TABLE species ADD COLUMN is_built_in INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (from < 32) await reportProgress();
    if (from < 33) {
      // Add locale column for i18n language preference
      final cols = await customSelect(
        'PRAGMA table_info(diver_settings)',
      ).get();
      final hasLocale = cols.any((row) => row.read<String>('name') == 'locale');
      if (!hasLocale) {
        await customStatement(
          "ALTER TABLE diver_settings ADD COLUMN locale TEXT NOT NULL DEFAULT 'system'",
        );
      }
    }
    if (from < 33) await reportProgress();
    if (from < 34) {
      // User-defined key:value custom fields per dive
      await customStatement('''
            CREATE TABLE IF NOT EXISTS dive_custom_fields (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              field_key TEXT NOT NULL,
              field_value TEXT NOT NULL DEFAULT '',
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_custom_fields_dive_id
            ON dive_custom_fields(dive_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_custom_fields_key
            ON dive_custom_fields(field_key)
          ''');
    }
    if (from < 34) await reportProgress();
    if (from < 35) {
      // Card coloring: attribute selector + gradient settings
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN card_color_attribute TEXT NOT NULL DEFAULT 'none'",
      );
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN card_color_gradient_preset TEXT NOT NULL DEFAULT 'ocean'",
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN card_color_gradient_start INTEGER',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN card_color_gradient_end INTEGER',
      );
      // Migrate existing depth coloring users
      await customStatement(
        "UPDATE diver_settings SET card_color_attribute = 'depth' WHERE show_depth_colored_dive_cards = 1",
      );
    }
    if (from < 35) await reportProgress();
    if (from < 36) {
      // Backfill water_temp from profile temperature data for dives
      // where water_temp is NULL but profile points have temperature.
      // Uses MIN(temperature) to match the import fallback logic.
      await customStatement('''
            UPDATE dives SET water_temp = (
              SELECT MIN(temperature) FROM dive_profiles
              WHERE dive_profiles.dive_id = dives.id
              AND dive_profiles.is_primary = 1
              AND dive_profiles.temperature IS NOT NULL
              AND dive_profiles.temperature >= -2
              AND dive_profiles.temperature <= 40
            ) WHERE water_temp IS NULL
          ''');
    }
    if (from < 36) await reportProgress();
    if (from < 37) {
      await customStatement(
        'ALTER TABLE dive_computers ADD COLUMN firmware_version TEXT',
      );
      await customStatement(
        'ALTER TABLE dives ADD COLUMN dive_computer_firmware TEXT',
      );
    }
    if (from < 37) await reportProgress();

    if (from < 38) {
      // Remove any existing duplicate media (same gallery photo linked
      // to same dive). Keep the oldest record (lowest created_at).
      await customStatement('''
            DELETE FROM media WHERE id IN (
              SELECT m.id FROM media m
              INNER JOIN (
                SELECT platform_asset_id, dive_id, MIN(created_at) as min_created
                FROM media
                WHERE platform_asset_id IS NOT NULL AND dive_id IS NOT NULL
                GROUP BY platform_asset_id, dive_id
                HAVING COUNT(*) > 1
              ) dupes ON m.platform_asset_id = dupes.platform_asset_id
                AND m.dive_id = dupes.dive_id
                AND m.created_at > dupes.min_created
            )
          ''');
      // Partial unique index: same gallery photo cannot be linked to
      // same dive twice. Only constrains rows where both columns are
      // non-null (signatures/orphans unaffected).
      await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_media_asset_dive_unique
            ON media(platform_asset_id, dive_id)
            WHERE platform_asset_id IS NOT NULL AND dive_id IS NOT NULL
          ''');
    }
    if (from < 38) await reportProgress();
    if (from < 39) {
      // Backfill avg_depth from profile data for dives that have
      // profile points but no avg_depth recorded.
      await customStatement('''
            UPDATE dives SET avg_depth = (
              SELECT AVG(depth) FROM dive_profiles
              WHERE dive_profiles.dive_id = dives.id
              AND dive_profiles.is_primary = 1
              AND dive_profiles.depth IS NOT NULL
            )
            WHERE avg_depth IS NULL
            AND EXISTS (
              SELECT 1 FROM dive_profiles
              WHERE dive_profiles.dive_id = dives.id
              AND dive_profiles.is_primary = 1
              AND dive_profiles.depth IS NOT NULL
            )
          ''');
      // Add CNS/OTU default visibility columns to settings
      final tableInfo = await customSelect(
        "PRAGMA table_info('diver_settings')",
      ).get();
      final existingColumns = tableInfo
          .map((row) => row.data['name'] as String)
          .toSet();
      if (!existingColumns.contains('default_show_cns')) {
        await customStatement(
          'ALTER TABLE diver_settings ADD COLUMN default_show_cns INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!existingColumns.contains('default_show_otu')) {
        await customStatement(
          'ALTER TABLE diver_settings ADD COLUMN default_show_otu INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (from < 39) await reportProgress();
    if (from < 40) {
      // Add per-sample decompression data columns to dive_profiles
      await customStatement('ALTER TABLE dive_profiles ADD COLUMN cns REAL');
      await customStatement('ALTER TABLE dive_profiles ADD COLUMN tts INTEGER');
      await customStatement('ALTER TABLE dive_profiles ADD COLUMN rbt INTEGER');
      await customStatement(
        'ALTER TABLE dive_profiles ADD COLUMN deco_type INTEGER',
      );
      // Add deco model fields to dives
      await customStatement('ALTER TABLE dives ADD COLUMN deco_algorithm TEXT');
      await customStatement(
        'ALTER TABLE dives ADD COLUMN deco_conservatism INTEGER',
      );
    }
    if (from < 40) await reportProgress();
    if (from < 41) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN use_dive_computer_cns_data INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (from < 41) await reportProgress();
    if (from < 42) {
      // Add per-metric data source columns
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_ndl_source INTEGER NOT NULL DEFAULT 1',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_ceiling_source INTEGER NOT NULL DEFAULT 1',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_tts_source INTEGER NOT NULL DEFAULT 1',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_cns_source INTEGER NOT NULL DEFAULT 1',
      );
      // Migrate existing CNS toggle: if user had it enabled, set CNS source to computer (0)
      await customStatement(
        'UPDATE diver_settings SET default_cns_source = 0 WHERE use_dive_computer_cns_data = 1',
      );
    }
    if (from < 42) await reportProgress();
    if (from < 43) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN theme_preset TEXT NOT NULL DEFAULT 'submersion'",
      );
    }
    if (from < 43) await reportProgress();
    if (from < 45) {
      // Migrations 44-45 add columns to diver_settings.
      // Guard with PRAGMA table_info to handle partial migrations
      // (ALTER TABLE ADD COLUMN cannot be rolled back in SQLite).
      final settingsInfo = await customSelect(
        'PRAGMA table_info(diver_settings)',
      ).get();
      final settingsCols = settingsInfo
          .map((r) => r.read<String>('name'))
          .toSet();
      if (!settingsCols.contains('o2_narcotic')) {
        await customStatement(
          'ALTER TABLE diver_settings ADD COLUMN o2_narcotic INTEGER NOT NULL DEFAULT 1',
        );
      }
      if (!settingsCols.contains('end_limit')) {
        await customStatement(
          'ALTER TABLE diver_settings ADD COLUMN end_limit REAL NOT NULL DEFAULT 30.0',
        );
      }
      if (!settingsCols.contains('tissue_color_scheme')) {
        await customStatement(
          "ALTER TABLE diver_settings ADD COLUMN tissue_color_scheme TEXT NOT NULL DEFAULT 'classic'",
        );
      }
      if (!settingsCols.contains('tissue_viz_mode')) {
        await customStatement(
          "ALTER TABLE diver_settings ADD COLUMN tissue_viz_mode TEXT NOT NULL DEFAULT 'heatMap'",
        );
      }
    }
    if (from < 45) await reportProgress();

    if (from < 46) {
      // Add trip type column to trips
      final tripsInfo = await customSelect('PRAGMA table_info(trips)').get();
      final tripsCols = tripsInfo.map((r) => r.read<String>('name')).toSet();
      if (!tripsCols.contains('trip_type')) {
        await customStatement(
          "ALTER TABLE trips ADD COLUMN trip_type TEXT NOT NULL DEFAULT 'shore'",
        );
      }

      // Create liveaboard_detail_records table
      await customStatement('''
            CREATE TABLE IF NOT EXISTS liveaboard_detail_records (
              id TEXT NOT NULL PRIMARY KEY,
              trip_id TEXT NOT NULL REFERENCES trips(id),
              vessel_name TEXT NOT NULL,
              operator_name TEXT,
              vessel_type TEXT,
              cabin_type TEXT,
              capacity INTEGER,
              embark_port TEXT,
              embark_latitude REAL,
              embark_longitude REAL,
              disembark_port TEXT,
              disembark_latitude REAL,
              disembark_longitude REAL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

      // Create trip_itinerary_days table
      await customStatement('''
            CREATE TABLE IF NOT EXISTS trip_itinerary_days (
              id TEXT NOT NULL PRIMARY KEY,
              trip_id TEXT NOT NULL REFERENCES trips(id),
              day_number INTEGER NOT NULL,
              date INTEGER NOT NULL,
              day_type TEXT NOT NULL DEFAULT 'diveDay',
              port_name TEXT,
              latitude REAL,
              longitude REAL,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

      // Migrate existing liveaboard trips
      await customStatement('''
            UPDATE trips SET trip_type = 'liveaboard'
            WHERE liveaboard_name IS NOT NULL AND liveaboard_name != ''
          ''');

      // Migrate existing resort trips (only non-liveaboard)
      await customStatement('''
            UPDATE trips SET trip_type = 'resort'
            WHERE resort_name IS NOT NULL AND resort_name != ''
              AND trip_type = 'shore'
          ''');

      // Create liveaboard_detail_records for existing liveaboard trips
      await customStatement('''
            INSERT INTO liveaboard_detail_records (
              id, trip_id, vessel_name, created_at, updated_at
            )
            SELECT
              lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
                substr(hex(randomblob(2)),2) || '-' ||
                substr('89ab', abs(random()) % 4 + 1, 1) ||
                substr(hex(randomblob(2)),2) || '-' || hex(randomblob(6))),
              id,
              COALESCE(liveaboard_name, 'Unknown Vessel'),
              created_at,
              updated_at
            FROM trips
            WHERE trip_type = 'liveaboard'
              AND id NOT IN (SELECT trip_id FROM liveaboard_detail_records)
          ''');
    }
    if (from < 46) await reportProgress();
    if (from < 47) {
      // Add lastDiveFingerprint column for incremental dive download
      final dcInfo = await customSelect(
        'PRAGMA table_info(dive_computers)',
      ).get();
      final dcCols = dcInfo.map((r) => r.read<String>('name')).toSet();
      if (!dcCols.contains('last_dive_fingerprint')) {
        await customStatement(
          'ALTER TABLE dive_computers ADD COLUMN last_dive_fingerprint TEXT',
        );
      }
    }
    if (from < 47) await reportProgress();
    if (from < 48) {
      // Add weather columns to dives table.
      // Guard with PRAGMA table_info to handle partial migrations
      // (ALTER TABLE ADD COLUMN cannot be rolled back in SQLite).
      final divesInfo = await customSelect('PRAGMA table_info(dives)').get();
      final divesCols = divesInfo.map((r) => r.read<String>('name')).toSet();
      if (!divesCols.contains('wind_speed')) {
        await customStatement('ALTER TABLE dives ADD COLUMN wind_speed REAL');
      }
      if (!divesCols.contains('wind_direction')) {
        await customStatement(
          'ALTER TABLE dives ADD COLUMN wind_direction TEXT',
        );
      }
      if (!divesCols.contains('cloud_cover')) {
        await customStatement('ALTER TABLE dives ADD COLUMN cloud_cover TEXT');
      }
      if (!divesCols.contains('precipitation')) {
        await customStatement(
          'ALTER TABLE dives ADD COLUMN precipitation TEXT',
        );
      }
      if (!divesCols.contains('humidity')) {
        await customStatement('ALTER TABLE dives ADD COLUMN humidity REAL');
      }
      if (!divesCols.contains('weather_description')) {
        await customStatement(
          'ALTER TABLE dives ADD COLUMN weather_description TEXT',
        );
      }
      if (!divesCols.contains('weather_source')) {
        await customStatement(
          'ALTER TABLE dives ADD COLUMN weather_source TEXT',
        );
      }
      if (!divesCols.contains('weather_fetched_at')) {
        await customStatement(
          'ALTER TABLE dives ADD COLUMN weather_fetched_at INTEGER',
        );
      }
    }
    if (from < 48) await reportProgress();
    if (from < 49) {
      // Add importVersion column.
      final divesInfo = await customSelect('PRAGMA table_info(dives)').get();
      final divesCols = divesInfo.map((r) => r.read<String>('name')).toSet();

      if (!divesCols.contains('import_version')) {
        await customStatement(
          'ALTER TABLE dives ADD COLUMN import_version INTEGER',
        );
      }

      // Migrate dive timestamps to wall-clock-as-UTC convention.
      // Computer-imported dives: already in correct format (the original
      // bug stored local wall-clock components as UTC, which matches the
      // target convention). Only mark them with importVersion = 1.
      await customStatement('''
            UPDATE dives SET import_version = 1
            WHERE dive_computer_model IS NOT NULL
               OR computer_id IS NOT NULL
          ''');

      // Wearable and manual dives: stored as true local epoch.
      // Both categories get the same shift so they are collapsed into one
      // UPDATE using `import_version IS NULL` (computer dives are already
      // set to 1 above).
      //
      // Convert local epoch to wall-clock-as-UTC:
      //   newEpoch = localEpoch + timeZoneOffsetMs
      //
      // UTC+8 example: local 8:42 = 0:42 UTC epoch.  +8 h = 8:42 UTC.
      // UTC-4 example: local 8:42 = 12:42 UTC epoch. -4 h = 8:42 UTC.
      final now = DateTime.now();
      final offsetMs = now.timeZoneOffset.inMilliseconds;

      await customStatement('''
            UPDATE dives
            SET dive_date_time = dive_date_time + $offsetMs,
                entry_time = CASE WHEN entry_time IS NOT NULL
                             THEN entry_time + $offsetMs ELSE NULL END,
                exit_time = CASE WHEN exit_time IS NOT NULL
                            THEN exit_time + $offsetMs ELSE NULL END,
                import_version = 1
            WHERE import_version IS NULL
          ''');
    }
    if (from < 49) await reportProgress();
    if (from < 50) {
      final settingsInfo = await customSelect(
        'PRAGMA table_info(diver_settings)',
      ).get();
      final settingsCols = settingsInfo
          .map((r) => r.read<String>('name'))
          .toSet();
      if (!settingsCols.contains('default_tank_preset')) {
        await customStatement(
          "ALTER TABLE diver_settings ADD COLUMN default_tank_preset TEXT DEFAULT 'al80'",
        );
      }
      if (!settingsCols.contains('apply_default_tank_to_imports')) {
        await customStatement(
          'ALTER TABLE diver_settings ADD COLUMN apply_default_tank_to_imports INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (from < 50) await reportProgress();
    if (from < 51) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN dive_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
      );
    }
    if (from < 51) await reportProgress();
    if (from < 52) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN site_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
      );
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN trip_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
      );
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN equipment_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
      );
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN buddy_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
      );
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN dive_center_list_view_mode TEXT NOT NULL DEFAULT 'detailed'",
      );
    }
    if (from < 52) await reportProgress();
    if (from < 53) {
      await customStatement('''
            CREATE TABLE IF NOT EXISTS dive_computer_data (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              computer_id TEXT REFERENCES dive_computers(id),
              is_primary INTEGER NOT NULL DEFAULT 0,
              computer_model TEXT,
              computer_serial TEXT,
              source_format TEXT,
              max_depth REAL,
              avg_depth REAL,
              duration INTEGER,
              water_temp REAL,
              entry_time INTEGER,
              exit_time INTEGER,
              max_ascent_rate REAL,
              max_descent_rate REAL,
              surface_interval INTEGER,
              cns REAL,
              otu REAL,
              deco_algorithm TEXT,
              gradient_factor_low INTEGER,
              gradient_factor_high INTEGER,
              imported_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_computer_data_dive_id
            ON dive_computer_data(dive_id)
          ''');
    }
    if (from < 53) await reportProgress();
    if (from < 54) {
      await customStatement(
        'ALTER TABLE dive_computer_data RENAME TO dive_data_sources',
      );
      await customStatement(
        'ALTER TABLE dive_data_sources ADD COLUMN source_file_name TEXT',
      );
      await customStatement(
        'ALTER TABLE dive_data_sources ADD COLUMN source_file_format TEXT',
      );
      await customStatement(
        'ALTER TABLE dives RENAME COLUMN wearable_source TO import_source',
      );
      await customStatement(
        'ALTER TABLE dives RENAME COLUMN wearable_id TO import_id',
      );
      await customStatement(
        'DROP INDEX IF EXISTS idx_dive_computer_data_dive_id',
      );
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_data_sources_dive_id
            ON dive_data_sources(dive_id)
          ''');
    }
    if (from < 54) await reportProgress();
  }
}
