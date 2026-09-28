part of '../app_database_migrations.dart';

/// The rungs that take a database to schema versions 72 to 95.
extension RungsV72ToV95 on AppDatabase {
  Future<void> _rungsV72ToV95(
    Migrator m,
    int from,
    Future<void> Function() reportProgress,
  ) async {
    if (from < 72) {
      // Phase 1 of Media Source Extension.
      // Add discriminator and new pointer columns to media.
      await customStatement(
        "ALTER TABLE media ADD COLUMN source_type TEXT NOT NULL DEFAULT 'platformGallery'",
      );
      await customStatement('ALTER TABLE media ADD COLUMN local_path TEXT');
      await customStatement('ALTER TABLE media ADD COLUMN bookmark_ref TEXT');
      await customStatement('ALTER TABLE media ADD COLUMN url TEXT');
      await customStatement(
        'ALTER TABLE media ADD COLUMN subscription_id TEXT',
      );
      await customStatement('ALTER TABLE media ADD COLUMN entry_key TEXT');
      await customStatement(
        'ALTER TABLE media ADD COLUMN connector_account_id TEXT',
      );
      await customStatement(
        'ALTER TABLE media ADD COLUMN remote_asset_id TEXT',
      );
      await customStatement(
        'ALTER TABLE media ADD COLUMN origin_device_id TEXT',
      );

      // Subscription registry (synced across devices).
      await customStatement('''
            CREATE TABLE IF NOT EXISTS media_subscriptions (
              id TEXT NOT NULL PRIMARY KEY,
              manifest_url TEXT NOT NULL,
              format TEXT NOT NULL,
              display_name TEXT,
              poll_interval_seconds INTEGER NOT NULL DEFAULT 86400,
              is_active INTEGER NOT NULL DEFAULT 1,
              credentials_host_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

      // Per-device polling state (NOT synced).
      await customStatement('''
            CREATE TABLE IF NOT EXISTS media_subscription_state (
              subscription_id TEXT NOT NULL PRIMARY KEY
                REFERENCES media_subscriptions(id) ON DELETE CASCADE,
              last_polled_at INTEGER,
              next_poll_at INTEGER,
              last_etag TEXT,
              last_modified TEXT,
              last_error TEXT,
              last_error_at INTEGER
            )
          ''');

      // Service connector accounts (NOT synced).
      await customStatement('''
            CREATE TABLE IF NOT EXISTS connector_accounts (
              id TEXT NOT NULL PRIMARY KEY,
              connector_type TEXT NOT NULL,
              display_name TEXT NOT NULL,
              base_url TEXT,
              account_identifier TEXT,
              credentials_ref TEXT NOT NULL,
              added_at INTEGER NOT NULL,
              last_used_at INTEGER
            )
          ''');

      // Per-host credentials for ad-hoc network URLs (NOT synced).
      await customStatement('''
            CREATE TABLE IF NOT EXISTS network_credential_hosts (
              id TEXT NOT NULL PRIMARY KEY,
              hostname TEXT NOT NULL UNIQUE,
              auth_type TEXT NOT NULL,
              display_name TEXT,
              credentials_ref TEXT NOT NULL,
              added_at INTEGER NOT NULL,
              last_used_at INTEGER
            )
          ''');

      // Per-device fetch diagnostics (NOT synced).
      await customStatement('''
            CREATE TABLE IF NOT EXISTS media_fetch_diagnostics (
              media_item_id TEXT NOT NULL PRIMARY KEY
                REFERENCES media(id) ON DELETE CASCADE,
              last_error_at INTEGER,
              last_error_message TEXT,
              error_count INTEGER NOT NULL DEFAULT 0
            )
          ''');

      // Backfill source_type for existing rows.
      // Order matters: signature first (most specific), then platformGallery,
      // then localFile, with platformGallery as the safe default for the
      // unreachable "neither pointer set" case.
      await customStatement('''
            UPDATE media SET source_type = 'signature'
            WHERE file_type = 'instructor_signature'
          ''');
      await customStatement('''
            UPDATE media
            SET source_type = 'platformGallery'
            WHERE file_type != 'instructor_signature'
              AND platform_asset_id IS NOT NULL
          ''');
      await customStatement('''
            UPDATE media
            SET source_type = 'localFile',
                local_path = file_path
            WHERE file_type != 'instructor_signature'
              AND platform_asset_id IS NULL
              AND file_path IS NOT NULL
              AND file_path != ''
          ''');

      // Indexes.
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_source_type
            ON media(source_type)
          ''');
      await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_media_subscription_entry
            ON media(subscription_id, entry_key)
            WHERE subscription_id IS NOT NULL
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_connector_account
            ON media(connector_account_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_origin_device
            ON media(origin_device_id)
          ''');
    }
    if (from < 72) await reportProgress();
    if (from < 73) {
      // Guard: dives may not exist in older migration-test contexts.
      final divesCols = await customSelect("PRAGMA table_info('dives')").get();
      if (divesCols.isNotEmpty) {
        final divesExisting = divesCols
            .map((c) => c.read<String>('name'))
            .toSet();
        if (!divesExisting.contains('entry_latitude')) {
          await customStatement(
            'ALTER TABLE dives ADD COLUMN entry_latitude REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN entry_longitude REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN exit_latitude REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN exit_longitude REAL',
          );
        }
      }
    }
    if (from < 73) await reportProgress();
    if (from < 74) {
      final cols = await customSelect(
        "PRAGMA table_info('dive_data_sources')",
      ).get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('entry_latitude')) {
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN entry_latitude REAL',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN entry_longitude REAL',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN exit_latitude REAL',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN exit_longitude REAL',
          );
        }
      }
    }
    if (from < 74) await reportProgress();
    if (from < 75) {
      final cols = await customSelect(
        "PRAGMA table_info('diver_settings')",
      ).get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('default_show_gas_timeline')) {
          await customStatement(
            'ALTER TABLE diver_settings ADD COLUMN default_show_gas_timeline INTEGER NOT NULL DEFAULT 0',
          );
        }
      }
    }
    if (from < 75) await reportProgress();
    if (from < 76) {
      final cols = await customSelect(
        "PRAGMA table_info('diver_settings')",
      ).get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('site_match_sensitivity')) {
          await customStatement(
            "ALTER TABLE diver_settings ADD COLUMN site_match_sensitivity TEXT NOT NULL DEFAULT 'balanced'",
          );
        }
      }
    }
    if (from < 76) await reportProgress();
    if (from < 77) {
      // Add nullable Hybrid Logical Clock column to every conflict-capable
      // syncable table (and sync_metadata for the device clock). Nullable
      // so existing rows fall back to updatedAt ordering until rewritten.
      for (final table in _hlcTables) {
        final cols = await customSelect("PRAGMA table_info('$table')").get();
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (cols.isNotEmpty && !existing.contains('hlc')) {
          await customStatement('ALTER TABLE $table ADD COLUMN hlc TEXT');
        }
      }
    }
    if (from < 77) await reportProgress();
    if (from < 78) {
      // Add the nullable per-database instance token to sync_metadata. Used
      // to detect a database restore/overwrite that leaves the device id
      // unchanged (a same-device backup). Nullable so existing rows read as
      // "no token yet" and are treated like a first-run seed.
      final cols = await customSelect(
        "PRAGMA table_info('sync_metadata')",
      ).get();
      final existing = cols.map((c) => c.read<String>('name')).toSet();
      if (cols.isNotEmpty && !existing.contains('instance_token')) {
        await customStatement(
          'ALTER TABLE sync_metadata ADD COLUMN instance_token TEXT',
        );
      }
    }
    if (from < 78) await reportProgress();
    if (from < 79) {
      // Support surface-interval derivation from timestamps (issue #235):
      // the correlated subquery SELECT MAX(exit_time) WHERE diver_id AND
      // exit_time < entry_time needs this index to stay fast at scale.
      // Guard with PRAGMA in case partial-schema migration fixtures are
      // used in tests where dives may not yet have these columns.
      final divesCols = await customSelect("PRAGMA table_info('dives')").get();
      if (divesCols.isNotEmpty) {
        final colNames = divesCols.map((c) => c.read<String>('name')).toSet();
        if (colNames.contains('diver_id') && colNames.contains('exit_time')) {
          await customStatement('''
                CREATE INDEX IF NOT EXISTS idx_dives_diver_exittime
                ON dives(diver_id, exit_time DESC)
              ''');
        }
      }
    }
    if (from < 79) await reportProgress();
    if (from < 80) {
      // Library epoch anchor for restore Replace mode: the epoch this
      // device last accepted, dual-anchored with a SharedPreferences
      // mirror (see library_epoch_store.dart).
      final cols = await customSelect(
        "PRAGMA table_info('sync_metadata')",
      ).get();
      final existing = cols.map((c) => c.read<String>('name')).toSet();
      if (cols.isNotEmpty && !existing.contains('last_accepted_epoch_id')) {
        await customStatement(
          'ALTER TABLE sync_metadata ADD COLUMN last_accepted_epoch_id TEXT',
        );
      }
    }
    if (from < 80) await reportProgress();
    if (from < 81) {
      // Provider stamp for the sync cursor: lastSyncTimestamp minted
      // against one backend must read as absent for another, so first
      // contact with a switched backend stays detectable. Nullable so
      // existing cursors read as legacy (valid for any provider).
      final cols = await customSelect(
        "PRAGMA table_info('sync_metadata')",
      ).get();
      final existing = cols.map((c) => c.read<String>('name')).toSet();
      if (cols.isNotEmpty && !existing.contains('last_sync_provider')) {
        await customStatement(
          'ALTER TABLE sync_metadata ADD COLUMN last_sync_provider TEXT',
        );
      }
    }
    if (from < 81) await reportProgress();
    if (from < 82) {
      // Recover databases stranded by the v77 schema-version collision:
      // PR #302 (surface-interval index) shipped a v77 that only created
      // an index, while the HLC backfill also claimed v77. Any database
      // that upgraded under the index-only v77 sits at user_version >= 77
      // with no hlc columns, so the v77 guard above (from < 77) is false
      // and the backfill is skipped — leaving every sync UNION query
      // (e.g. SELECT MAX(hlc) FROM "equipment") failing at prepare time.
      //
      // Re-run the same PRAGMA-guarded ALTER: healthy databases that
      // already have hlc no-op on every table; affected databases get the
      // missing columns added and sync starts working again.
      for (final table in _hlcTables) {
        final cols = await customSelect("PRAGMA table_info('$table')").get();
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (cols.isNotEmpty && !existing.contains('hlc')) {
          await customStatement('ALTER TABLE $table ADD COLUMN hlc TEXT');
        }
      }
    }
    if (from < 82) await reportProgress();
    if (from < 83) {
      // Comprehensive recovery for databases stranded past v77 by the wider
      // set of sync-branch schema-version collisions. The v77 HLC / PR #302
      // index collision (healed by the v82 block above) was only the first:
      // the abandoned encrypted-sync and iCloud-diagnostic lineages also
      // reused v78-v81 for unrelated migrations. A database that reached
      // user_version >= 78 via one of those branches skipped the canonical
      // sync_metadata ALTERs — instance_token (v78), last_accepted_epoch_id
      // (v80), last_sync_provider (v81) — because their `from < N` guards
      // are false once `from` already passed N. The v82 block re-added only
      // hlc, so the three text columns stayed missing once the database sat
      // at the current version and stopped running onUpgrade. Every identity
      // write then failed at prepare time with "no such column:
      // instance_token" (launch-time reconcile and the twin-split
      // adopt-fresh-identity path), so sync could never start.
      //
      // Re-assert every post-v76 sync_metadata column with PRAGMA-guarded
      // ALTERs: healthy databases no-op, stranded databases are healed. The
      // columns are all nullable, so existing rows read as "not yet set"
      // exactly as they did on the original add.
      const syncMetadataColumns = <String, String>{
        'instance_token': 'TEXT',
        'last_accepted_epoch_id': 'TEXT',
        'last_sync_provider': 'TEXT',
      };
      final smCols = await customSelect(
        "PRAGMA table_info('sync_metadata')",
      ).get();
      if (smCols.isNotEmpty) {
        final existing = smCols.map((c) => c.read<String>('name')).toSet();
        for (final entry in syncMetadataColumns.entries) {
          if (!existing.contains(entry.key)) {
            await customStatement(
              'ALTER TABLE sync_metadata '
              'ADD COLUMN ${entry.key} ${entry.value}',
            );
          }
        }
      }
      // Re-run the hlc backfill as well, covering any database that reached
      // user_version 82 (so the v82 block no longer fires) while still
      // missing hlc on some table via a collision that also claimed v82.
      for (final table in _hlcTables) {
        final cols = await customSelect("PRAGMA table_info('$table')").get();
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (cols.isNotEmpty && !existing.contains('hlc')) {
          await customStatement('ALTER TABLE $table ADD COLUMN hlc TEXT');
        }
      }
    }
    if (from < 83) await reportProgress();
    if (from < 84) {
      // Incremental changeset-log sync: per-peer download cursors and this
      // device's own per-provider publish position.
      await customStatement('''
            CREATE TABLE IF NOT EXISTS sync_peer_cursors (
              peer_device_id TEXT NOT NULL,
              provider TEXT NOT NULL,
              base_seq_applied INTEGER,
              last_seq_applied INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY (peer_device_id, provider)
            )
          ''');
      await customStatement('''
            CREATE TABLE IF NOT EXISTS local_publish_states (
              provider TEXT NOT NULL PRIMARY KEY,
              base_seq INTEGER,
              base_part_count INTEGER,
              base_bytes INTEGER,
              head_seq INTEGER NOT NULL DEFAULT 0,
              published_hlc_high TEXT,
              changeset_bytes_since_base INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL
            )
          ''');
    }
    if (from < 84) await reportProgress();
    if (from < 85) {
      // media, species, field_presets become first-class HLC entities so
      // they delta by their own hlc instead of being exported in full.
      // Table/column identifiers cannot be SQL-parameterized; these names
      // are a fixed compile-time const list (no user input), so the string
      // interpolation below is injection-safe.
      for (final table in const ['media', 'species', 'field_presets']) {
        final cols = await customSelect("PRAGMA table_info('$table')").get();
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (cols.isNotEmpty && !existing.contains('hlc')) {
          await customStatement('ALTER TABLE $table ADD COLUMN hlc TEXT');
        }
      }
    }
    if (from < 85) await reportProgress();
    if (from < 86) {
      // Deletions become HLC-versioned like rows: logDeletion now stamps a
      // monotonic hlc so an incremental changeset can carry only NEW
      // tombstones instead of re-publishing the whole deletion log every
      // sync. Backfill pre-existing tombstones with a minimal sentinel so
      // they read as already-published (excluded from incrementals) while
      // still riding every full base -- no re-publish, no resurrection.
      final cols = await customSelect(
        "PRAGMA table_info('deletion_log')",
      ).get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('hlc')) {
          await customStatement('ALTER TABLE deletion_log ADD COLUMN hlc TEXT');
        }
        await customStatement(
          "UPDATE deletion_log SET hlc = '000000000000000:000000:legacy' "
          'WHERE hlc IS NULL',
        );
      }
    }
    if (from < 86) await reportProgress();
    if (from < 87) {
      // Prior dive experience (issue #331): three nullable columns on
      // `divers`. PRAGMA-guarded so a healthy database no-ops; existing
      // rows read as NULL = "no prior experience".
      final cols = await customSelect("PRAGMA table_info('divers')").get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('prior_dive_count')) {
          await customStatement(
            'ALTER TABLE divers ADD COLUMN prior_dive_count INTEGER',
          );
        }
        if (!existing.contains('prior_dive_time_seconds')) {
          await customStatement(
            'ALTER TABLE divers ADD COLUMN prior_dive_time_seconds INTEGER',
          );
        }
        if (!existing.contains('diving_since')) {
          await customStatement(
            'ALTER TABLE divers ADD COLUMN diving_since INTEGER',
          );
        }
      }
    }
    if (from < 87) await reportProgress();
    if (from < 88) {
      // Add 'Cavern' as a built-in dive type. Cavern diving (light-zone
      // only, cavern cert) is a distinct discipline from Cave (beyond
      // light zone, full cave cert). Guarded by a sqlite_master check so
      // minimal-schema test databases without dive_types are not affected;
      // INSERT OR IGNORE preserves any user-created 'cavern' row.
      //
      // Renumbered from v84 to v88 because upstream claimed v84-v87 for
      // sync-infrastructure migrations (see blocks above).
      final tables = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='dive_types'",
      ).get();
      if (tables.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await customStatement('''
              INSERT OR IGNORE INTO dive_types (id, name, is_built_in, sort_order, created_at, updated_at)
              VALUES ('cavern', 'Cavern', 1, 14, $now, $now)
            ''');
      }
    }
    if (from < 88) await reportProgress();
    if (from < 89) {
      // Individual CCR O2 cell readings (sensor1..sensor6 from Subsurface
      // CCR imports): six nullable columns on `dive_profiles`. PRAGMA-guarded
      // so a healthy database no-ops; existing rows read as NULL.
      //
      // Renumbered from v88 to v89 because upstream claimed v88 for the
      // Cavern dive-type migration (see block above).
      final cols = await customSelect(
        "PRAGMA table_info('dive_profiles')",
      ).get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        for (var n = 1; n <= 6; n++) {
          if (!existing.contains('o2_sensor$n')) {
            await customStatement(
              'ALTER TABLE dive_profiles ADD COLUMN o2_sensor$n REAL',
            );
          }
        }
      }
    }
    if (from < 89) await reportProgress();
    if (from < 90) {
      // City and Island localities for dive sites (issue #344). Lets
      // divers tell apart sites that share a country and region (e.g.
      // multiple islands off Cebu). PRAGMA-guarded so a healthy database
      // no-ops; existing rows read as NULL. body_of_water already exists.
      final cols = await customSelect("PRAGMA table_info('dive_sites')").get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('city')) {
          await customStatement('ALTER TABLE dive_sites ADD COLUMN city TEXT');
        }
        if (!existing.contains('island')) {
          await customStatement(
            'ALTER TABLE dive_sites ADD COLUMN island TEXT',
          );
        }
      }
    }
    if (from < 90) await reportProgress();
    if (from < 91) {
      // Persisted default for the "Ascent Rate Line" profile overlay
      // (issue: ascent-rate toggles default-off). Previously the line was a
      // session-only toggle with no setting; it now joins the Default
      // Visible Metrics list. PRAGMA-guarded so a healthy database no-ops
      // and an interrupted upgrade does not fail on a duplicate ALTER.
      final cols = await customSelect(
        "PRAGMA table_info('diver_settings')",
      ).get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('default_show_ascent_rate_line')) {
          await customStatement(
            'ALTER TABLE diver_settings '
            'ADD COLUMN default_show_ascent_rate_line '
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
      }
    }
    if (from < 91) await reportProgress();
    if (from < 92) {
      await m.createTable(diveDiveTypes);
      // Seed only when the dives table (with its dive_type column) is
      // present. Minimal-schema migration tests build a partial database
      // without it, and the seed must not fail there.
      final diveCols = await customSelect("PRAGMA table_info('dives')").get();
      final hasDiveType = diveCols.any(
        (c) => c.read<String>('name') == 'dive_type',
      );
      if (hasDiveType) {
        await customStatement(kSeedDiveDiveTypesSql);
      }
    }
    if (from < 92) await reportProgress();
    if (from < 93) {
      // Backfill built-in dive types. The full built-in set was only ever
      // seeded in onCreate, so every database that reached the app via
      // migration (rather than a fresh install) kept an EMPTY dive_types
      // table -- the multi-select dive-type picker (#414) then showed no
      // options. Guarded by a sqlite_master check so minimal-schema
      // migration tests without dive_types are unaffected; INSERT OR IGNORE
      // preserves rows already present (synced custom types, 'cavern' from
      // the v88 migration).
      final tables = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='dive_types'",
      ).get();
      if (tables.isNotEmpty) {
        await customStatement(kSeedBuiltInDiveTypesSql);
      }
    }
    if (from < 93) await reportProgress();
    if (from < 94) {
      // Guarded by sqlite_master so minimal-schema migration tests without
      // diver_settings are unaffected.
      final dsTable = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='diver_settings'",
      ).get();
      if (dsTable.isNotEmpty) {
        await m.addColumn(diverSettings, diverSettings.ascentGasSet);
      }
    }
    if (from < 94) await reportProgress();
    if (from < 95) {
      // Dive naming (#400): optional user-defined dive name. Guarded by a
      // PRAGMA check so an interrupted upgrade that already added the
      // column does not fail on a duplicate ALTER, and so minimal-schema
      // migration tests without a dives table are unaffected (empty
      // table_info means no dives table).
      final diveCols = await customSelect("PRAGMA table_info('dives')").get();
      final hasName = diveCols.any((c) => c.read<String>('name') == 'name');
      if (diveCols.isNotEmpty && !hasName) {
        await customStatement('ALTER TABLE dives ADD COLUMN name TEXT');
      }
    }
    if (from < 95) await reportProgress();
  }
}
