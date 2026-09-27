part of '../app_database_migrations.dart';

/// The rungs that take a database to schema versions 55 to 71.
extension RungsV55ToV71 on AppDatabase {
  Future<void> _rungsV55ToV71(
    Migrator m,
    int from,
    Future<void> Function() reportProgress,
  ) async {
    if (from < 55) {
      // Add data source badge visibility setting to diver_settings
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN show_data_source_badges INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (from < 55) await reportProgress();
    if (from < 56) {
      await m.database.customStatement(
        'ALTER TABLE dives RENAME COLUMN duration TO bottom_time',
      );
    }
    if (from < 56) await reportProgress();
    if (from < 57) {
      // Add dive detail section configuration column to diver_settings
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN dive_detail_sections TEXT',
      );
    }
    if (from < 57) await reportProgress();
    if (from < 58) {
      // Add csv_presets table for user-saved CSV import presets
      await customStatement('''
            CREATE TABLE IF NOT EXISTS csv_presets (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              preset_json TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
      // Convert pressure columns from INTEGER to REAL in dive_tanks
      // to avoid rounding errors in PSI/bar conversions.
      // SQLite doesn't support ALTER COLUMN, so recreate the table.
      await customStatement('''
            CREATE TABLE dive_tanks_new (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              equipment_id TEXT REFERENCES equipment(id),
              volume REAL,
              working_pressure REAL,
              start_pressure REAL,
              end_pressure REAL,
              o2_percent REAL NOT NULL DEFAULT 21.0,
              he_percent REAL NOT NULL DEFAULT 0.0,
              tank_order INTEGER NOT NULL DEFAULT 0,
              tank_role TEXT NOT NULL DEFAULT 'backGas',
              tank_material TEXT,
              tank_name TEXT,
              preset_name TEXT
            )
          ''');
      await customStatement('''
            INSERT INTO dive_tanks_new
              (id, dive_id, equipment_id, volume,
               working_pressure, start_pressure, end_pressure,
               o2_percent, he_percent, tank_order, tank_role,
               tank_material, tank_name, preset_name)
            SELECT id, dive_id, equipment_id, volume,
                   CAST(working_pressure AS REAL),
                   CAST(start_pressure AS REAL),
                   CAST(end_pressure AS REAL),
                   o2_percent, he_percent, tank_order, tank_role,
                   tank_material, tank_name, preset_name
            FROM dive_tanks
          ''');
      await customStatement('DROP TABLE dive_tanks');
      await customStatement('ALTER TABLE dive_tanks_new RENAME TO dive_tanks');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_dive_tanks_dive_id ON dive_tanks(dive_id)',
      );
      // Convert workingPressureBar from INTEGER to REAL in tank_presets
      await customStatement('''
            CREATE TABLE tank_presets_new (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              name TEXT NOT NULL,
              display_name TEXT NOT NULL,
              volume_liters REAL NOT NULL,
              working_pressure_bar REAL NOT NULL,
              material TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
      await customStatement('''
            INSERT INTO tank_presets_new
              (id, diver_id, name, display_name, volume_liters,
               working_pressure_bar, material, description,
               sort_order, created_at, updated_at)
            SELECT id, diver_id, name, display_name, volume_liters,
                   CAST(working_pressure_bar AS REAL),
                   material, description, sort_order, created_at, updated_at
            FROM tank_presets
          ''');
      await customStatement('DROP TABLE tank_presets');
      await customStatement(
        'ALTER TABLE tank_presets_new RENAME TO tank_presets',
      );
    }
    if (from < 58) await reportProgress();
    if (from < 59) {
      // Migrate legacy dive_profiles.pressure data into
      // tank_pressure_profiles in a single bulk INSERT.
      // For each dive that has pressure data in dive_profiles but NO
      // existing rows in tank_pressure_profiles, copy the pressure
      // points associated with the dive's first tank (by rowid).
      //
      // Performance: use EXCEPT on small dive_id sets instead of
      // per-row NOT EXISTS (which triggers full table scans on
      // large tables). Reuse dp.id instead of generating UUIDs.
      // Temp tables with PKs give SQLite indexed join paths.

      // Build an indexed lookup of first tank per dive (~500 rows).
      await customStatement('''
            CREATE TEMP TABLE _migration_first_tanks (
              dive_id TEXT PRIMARY KEY,
              tank_id TEXT NOT NULL
            )
          ''');
      await customStatement('''
            INSERT INTO _migration_first_tanks (dive_id, tank_id)
            SELECT dive_id, id
            FROM (
              SELECT dive_id, id,
                     ROW_NUMBER() OVER (PARTITION BY dive_id ORDER BY rowid) AS rn
              FROM dive_tanks
            )
            WHERE rn = 1
          ''');

      // Ensure index exists so NOT EXISTS can use it
      // (may be missing depending on migration history).
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_tank_pressure_dive_tank
            ON tank_pressure_profiles(dive_id, tank_id, timestamp)
          ''');

      // Find dive_ids needing migration: have legacy pressure data
      // but no rows in tank_pressure_profiles yet. Uses set
      // difference on small distinct-dive_id sets (~hundreds) rather
      // than per-row NOT EXISTS on ~100k profile rows.
      final divesToMigrate = await customSelect('''
            SELECT DISTINCT dp.dive_id
            FROM dive_profiles dp
            WHERE dp.pressure IS NOT NULL AND dp.is_primary = 1
            EXCEPT
            SELECT DISTINCT dive_id FROM tank_pressure_profiles
          ''').get();

      if (divesToMigrate.isNotEmpty) {
        // Stash the dive_ids that need migration.
        await customStatement('''
              CREATE TEMP TABLE _migration_dive_ids (
                dive_id TEXT PRIMARY KEY
              )
            ''');
        for (final row in divesToMigrate) {
          await customStatement("INSERT INTO _migration_dive_ids VALUES (?)", [
            row.read<String>('dive_id'),
          ]);
        }

        // Drop secondary index for faster bulk insert.
        await customStatement(
          'DROP INDEX IF EXISTS idx_tank_pressure_dive_tank',
        );
        final cacheResult = await customSelect('PRAGMA cache_size').get();
        final previousCacheSize = cacheResult.first.read<int>('cache_size');
        await customStatement('PRAGMA cache_size = -65536');
        await customStatement('''
              INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, pressure)
              SELECT
                dp.id,
                dp.dive_id,
                ft.tank_id,
                dp.timestamp,
                dp.pressure
              FROM dive_profiles dp
              JOIN _migration_first_tanks ft ON ft.dive_id = dp.dive_id
              JOIN _migration_dive_ids md ON md.dive_id = dp.dive_id
              WHERE dp.pressure IS NOT NULL
                AND dp.is_primary = 1
            ''');
        await customStatement('PRAGMA cache_size = $previousCacheSize');
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_tank_pressure_dive_tank
              ON tank_pressure_profiles(dive_id, tank_id, timestamp)
            ''');
        await customStatement('DROP TABLE IF EXISTS _migration_dive_ids');
      }

      await customStatement('DROP TABLE IF EXISTS _migration_first_tanks');
    }
    if (from < 59) await reportProgress();

