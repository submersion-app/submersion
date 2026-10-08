part of '../app_database_migrations.dart';

/// The rungs that take a database to schema versions 96 to 148.
extension RungsV96ToV148 on AppDatabase {
  Future<void> _rungsV96ToV148(
    Migrator m,
    int from,
    Future<void> Function() reportProgress,
  ) async {
    if (from < 96) {
      // Persisted default for the "Photo Markers" profile overlay
      // (issue #162). Guarded like v91: skip when diver_settings does
      // not exist (minimal-schema migration tests) or the column is
      // already present (interrupted upgrade).
      final cols = await customSelect(
        "PRAGMA table_info('diver_settings')",
      ).get();
      if (cols.isNotEmpty) {
        final existing = cols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('default_show_photo_markers')) {
          await customStatement(
            'ALTER TABLE diver_settings '
            'ADD COLUMN default_show_photo_markers '
            'INTEGER NOT NULL DEFAULT 1',
          );
        }
      }
    }
    if (from < 96) await reportProgress();
    if (from < 97) {
      // Multi-computer consolidation: per-source attribution for tanks,
      // pressure curves, and events. Guarded per table so minimal-schema
      // migration tests without these tables are unaffected; existing
      // rows keep NULL (= primary source / manual entry). (Authored as
      // v94 on the feature branch; renumbered on merge as later
      // migrations landed on main: ascent_gas_set v94, dive naming v95,
      // photo markers v96.)
      for (final table in [
        'dive_tanks',
        'tank_pressure_profiles',
        'dive_profile_events',
      ]) {
        final cols = await customSelect("PRAGMA table_info('$table')").get();
        if (cols.isEmpty) continue;
        final names = cols.map((c) => c.read<String>('name')).toSet();
        if (!names.contains('computer_id')) {
          await customStatement(
            'ALTER TABLE $table ADD COLUMN computer_id TEXT '
            'REFERENCES dive_computers (id) ON DELETE SET NULL',
          );
        }
      }
    }
    if (from < 97) await reportProgress();
    if (from < 98) {
      // Checklist tables for trip planning (issue #164). Raw idempotent
      // DDL (matches the v84 idiom) so interrupted migrations are safe.
      // Renumbered v95 -> v96 -> v97 -> v98 as parallel branches each
      // consumed a version before this merged (dive naming v95, photo
      // markers v96, multi-computer consolidation v97), stranding some
      // live databases at those versions without the checklist tables.
      // Re-running the idempotent CREATE TABLE/INDEX IF NOT EXISTS
      // statements here recovers them without disturbing what earlier
      // versions added — the same recovery pattern as the v82/v83
      // schema-version-collision blocks above.
      await customStatement('''
            CREATE TABLE IF NOT EXISTS checklist_templates (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers (id),
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
      await customStatement('''
            CREATE TABLE IF NOT EXISTS checklist_template_items (
              id TEXT NOT NULL PRIMARY KEY,
              template_id TEXT NOT NULL REFERENCES checklist_templates (id),
              title TEXT NOT NULL,
              category TEXT,
              notes TEXT NOT NULL DEFAULT '',
              due_offset_days INTEGER,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
      await customStatement('''
            CREATE TABLE IF NOT EXISTS trip_checklist_items (
              id TEXT NOT NULL PRIMARY KEY,
              trip_id TEXT NOT NULL REFERENCES trips (id),
              title TEXT NOT NULL,
              category TEXT,
              notes TEXT NOT NULL DEFAULT '',
              due_date INTEGER,
              is_done INTEGER NOT NULL DEFAULT 0,
              completed_at INTEGER,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_checklist_template_items_template_id
            ON checklist_template_items(template_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_trip_checklist_items_trip_id
            ON trip_checklist_items(trip_id)
          ''');
    }
    if (from < 98) await reportProgress();
    if (from < 99) {
      // Structured instructor link on certifications (issue #395).
      // PRAGMA-guarded so a healthy database no-ops and an interrupted
      // upgrade does not fail on a duplicate ALTER. (v99: renumbered
      // from v94 repeatedly as main claimed 94-96, then 97, then 98
      // while the branch was in review; a beforeOpen backstop
      // re-asserts this object too, so a version collision can't
      // strand it.)
      //
      // This block also created the buddy_roles table historically
      // (buddy professional credentials); v147 folds those rows into
      // certifications and drops the table.
      final certCols = await customSelect(
        "PRAGMA table_info('certifications')",
      ).get();
      if (certCols.isNotEmpty) {
        final existing = certCols.map((c) => c.read<String>('name')).toSet();
        if (!existing.contains('instructor_id')) {
          await customStatement(
            'ALTER TABLE certifications ADD COLUMN instructor_id TEXT '
            'REFERENCES buddies (id) ON DELETE SET NULL',
          );
        }
      }
    }
    if (from < 99) await reportProgress();
    if (from < 100) {
      // Saved dive plans (planner redesign Phase 2): three synced tables.
      // createTable is IF NOT EXISTS and the indexes are guarded, so this
      // block is idempotent; the beforeOpen backstop re-asserts the same
      // objects against schema-version collisions.
      await m.createTable(divePlans);
      await m.createTable(divePlanTanks);
      await m.createTable(divePlanSegments);
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_plan_tanks_plan_id
            ON dive_plan_tanks(plan_id)
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_dive_plan_segments_plan_id
            ON dive_plan_segments(plan_id)
          ''');
    }
    if (from < 100) await reportProgress();
    if (from < 101) {
      // GPS surface track logging (discussion #289). Raw idempotent DDL
      // (v98 checklist idiom) so interrupted migrations and schema-version
      // collisions are safe. gps_track_points_local is a device-local
      // recording buffer and is never synced.
      await customStatement('''
            CREATE TABLE IF NOT EXISTS gps_tracks (
              id TEXT NOT NULL PRIMARY KEY,
              start_time INTEGER NOT NULL,
              end_time INTEGER,
              tz_offset_minutes INTEGER NOT NULL DEFAULT 0,
              device_name TEXT,
              point_count INTEGER NOT NULL DEFAULT 0,
              points BLOB,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              hlc TEXT
            )
          ''');
      await customStatement('''
            CREATE TABLE IF NOT EXISTS gps_track_points_local (
              row_id INTEGER PRIMARY KEY AUTOINCREMENT,
              track_id TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              accuracy REAL
            )
          ''');
      await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_gps_track_points_local_track_id
            ON gps_track_points_local(track_id)
          ''');
    }
    if (from < 101) await reportProgress();
    if (from < 102) {
      await _relinkStrandedTankPressures();
    }
    if (from < 102) await reportProgress();
    if (from < 103) {
      // Two features independently claimed v103 on parallel branches
      // (media store spec 2026-07-10; dive roles #551/#547). Both
      // blocks are idempotent and touch disjoint tables, so the merge
      // keeps both and beforeOpen re-asserts each against the
      // schema-version collision this very overlap illustrates.

      // Media store Phase 1: content identity + upload stamps on media,
      // plus the secret-free store descriptor. Guarded ALTERs and
      // IF NOT EXISTS keep this idempotent.
      await _assertMediaStoreSchema();

      // Dive roles vocabulary (#551) + the diver's own role (#547).
      // createTable is IF NOT EXISTS and the seed is INSERT OR IGNORE,
      // so this block is idempotent. The existence guards (divers for
      // the seed's FK parent, dives for the ALTER) only matter for
      // minimal test-fixture databases.
      await m.createTable(diveRoles);
      final diversTable = await customSelect(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name='divers'",
      ).get();
      if (diversTable.isNotEmpty) {
        await customStatement(kSeedBuiltInDiveRolesSql);
      }
      final diveCols = await customSelect("PRAGMA table_info('dives')").get();
      final hasDiverRole = diveCols.any(
        (c) => c.read<String>('name') == 'diver_role',
      );
      if (diveCols.isNotEmpty && !hasDiverRole) {
        await customStatement('ALTER TABLE dives ADD COLUMN diver_role TEXT');
      }
    }
    if (from < 103) await reportProgress();
    if (from < 104) {
      await m.createTable(diverWeightEntries);
      await m.createTable(divePlanEquipment);
      Future<void> addColumnIfMissing(
        String table,
        String column,
        String type,
      ) async {
        final cols = await customSelect("PRAGMA table_info('$table')").get();
        final has = cols.any((c) => c.read<String>('name') == column);
        if (cols.isNotEmpty && !has) {
          await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
        }
      }

      await addColumnIfMissing('dives', 'weighting_feedback', 'TEXT');
      await addColumnIfMissing('dives', 'weighting_feedback_kg', 'REAL');
      await addColumnIfMissing('equipment', 'buoyancy_kg', 'REAL');
      await addColumnIfMissing('equipment', 'weight_kg', 'REAL');
      await addColumnIfMissing('dive_plans', 'planned_weight_kg', 'REAL');
      await addColumnIfMissing(
        'dive_plans',
        'planned_weight_placement',
        'TEXT',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_diver_weight_entries_diver_id '
        'ON diver_weight_entries(diver_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_dive_plan_equipment_plan_id '
        'ON dive_plan_equipment(plan_id)',
      );
    }
    if (from < 104) await reportProgress();
    if (from < 105) {
      // v105: per-sample compass heading (DC_SAMPLE_BEARING) on
      // dive_profiles. PRAGMA-guarded so a healthy database no-ops.
      final profileCols = await customSelect(
        "PRAGMA table_info('dive_profiles')",
      ).get();
      if (profileCols.isNotEmpty) {
        final hasHeading = profileCols.any(
          (c) => c.read<String>('name') == 'heading',
        );
        if (!hasHeading) {
          await customStatement(
            'ALTER TABLE dive_profiles ADD COLUMN heading REAL',
          );
        }
      }
    }
    if (from < 105) await reportProgress();
    if (from < 106) {
      // Lightroom auto-linking: connector identity on pending photo
      // suggestions. PRAGMA-guarded ALTERs keep this idempotent; the
      // beforeOpen backstop re-asserts it against parallel-branch
      // schema-version collisions (v104 weight planner and v105
      // heading both renumbered this block already, the same disease
      // the v103 comment documents).
      await _assertConnectorSuggestionColumns();
    }
    if (from < 106) await reportProgress();
    if (from < 107) {
      // Connected accounts (program spec section 5). Idempotent DDL;
      // beforeOpen re-asserts against parallel-branch version collisions.
      await _assertConnectedAccountsSchema();
      // Adopt Lightroom connector accounts (ids preserved: scan state
      // and suggestion rows key on them), then retire the table. Guarded
      // on table existence for fresh installs and minimal test fixtures.
      final connectorTable = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='connector_accounts'",
      ).get();
      if (connectorTable.isNotEmpty) {
        await customStatement(
          "INSERT OR IGNORE INTO connected_accounts "
          "(id, kind, label, account_identifier, created_at, updated_at) "
          "SELECT id, 'adobeLightroom', display_name, account_identifier, "
          "added_at, added_at FROM connector_accounts "
          "WHERE connector_type = 'lightroom'",
        );
        await customStatement('DROP TABLE IF EXISTS connector_accounts');
      }
    }
    if (from < 107) await reportProgress();
    if (from < 108) {
      // Manifest subscriptions become synced (program spec section 6).
      await _assertMediaSubscriptionsHlc();
    }
    if (from < 108) await reportProgress();
    if (from < 109) {
      // issue #553: certifications can belong to a buddy. Add the owner
      // column, then copy each buddy's inline cert into a certifications
      // row (deterministic id so per-device migration converges). The copy
      // runs here only -- see _migrateBuddyInlineCertifications.
      await _assertCertificationBuddyOwnerColumn();
      await _migrateBuddyInlineCertifications();
    }
    if (from < 109) await reportProgress();
    if (from < 110) {
      // issue #553 contract: the inline buddy cert columns are redundant
      // (data now lives in certifications rows). Copy once more as a
      // safety net -- covers a collision that advanced user_version to
      // v109 without running the v109 copy -- THEN drop. SQLite >= 3.35
      // supports DROP COLUMN; the PRAGMA guard keeps a fresh v110 db a
      // no-op.
      await _migrateBuddyInlineCertifications();
      final buddyCols = await customSelect(
        "PRAGMA table_info('buddies')",
      ).get();
      final names = buddyCols.map((c) => c.read<String>('name')).toSet();
      if (names.contains('certification_level')) {
        await customStatement(
          'ALTER TABLE buddies DROP COLUMN certification_level',
        );
      }
      if (names.contains('certification_agency')) {
        await customStatement(
          'ALTER TABLE buddies DROP COLUMN certification_agency',
        );
      }
    }
    if (from < 110) await reportProgress();
    if (from < 111) {
      await _assertEquipmentSetDefaultAndGeofenceSchema();
    }
    if (from < 111) await reportProgress();
    if (from < 112) {
      await _assertEquipmentThicknessColumn();
    }
    if (from < 112) await reportProgress();
    if (from < 113) {
      await _assertCnsCalculationMethodColumn();
    }
    if (from < 113) await reportProgress();
    if (from < 114) {
      // Guarded like the beforeOpen backstops: minimal migration-test
      // fixtures may lack the table entirely.
      final peerCursorCols = await customSelect(
        "PRAGMA table_info('sync_peer_cursors')",
      ).get();
      final hasAck = peerCursorCols.any(
        (c) => c.read<String>('name') == 'applied_hlc_high',
      );
      if (peerCursorCols.isNotEmpty && !hasAck) {
        await m.addColumn(syncPeerCursors, syncPeerCursors.appliedHlcHigh);
      }
      await ensureDeletionLogIndex();
    }
    if (from < 114) await reportProgress();
    // v120: planner Subsurface-parity columns. Version claimed in-worktree
    // per the schema-ladder convention; reconcile numbering at merge time.
    if (from < 120) {
      await _assertPlannerParitySchema();
    }
    if (from < 120) await reportProgress();
    // v121: course requirement tracker (renumbered from v114 at merge
    // time; v114 became the tombstone-GC migration on main). Both tables
    // are new, no data migration. createTable is idempotent (IF NOT
    // EXISTS).
    if (from < 121) {
      await m.createTable(courseRequirements);
      await m.createTable(courseRequirementDives);
    }
    if (from < 121) await reportProgress();
    // v122: gear service ledger (renumbered from v115 as main advanced
    // past it at merge time). The legacy backfill runs here only, never in
    // beforeOpen, so user-deleted schedules are not resurrected.
    if (from < 122) {
      await _assertServiceLedgerSchema();
      await _backfillLegacyServiceSchedules();
    }
    if (from < 122) await reportProgress();
    // v123: post-dive safety review tables + diver safety settings columns
    // (renumbered from v115 as main advanced past it at merge time).
    if (from < 123) {
      await _assertSafetyReviewSchema();
    }
    if (from < 123) await reportProgress();
    // v124: equipment type-specific attributes (renumbered from v115/v123
    // as main advanced past it at merge time). The legacy-column copy runs
    // here only, never in beforeOpen, so user-cleared attributes are not
    // resurrected.
    if (from < 124) {
      await _assertEquipmentAttributesSchema();
      await _migrateLegacyEquipmentColumnsToAttributes();
    }
    if (from < 124) await reportProgress();
    // v125: diver_settings.no_fly_preset column (safety phase 2, no-fly
    // countdown). Renumbered from v117/v124 as main advanced past it at
    // merge time.
    if (from < 125) {
      await _assertNoFlySettingsColumn();
    }
    if (from < 125) await reportProgress();
    // v126: emergency_chambers table + emergency card settings columns
    // (renumbered from v118 as main advanced past it at merge time).
    if (from < 126) {
      await _assertEmergencyCardSchema();
    }
    if (from < 126) await reportProgress();
    // v127: incidents table (near-miss log, safety phase 4). Renumbered
    // from v119 as main advanced past it at merge time.
    if (from < 127) {
      await _assertIncidentsSchema();
    }
    if (from < 127) await reportProgress();
    // v128: pre-dive checklist tables + built-in template seeds
    // (renumbered from v117/v127 as main advanced past it at merge time).
    if (from < 128) {
      await _assertPreDiveChecklistSchema();
      await _seedBuiltInPreDiveTemplates();
    }
    if (from < 128) await reportProgress();
    // v129: quality_findings table for the Data Quality Assistant
    // (renumbered from v118 as main advanced past it at merge time).
    if (from < 129) {
      await _assertQualityFindingsSchema();
    }
    if (from < 129) await reportProgress();
    // v130: media_enrichment.hlc so a photo's depth/time association
    // replicates through sync (it was local-only before).
    if (from < 130) {
      await _assertMediaEnrichmentHlcColumn();
    }
    if (from < 130) await reportProgress();
    // v131: reconcile legacy service intervals edited after the v122
    // backfill into General service clocks (deletion-log guarded).
    if (from < 131) {
      await _reconcileLegacyServiceSchedules();
    }
    if (from < 131) await reportProgress();
    // v132: correct dives whose bottom_time was stored equal to runtime by
    // older imports (Subsurface/MacDive/CSV via the UDDF entity importer,
    // which seeded bottom_time from the total-time `duration`). onUpgrade
    // only -- a deterministic local recompute, never beforeOpen, so a
    // profile-less dive a user deliberately left with bottom_time==runtime
    // is not re-touched on every open.
    if (from < 132) {
      await _backfillBottomTimeFromProfile();
    }
    if (from < 132) await reportProgress();
    // v133: deco stop band columns on diver_settings (renumbered from v130
    // as main advanced past it at merge time).
    if (from < 133) {
      await _assertDecoStopSettingsColumns();
    }
    if (from < 133) await reportProgress();
    // v134: media compressed-rendition columns (adjustable upload quality
    // Phase A). Renumbered from v130 as main advanced past it at merge time.
    if (from < 134) {
      await _assertMediaCompressedRenditionColumns();
    }
    if (from < 134) await reportProgress();
    // v135: color accent toggle columns on diver_settings. Devices that
    // upgraded through main's v136/v137 before this merge skipped 135;
    // the beforeOpen backstop re-asserts the columns for them.
    if (from < 135) {
      await _assertAccentColorSettingsColumns();
    }
    if (from < 135) await reportProgress();
    // v136: media_stores.last_sweep_at (Verify Library fleet cadence).
    // v136 shipped while v135 was still on its branch, so a DB can be at
    // 136+ without the accent columns; see the v135 note above.
    if (from < 136) {
      await _assertMediaStoresLastSweepColumn();
    }
    if (from < 136) await reportProgress();
    // v137: dives.weather_code + clear the English weather prose we
    // generated ourselves, so it re-renders in the diver's locale.
    if (from < 137) {
      await _assertWeatherCodeColumn();
      await _clearGeneratedWeatherDescriptions();
    }
    if (from < 137) await reportProgress();
    if (from < 139) {
      await _assertCylinderConfigSchema();
      await reportProgress();
    }
    // v140: media.retain_in_library (Media section Phase 1). v138
    // (divelogs) lives on a parallel branch; a DB arriving here from 137
    // runs the v139 cylinder block then this one, and the beforeOpen
    // backstop self-heals any DB a parallel branch strands in between.
    if (from < 140) {
      await _assertMediaRetainInLibraryColumn();
    }
    if (from < 140) await reportProgress();
    // v141: default currency for priced items (e.g. equipment). A DB
    // that upgraded past 141 on a parallel branch never enters this block;
    // the beforeOpen backstop below is its only path to the column.
    if (from < 141) {
      await _assertDefaultCurrencyColumn();
    }
    if (from < 141) await reportProgress();
    // v142: trips.return_flight_at (return-flight dive-window countdown).
    // v138 (#603) is reserved by a parallel branch; the beforeOpen
    // backstop heals any DB stranded between.
    if (from < 142) {
      await _assertTripReturnFlightColumn();
    }
    if (from < 142) await reportProgress();
    // v143: repair history + smart albums (Media section Phase 5). A DB
    // already carried to 144-150 by main never enters this block; the
    // beforeOpen backstop is its only path to those tables.
    if (from < 143) {
      await _assertMediaPhase5Schema();
    }
    if (from < 143) await reportProgress();
    // v144: dives.visibility_meters + the diver_settings visibility
    // calibration columns.
    if (from < 144) {
      await _assertVisibilityMetersColumn();
      await _assertVisibilityScaleColumns();
    }
    if (from < 144) await reportProgress();
    // v145: gps_tracks source/source_ref/name + non-destructive trim
    // bounds. Renumbered from v144 as main took that step for the
    // visibility scale work at merge time.
    if (from < 145) {
      await _assertGpsTrackColumns();
    }
    if (from < 145) await reportProgress();
    // v146: recompute bottom times the retired square-profile heuristic
    // derived too short on multilevel dives. Fingerprinted -- stored
    // values that exactly reproduce the old heuristic get replaced
    // (machine-derived, or a coincidental user match that recomputes to
    // a profile-consistent value); anything else is treated as user
    // data and left alone. onUpgrade only, hlc untouched (v132 pattern).
    if (from < 146) {
      await _recomputeMultilevelBottomTimes();
    }
    if (from < 146) await reportProgress();
    if (from < 147) {
      // Fold buddy professional credentials into certifications and drop
      // buddy_roles (spec 2026-08-08). Conversion + drop in one step; the
      // sqlite_master guard makes a fresh v147 db a no-op.
      await _migrateBuddyRolesToCertifications();
    }
    if (from < 147) await reportProgress();
    if (from < 148) {
      // Site media (issues #211/#627). Query index for the site gallery;
      // dedupe cleanup + partial unique index mirroring the dive-side
      // v38 pair so the same gallery asset cannot be linked to the same
      // site twice. The survivor is the oldest row, tie-broken by rowid:
      // created_at is epoch MILLISECONDS and a bulk import writes many
      // rows inside one, so a `created_at > MIN(created_at)` cleanup
      // would leave every tied row behind and the unique index below
      // would then abort the whole migration.
      // Guarded on media.site_id existing so partial migration-test
      // fixture databases (which build only the tables and columns their
      // migration touches) pass through unharmed.
      final mediaSiteCol = await customSelect(
        "SELECT name FROM pragma_table_info('media') "
        "WHERE name = 'site_id'",
      ).get();
      if (mediaSiteCol.isNotEmpty) {
        await customStatement('''
            CREATE INDEX IF NOT EXISTS idx_media_site_id
            ON media(site_id)
          ''');
        await customStatement('''
            DELETE FROM media
            WHERE platform_asset_id IS NOT NULL
              AND site_id IS NOT NULL
              AND rowid NOT IN (
                SELECT rowid FROM (
                  SELECT rowid, ROW_NUMBER() OVER (
                    PARTITION BY platform_asset_id, site_id
                    ORDER BY created_at ASC, rowid ASC
                  ) AS rn FROM media
                  WHERE platform_asset_id IS NOT NULL AND site_id IS NOT NULL
                ) WHERE rn = 1
              )
          ''');
        await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_media_asset_site_unique
            ON media(platform_asset_id, site_id)
            WHERE platform_asset_id IS NOT NULL AND site_id IS NOT NULL
          ''');
      }
    }
    if (from < 148) await reportProgress();
  }
}
