part of '../app_database_migrations.dart';

/// The rungs that take a database to schema versions 2 to 29.
extension RungsV2ToV29 on AppDatabase {
  Future<void> _rungsV2ToV29(
    Migrator m,
    int from,
    Future<void> Function() reportProgress,
  ) async {
    if (from < 2) {
      // Add sacUnit column to diver_settings
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN sac_unit TEXT NOT NULL DEFAULT 'litersPerMin'",
      );
    }
    if (from < 2) await reportProgress();
    if (from < 3) {
      // Add presetName column to dive_tanks
      await customStatement(
        'ALTER TABLE dive_tanks ADD COLUMN preset_name TEXT',
      );
    }
    if (from < 3) await reportProgress();
    if (from < 4) {
      // Add sync tables for cloud sync feature
      await customStatement('''
            CREATE TABLE IF NOT EXISTS sync_metadata (
              id TEXT NOT NULL PRIMARY KEY,
              last_sync_timestamp INTEGER,
              device_id TEXT NOT NULL,
              sync_provider TEXT,
              remote_file_id TEXT,
              sync_version INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
      await customStatement('''
            CREATE TABLE IF NOT EXISTS sync_records (
              id TEXT NOT NULL PRIMARY KEY,
              entity_type TEXT NOT NULL,
              record_id TEXT NOT NULL,
              local_updated_at INTEGER NOT NULL,
              synced_at INTEGER,
              sync_status TEXT NOT NULL DEFAULT 'synced',
              conflict_data TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
      await customStatement('''
            CREATE TABLE IF NOT EXISTS deletion_log (
              id TEXT NOT NULL PRIMARY KEY,
              entity_type TEXT NOT NULL,
              record_id TEXT NOT NULL,
              deleted_at INTEGER NOT NULL
            )
          ''');
    }
    if (from < 4) await reportProgress();
    if (from < 5) {
      // Add showMapBackgroundOnDiveCards column to diver_settings
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN show_map_background_on_dive_cards INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (from < 5) await reportProgress();
    if (from < 6) {
      // Add showMapBackgroundOnSiteCards column to diver_settings
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN show_map_background_on_site_cards INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (from < 6) await reportProgress();
    if (from < 7) {
      // Add showDepthColoredDiveCards column to diver_settings (was missing migration)
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN show_depth_colored_dive_cards INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (from < 7) await reportProgress();
    if (from < 8) {
      // Add dive profile marker settings
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN show_max_depth_marker INTEGER NOT NULL DEFAULT 1',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN show_pressure_threshold_markers INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (from < 8) await reportProgress();
    if (from < 9) {
      // Add per-tank pressure profiles for multi-tank visualization
      await customStatement('''
            CREATE TABLE IF NOT EXISTS tank_pressure_profiles (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              tank_id TEXT NOT NULL REFERENCES dive_tanks(id) ON DELETE CASCADE,
              timestamp INTEGER NOT NULL,
              pressure REAL NOT NULL
            )
          ''');
      // Index for efficient queries by dive and tank
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_tank_pressure_dive_tank
            ON tank_pressure_profiles(dive_id, tank_id, timestamp)
          ''');
    }
    if (from < 9) await reportProgress();
    if (from < 10) {
      // Add time/date format columns to diver_settings
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN time_format TEXT NOT NULL DEFAULT 'twelveHour'",
      );
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN date_format TEXT NOT NULL DEFAULT 'mmmDYYYY'",
      );
    }
    if (from < 10) await reportProgress();
    if (from < 11) {
      // CCR/SCR Rebreather Support (v1.5)

      // CCR Setpoints (bar)
      await customStatement('ALTER TABLE dives ADD COLUMN setpoint_low REAL');
      await customStatement('ALTER TABLE dives ADD COLUMN setpoint_high REAL');
      await customStatement('ALTER TABLE dives ADD COLUMN setpoint_deco REAL');

      // SCR Configuration
      await customStatement('ALTER TABLE dives ADD COLUMN scr_type TEXT');
      await customStatement(
        'ALTER TABLE dives ADD COLUMN scr_injection_rate REAL',
      );
      await customStatement(
        'ALTER TABLE dives ADD COLUMN scr_addition_ratio REAL',
      );
      await customStatement(
        'ALTER TABLE dives ADD COLUMN scr_orifice_size TEXT',
      );
      await customStatement('ALTER TABLE dives ADD COLUMN assumed_vo2 REAL');

      // Diluent/Supply Gas
      await customStatement('ALTER TABLE dives ADD COLUMN diluent_o2 REAL');
      await customStatement('ALTER TABLE dives ADD COLUMN diluent_he REAL');

      // Loop FO2 measurements (SCR)
      await customStatement('ALTER TABLE dives ADD COLUMN loop_o2_min REAL');
      await customStatement('ALTER TABLE dives ADD COLUMN loop_o2_max REAL');
      await customStatement('ALTER TABLE dives ADD COLUMN loop_o2_avg REAL');

      // Shared rebreather fields
      await customStatement('ALTER TABLE dives ADD COLUMN loop_volume REAL');
      await customStatement('ALTER TABLE dives ADD COLUMN scrubber_type TEXT');
      await customStatement(
        'ALTER TABLE dives ADD COLUMN scrubber_duration_minutes INTEGER',
      );
      await customStatement(
        'ALTER TABLE dives ADD COLUMN scrubber_remaining_minutes INTEGER',
      );

      // DiveProfiles CCR/SCR fields
      await customStatement(
        'ALTER TABLE dive_profiles ADD COLUMN setpoint REAL',
      );
      await customStatement('ALTER TABLE dive_profiles ADD COLUMN pp_o2 REAL');
    }
    if (from < 11) await reportProgress();
    if (from < 12) {
      // Add isPlanned column for dive planner feature
      await customStatement(
        'ALTER TABLE dives ADD COLUMN is_planned INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (from < 12) await reportProgress();
    if (from < 13) {
      // Add custom tank presets table
      await customStatement('''
            CREATE TABLE IF NOT EXISTS tank_presets (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              name TEXT NOT NULL,
              display_name TEXT NOT NULL,
              volume_liters REAL NOT NULL,
              working_pressure_bar INTEGER NOT NULL,
              material TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
    }
    if (from < 13) await reportProgress();
    if (from < 14) {
      // Add tide records table for storing tide data with dives
      await customStatement('''
            CREATE TABLE IF NOT EXISTS tide_records (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              height_meters REAL NOT NULL,
              tide_state TEXT NOT NULL,
              rate_of_change REAL,
              high_tide_height REAL,
              high_tide_time INTEGER,
              low_tide_height REAL,
              low_tide_time INTEGER,
              created_at INTEGER NOT NULL
            )
          ''');
      // Index for efficient lookup by dive
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_tide_records_dive
            ON tide_records(dive_id)
          ''');
    }
    if (from < 14) await reportProgress();
    if (from < 15) {
      // Add index on dive_profiles.dive_id for faster profile loading
      // This table has 160K+ rows and is queried frequently by dive_id
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_profiles_dive_id
            ON dive_profiles(dive_id)
          ''');
      // Add composite index on sync_records for efficient pending/conflict lookups
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_sync_records_entity_record
            ON sync_records(entity_type, record_id)
          ''');
    }
    if (from < 15) await reportProgress();
    if (from < 16) {
      // Add altitude column to dive_sites for altitude diving support
      await customStatement('ALTER TABLE dive_sites ADD COLUMN altitude REAL');
    }
    if (from < 16) await reportProgress();
    if (from < 17) {
      // Add personal & medical data fields to divers table
      await customStatement('ALTER TABLE divers ADD COLUMN medications TEXT');
      await customStatement(
        'ALTER TABLE divers ADD COLUMN medical_clearance_expiry_date INTEGER',
      );
      // Secondary emergency contact
      await customStatement(
        'ALTER TABLE divers ADD COLUMN emergency_contact2_name TEXT',
      );
      await customStatement(
        'ALTER TABLE divers ADD COLUMN emergency_contact2_phone TEXT',
      );
      await customStatement(
        'ALTER TABLE divers ADD COLUMN emergency_contact2_relation TEXT',
      );
    }
    if (from < 17) await reportProgress();
    if (from < 18) {
      // Add site_species junction table for expected marine life at sites
      await customStatement('''
            CREATE TABLE IF NOT EXISTS site_species (
              id TEXT NOT NULL PRIMARY KEY,
              site_id TEXT NOT NULL REFERENCES dive_sites(id) ON DELETE CASCADE,
              species_id TEXT NOT NULL REFERENCES species(id) ON DELETE CASCADE,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL
            )
          ''');
      // Index for efficient lookup by site
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_site_species_site
            ON site_species(site_id)
          ''');
    }
    if (from < 18) await reportProgress();
    if (from < 19) {
      // Training courses feature (v1.5)
      // Create courses table
      await customStatement('''
            CREATE TABLE IF NOT EXISTS courses (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
              name TEXT NOT NULL,
              agency TEXT NOT NULL,
              start_date INTEGER NOT NULL,
              completion_date INTEGER,
              instructor_id TEXT REFERENCES buddies(id) ON DELETE SET NULL,
              instructor_name TEXT,
              instructor_number TEXT,
              certification_id TEXT REFERENCES certifications(id) ON DELETE SET NULL,
              location TEXT,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
      // Index for efficient lookup by diver
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_courses_diver
            ON courses(diver_id)
          ''');

      // Add courseId FK to dives table
      await customStatement(
        'ALTER TABLE dives ADD COLUMN course_id TEXT REFERENCES courses(id) ON DELETE SET NULL',
      );

      // Add courseId FK to certifications table (bidirectional link)
      await customStatement(
        'ALTER TABLE certifications ADD COLUMN course_id TEXT REFERENCES courses(id) ON DELETE SET NULL',
      );

      // Add signature fields to media table
      await customStatement(
        'ALTER TABLE media ADD COLUMN signer_id TEXT REFERENCES buddies(id) ON DELETE SET NULL',
      );
      await customStatement('ALTER TABLE media ADD COLUMN signer_name TEXT');
    }
    if (from < 19) await reportProgress();
    if (from < 20) {
      // Underwater photography feature (v2.0)
      final now = DateTime.now().millisecondsSinceEpoch;

      // Add new columns to media table for gallery photos
      await customStatement(
        'ALTER TABLE media ADD COLUMN platform_asset_id TEXT',
      );
      await customStatement(
        'ALTER TABLE media ADD COLUMN original_filename TEXT',
      );
      await customStatement('ALTER TABLE media ADD COLUMN width INTEGER');
      await customStatement('ALTER TABLE media ADD COLUMN height INTEGER');
      await customStatement(
        'ALTER TABLE media ADD COLUMN duration_seconds INTEGER',
      );
      await customStatement(
        'ALTER TABLE media ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE media ADD COLUMN thumbnail_generated_at INTEGER',
      );
      await customStatement(
        'ALTER TABLE media ADD COLUMN last_verified_at INTEGER',
      );
      await customStatement(
        'ALTER TABLE media ADD COLUMN is_orphaned INTEGER NOT NULL DEFAULT 0',
      );
      // Add timestamps with default for existing rows
      await customStatement(
        'ALTER TABLE media ADD COLUMN created_at INTEGER NOT NULL DEFAULT $now',
      );
      await customStatement(
        'ALTER TABLE media ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $now',
      );

      // Index on platform_asset_id for gallery photo lookups
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_platform_asset_id
            ON media(platform_asset_id)
          ''');

      // Create media_enrichment table
      await customStatement('''
            CREATE TABLE IF NOT EXISTS media_enrichment (
              id TEXT NOT NULL PRIMARY KEY,
              media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              depth_meters REAL,
              temperature_celsius REAL,
              elapsed_seconds INTEGER,
              match_confidence TEXT NOT NULL DEFAULT 'exact',
              timestamp_offset_seconds INTEGER,
              created_at INTEGER NOT NULL
            )
          ''');
      // Indexes for media_enrichment
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_enrichment_media
            ON media_enrichment(media_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_enrichment_dive
            ON media_enrichment(dive_id)
          ''');

      // Create media_species table
      await customStatement('''
            CREATE TABLE IF NOT EXISTS media_species (
              id TEXT NOT NULL PRIMARY KEY,
              media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,
              species_id TEXT NOT NULL REFERENCES species(id) ON DELETE CASCADE,
              sighting_id TEXT REFERENCES sightings(id) ON DELETE SET NULL,
              bbox_x REAL,
              bbox_y REAL,
              bbox_width REAL,
              bbox_height REAL,
              notes TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
      // Indexes for media_species
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_species_media
            ON media_species(media_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_species_species
            ON media_species(species_id)
          ''');

      // Create pending_photo_suggestions table
      await customStatement('''
            CREATE TABLE IF NOT EXISTS pending_photo_suggestions (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              platform_asset_id TEXT NOT NULL,
              taken_at INTEGER NOT NULL,
              thumbnail_path TEXT,
              dismissed INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
      // Index for pending_photo_suggestions
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_pending_photo_suggestions_dive
            ON pending_photo_suggestions(dive_id)
          ''');
    }
    if (from < 20) await reportProgress();
    if (from < 21) {
      // Cached map regions for offline maps feature
      await customStatement('''
            CREATE TABLE IF NOT EXISTS cached_regions (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              min_lat REAL NOT NULL,
              max_lat REAL NOT NULL,
              min_lng REAL NOT NULL,
              max_lng REAL NOT NULL,
              min_zoom INTEGER NOT NULL,
              max_zoom INTEGER NOT NULL,
              tile_count INTEGER NOT NULL,
              size_bytes INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              last_accessed_at INTEGER NOT NULL
            )
          ''');
    }
    if (from < 21) await reportProgress();
    if (from < 22) {
      // Buddy signatures feature - add signature type column
      await customStatement('ALTER TABLE media ADD COLUMN signature_type TEXT');
    }
    if (from < 22) await reportProgress();
    if (from < 23) {
      // Store photos as BLOBs instead of file paths for backup/export
      // Add BLOB columns to certifications table
      await customStatement(
        'ALTER TABLE certifications ADD COLUMN photo_front BLOB',
      );
      await customStatement(
        'ALTER TABLE certifications ADD COLUMN photo_back BLOB',
      );
      // Add BLOB column to media table for signatures
      await customStatement('ALTER TABLE media ADD COLUMN image_data BLOB');
    }
    if (from < 23) await reportProgress();
    if (from < 24) {
      // Add structured address fields to dive_centers
      // The original table had 'location' but not 'city', so we add all new columns
      // Check which columns exist to handle partial migrations
      final tableInfo = await customSelect(
        "PRAGMA table_info('dive_centers')",
      ).get();
      final existingColumns = tableInfo
          .map((row) => row.data['name'] as String)
          .toSet();

      if (!existingColumns.contains('street')) {
        await customStatement(
          'ALTER TABLE dive_centers ADD COLUMN street TEXT',
        );
      }
      if (!existingColumns.contains('city')) {
        await customStatement('ALTER TABLE dive_centers ADD COLUMN city TEXT');
      }
      if (!existingColumns.contains('state_province')) {
        await customStatement(
          'ALTER TABLE dive_centers ADD COLUMN state_province TEXT',
        );
      }
      if (!existingColumns.contains('postal_code')) {
        await customStatement(
          'ALTER TABLE dive_centers ADD COLUMN postal_code TEXT',
        );
      }
      // Migrate existing location data to the new city column (if location exists)
      if (existingColumns.contains('location')) {
        await customStatement('''
              UPDATE dive_centers
              SET city = location
              WHERE location IS NOT NULL AND (city IS NULL OR city = '')
            ''');
      }
    }
    if (from < 24) await reportProgress();
    if (from < 25) {
      // Add altitudeUnit column to diver_settings
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN altitude_unit TEXT NOT NULL DEFAULT 'meters'",
      );
    }
    if (from < 25) await reportProgress();
    if (from < 26) {
      // Notification settings for service reminders
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN notifications_enabled INTEGER NOT NULL DEFAULT 1',
      );
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN service_reminder_days TEXT NOT NULL DEFAULT '[7, 14, 30]'",
      );
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN reminder_time TEXT NOT NULL DEFAULT '09:00'",
      );
    }
    if (from < 26) await reportProgress();
    if (from < 27) {
      // Per-equipment notification overrides
      await customStatement(
        'ALTER TABLE equipment ADD COLUMN custom_reminder_enabled INTEGER',
      );
      await customStatement(
        'ALTER TABLE equipment ADD COLUMN custom_reminder_days TEXT',
      );
    }
    if (from < 27) await reportProgress();
    if (from < 28) {
      // Scheduled notifications tracking table
      await customStatement('''
            CREATE TABLE IF NOT EXISTS scheduled_notifications (
              id TEXT NOT NULL PRIMARY KEY,
              equipment_id TEXT NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
              scheduled_date INTEGER NOT NULL,
              reminder_days_before INTEGER NOT NULL,
              notification_id INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
      // Index for efficient lookup by equipment
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_equipment
            ON scheduled_notifications(equipment_id)
          ''');
    }
    if (from < 28) await reportProgress();
    if (from < 29) {
      // Add dive profile chart default visibility settings to diver_settings
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN default_right_axis_metric TEXT NOT NULL DEFAULT 'temperature'",
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_temperature INTEGER NOT NULL DEFAULT 1',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_pressure INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_heart_rate INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_sac INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_events INTEGER NOT NULL DEFAULT 1',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_pp_o2 INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_pp_n2 INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_pp_he INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_gas_density INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_gf INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_surface_gf INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_mean_depth INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_tts INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_gas_switch_markers INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (from < 29) await reportProgress();
  }
}