    if (from < 60) {
      await customStatement('''
            CREATE TABLE IF NOT EXISTS view_configs (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
              view_mode TEXT NOT NULL,
              config_json TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
      await customStatement('''
            CREATE TABLE IF NOT EXISTS field_presets (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
              view_mode TEXT NOT NULL,
              name TEXT NOT NULL,
              config_json TEXT NOT NULL,
              is_built_in INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_view_configs_diver ON view_configs(diver_id, view_mode)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_field_presets_diver ON field_presets(diver_id, view_mode)',
      );
    }
    if (from < 60) await reportProgress();

    if (from < 61) {
      // Add showProfilePanelInTableView column to diver_settings.
      // Guard against table not existing in older migration test contexts.
      final columns = await customSelect(
        "PRAGMA table_info('diver_settings')",
      ).get();
      if (columns.isNotEmpty &&
          !columns.any(
            (c) => c.read<String>('name') == 'show_profile_panel_in_table_view',
          )) {
        await customStatement('''
              ALTER TABLE diver_settings
              ADD COLUMN show_profile_panel_in_table_view INTEGER NOT NULL DEFAULT 1
            ''');
      }
    }
    if (from < 61) await reportProgress();

    if (from < 62) {
      await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_view_configs_unique
            ON view_configs(diver_id, view_mode)
          ''');
    }
    if (from < 62) await reportProgress();

    if (from < 63) {
      // Add per-section details pane toggle columns to diver_settings.
      final columns = await customSelect(
        "PRAGMA table_info('diver_settings')",
      ).get();
      if (columns.isNotEmpty) {
        final existing = columns.map((c) => c.read<String>('name')).toSet();
        const newColumns = {
          'show_details_pane_dives': 0,
          'show_details_pane_sites': 0,
          'show_details_pane_buddies': 0,
          'show_details_pane_trips': 0,
          'show_details_pane_equipment': 0,
          'show_details_pane_dive_centers': 0,
          'show_details_pane_certifications': 0,
          'show_details_pane_courses': 0,
        };
        for (final entry in newColumns.entries) {
          if (!existing.contains(entry.key)) {
            await customStatement('''
                  ALTER TABLE diver_settings
                  ADD COLUMN ${entry.key} INTEGER NOT NULL DEFAULT ${entry.value}
                ''');
          }
        }
      }
    }
    if (from < 63) await reportProgress();

    if (from < 64) {
      // Delete orphaned records (diver_id = NULL) left by prior diver
      // deletions that nullified instead of cascade-deleting.
      // Delete dives first so child tables CASCADE automatically.
      // Guard: only run on tables that have a diver_id column (older
      // migration-test databases may not have it).
      for (final table in [
        'dives',
        'trips',
        'dive_sites',
        'equipment',
        'equipment_sets',
        'buddies',
        'certifications',
        'dive_centers',
        'tags',
        'dive_computers',
        'tank_presets',
      ]) {
        final cols = await customSelect("PRAGMA table_info('$table')").get();
        if (cols.any((c) => c.read<String>('name') == 'diver_id')) {
          await customStatement('DELETE FROM $table WHERE diver_id IS NULL');
        }
      }

      // Custom dive types may be orphaned too, but built-in types
      // (is_built_in = 1) intentionally have null diver_id. Only
      // delete orphaned custom types.
      final diveTypeCols = await customSelect(
        "PRAGMA table_info('dive_types')",
      ).get();
      final hasDiverId = diveTypeCols.any(
        (c) => c.read<String>('name') == 'diver_id',
      );
      final hasBuiltIn = diveTypeCols.any(
        (c) => c.read<String>('name') == 'is_built_in',
      );
      if (hasDiverId && hasBuiltIn) {
        await customStatement(
          'DELETE FROM dive_types WHERE diver_id IS NULL AND is_built_in = 0',
        );
      }
    }
    if (from < 64) await reportProgress();

    if (from < 65) {
      // Flip legacy detailed-card stat2 default from bottomTime to runtime.
      // Preserves deliberate customizations (e.g. waterTemp) by only
      // rewriting rows that still carry the old default.
      final rows = await customSelect(
        "SELECT id, config_json FROM view_configs WHERE view_mode = 'detailed'",
      ).get();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final row in rows) {
        final configJson = row.read<String>('config_json');
        Map<String, dynamic> parsed;
        try {
          parsed = jsonDecode(configJson) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final slots = parsed['slots'];
        if (slots is! List) continue;
        var modified = false;
        for (final slot in slots) {
          if (slot is Map<String, dynamic> &&
              slot['slotId'] == 'stat2' &&
              slot['field'] == 'bottomTime') {
            slot['field'] = 'runtime';
            modified = true;
          }
        }
        if (!modified) continue;
        await customStatement(
          'UPDATE view_configs SET config_json = ?, updated_at = ? WHERE id = ?',
          [jsonEncode(parsed), now, row.read<String>('id')],
        );
      }
    }
    if (from < 65) await reportProgress();
    if (from < 66) {
      // Guard: dive_data_sources may not exist in older migration tests.
      final ddsColumns = await customSelect(
        "PRAGMA table_info('dive_data_sources')",
      ).get();
      if (ddsColumns.isNotEmpty) {
        final existing = ddsColumns.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('raw_data')) {
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN raw_data BLOB',
          );
        }
        if (!existing.contains('raw_fingerprint')) {
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN raw_fingerprint BLOB',
          );
        }
        if (!existing.contains('descriptor_vendor')) {
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN descriptor_vendor TEXT',
          );
        }
        if (!existing.contains('descriptor_product')) {
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN descriptor_product TEXT',
          );
        }
        if (!existing.contains('descriptor_model')) {
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN descriptor_model INTEGER',
          );
        }
        if (!existing.contains('libdivecomputer_version')) {
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN libdivecomputer_version TEXT',
          );
        }
        if (!existing.contains('last_parsed_at')) {
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN last_parsed_at INTEGER',
          );
        }

        // Rebuild the table to update the computer_id FK from the
        // original NO ACTION to ON DELETE SET NULL. SQLite cannot
        // alter constraints in place, so we create → copy → swap.
        await customStatement('PRAGMA foreign_keys = OFF');
        await customStatement('''
              CREATE TABLE dive_data_sources_new (
                id TEXT NOT NULL PRIMARY KEY,
                dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
                computer_id TEXT REFERENCES dive_computers(id) ON DELETE SET NULL,
                is_primary INTEGER NOT NULL DEFAULT 0,
                computer_model TEXT,
                computer_serial TEXT,
                source_format TEXT,
                source_file_name TEXT,
                source_file_format TEXT,
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
                created_at INTEGER NOT NULL,
                raw_data BLOB,
                raw_fingerprint BLOB,
                descriptor_vendor TEXT,
                descriptor_product TEXT,
                descriptor_model INTEGER,
                libdivecomputer_version TEXT,
                last_parsed_at INTEGER
              )
            ''');
        await customStatement('''
              INSERT INTO dive_data_sources_new
              SELECT id, dive_id, computer_id, is_primary,
                     computer_model, computer_serial, source_format,
                     source_file_name, source_file_format,
                     max_depth, avg_depth, duration, water_temp,
                     entry_time, exit_time, max_ascent_rate, max_descent_rate,
                     surface_interval, cns, otu, deco_algorithm,
                     gradient_factor_low, gradient_factor_high,
                     imported_at, created_at,
                     raw_data, raw_fingerprint,
                     descriptor_vendor, descriptor_product, descriptor_model,
                     libdivecomputer_version, last_parsed_at
              FROM dive_data_sources
            ''');
        await customStatement('DROP TABLE dive_data_sources');
        await customStatement(
          'ALTER TABLE dive_data_sources_new RENAME TO dive_data_sources',
        );
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_dive_data_sources_dive_id
              ON dive_data_sources(dive_id)
            ''');
        await customStatement('PRAGMA foreign_keys = ON');
      }
    }
    if (from < 66) await reportProgress();

    if (from < 67) {
      final cols = await customSelect(
        "PRAGMA table_info('diver_settings')",
      ).get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('map_style')) {
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN map_style TEXT NOT NULL DEFAULT 'openStreetMap'",
          );
        }
      }
    }
    if (from < 67) await reportProgress();

    if (from < 68) {
      // Guard: dive_profile_events may not exist in older migration tests.
      final dpeColumns = await customSelect(
        "PRAGMA table_info('dive_profile_events')",
      ).get();
      if (dpeColumns.isNotEmpty) {
        final existing = dpeColumns.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('source')) {
          await customStatement(
            "ALTER TABLE dive_profile_events ADD COLUMN source TEXT NOT NULL DEFAULT 'imported'",
          );
        }
      }
    }
    if (from < 68) await reportProgress();
    if (from < 69) {
      // Guard: trips may not exist in older migration test schemas.
      final tripColumns = await customSelect(
        "PRAGMA table_info('trips')",
      ).get();
      if (tripColumns.isNotEmpty) {
        final existing = tripColumns.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('is_shared')) {
          await customStatement(
            'ALTER TABLE trips ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0',
          );
        }
      }
      // Guard: dive_sites may not exist in older migration test schemas.
      final siteColumns = await customSelect(
        "PRAGMA table_info('dive_sites')",
      ).get();
      if (siteColumns.isNotEmpty) {
        final existing = siteColumns.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('is_shared')) {
          await customStatement(
            'ALTER TABLE dive_sites ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0',
          );
        }
      }
    }
    if (from < 69) await reportProgress();
    if (from < 70) {
      // Migration 70: add source_uuid to dive_data_sources for
      // cross-format import deduplication (MacDive UUID, Shearwater
      // DiveId, Subsurface SSRF id, generic UDDF dive id).
      // libdivecomputer continues to use raw_fingerprint.
      // Guard: dive_data_sources may not exist in older migration tests.
      final cols = await customSelect(
        "PRAGMA table_info('dive_data_sources')",
      ).get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('source_uuid')) {
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN source_uuid TEXT',
          );
        }
      }
    }
    if (from < 70) await reportProgress();
    if (from < 71) {
      // Migration 71: add MacDive dive + site metadata fields.
      final divesCols = await customSelect("PRAGMA table_info('dives')").get();
      final divesExisting = divesCols
          .map((r) => r.data['name'] as String)
          .toSet();
      if (divesCols.isNotEmpty) {
        if (!divesExisting.contains('boat_name')) {
          await customStatement('ALTER TABLE dives ADD COLUMN boat_name TEXT');
        }
        if (!divesExisting.contains('boat_captain')) {
          await customStatement(
            'ALTER TABLE dives ADD COLUMN boat_captain TEXT',
          );
        }
        if (!divesExisting.contains('dive_operator')) {
          await customStatement(
            'ALTER TABLE dives ADD COLUMN dive_operator TEXT',
          );
        }
        if (!divesExisting.contains('surface_conditions')) {
          await customStatement(
            'ALTER TABLE dives ADD COLUMN surface_conditions TEXT',
          );
        }
      }
      final sitesCols = await customSelect(
        "PRAGMA table_info('dive_sites')",
      ).get();
      final sitesExisting = sitesCols
          .map((r) => r.data['name'] as String)
          .toSet();
      if (sitesCols.isNotEmpty) {
        if (!sitesExisting.contains('water_type')) {
          await customStatement(
            'ALTER TABLE dive_sites ADD COLUMN water_type TEXT',
          );
        }
        if (!sitesExisting.contains('body_of_water')) {
          await customStatement(
            'ALTER TABLE dive_sites ADD COLUMN body_of_water TEXT',
          );
        }
      }
    }
    if (from < 71) await reportProgress();
  }
}
