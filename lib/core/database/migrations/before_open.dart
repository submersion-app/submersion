part of 'app_database_migrations.dart';

/// The backstops that run on every open, after any upgrade.
///
/// A database that arrives by restore or by adopting a synced copy never
/// runs the upgrade ladder, so each rung that must hold for every file is
/// asserted again here.
extension BeforeOpenBackstops on AppDatabase {
  Future<void> _beforeOpen(OpeningDetails details) async {
    // v240 backstop: the events-by-dive index.
    await _assertProfileEventsDiveIdIndex();

    // v237 backstop: the dive figure switch.
    await _assertShowDiveFigureColumn();

    // v229 backstop: the per-set diver figure switch.
    await _assertEquipmentSetShowFigureColumn();

    // v227 backstop: the hidden built-in tank presets.
    await _assertHiddenTankPresetIdsColumn();

    // v222 backstop: the per-site vertical exaggeration overrides.
    await _assertSeascapeVerticalExaggerationOverridesColumn();

    // v220 backstop: the computer-set auto-apply opt-in column.
    await _assertEquipmentSetComputerAutoApplyColumn();

    // v217 and v219 backstop: the tag scope flags.
    await _assertTagScopeColumns();

    // v211 backstop: re-assert diver_settings.auto_tag_imports.
    await _assertAutoTagImportsColumn();

    // v210 backstop: the dive_tanks equipment link sets null on delete.
    // First, while foreign keys are still off: the rebuild it may do
    // drops the table, which with enforcement on would cascade into the
    // rows that hang off the tanks.
    await _assertDiveTankEquipmentSetNull();
    // v210 backstop: the child tables' own clocks.
    await _assertChildHlcColumns();

    // Enable foreign keys
    await customStatement('PRAGMA foreign_keys = ON');

    // v230 backstop: re-assert the nav_tracks table. A database that
    // arrives by restore or sync-adopt never runs onUpgrade.
    await _assertNavTracksSchema();

    // v207 backstop: re-assert the gear junctions' updated_at. A device
    // stranded without it has no age signal on those rows, so a stale
    // peer tombstone deletes a gear link unconditionally and no later
    // sync can revive it (issue #1728).
    await _assertJunctionUpdatedAtColumns();

    // v201 backstop: re-assert the cell linearity columns.
    await _assertTemplateItemSourceIdColumn();
    await _assertSessionItemSourceColumns();

    // v103 backstop: re-assert media store schema (the helper is
    // self-guarding when the media table is absent).
    await _assertMediaStoreSchema();

    // v130 backstop: re-assert the media_enrichment.hlc column.
    await _assertMediaEnrichmentHlcColumn();

    // v134 backstop: re-assert compressed-rendition columns.
    await _assertMediaCompressedRenditionColumns();

    // v136 backstop: re-assert media_stores.last_sweep_at.
    await _assertMediaStoresLastSweepColumn();

    // v137 backstop: re-assert dives.weather_code.
    await _assertWeatherCodeColumn();

    // v140 backstop: re-assert media.retain_in_library. A device
    // already at 141/142 never enters the `from < 140` block above, so
    // this is the ONLY path that gives it the column.
    await _assertMediaRetainInLibraryColumn();

    // v141 backstop: re-assert diver_settings.default_currency.
    await _assertDefaultCurrencyColumn();

    // v143 backstop: re-assert the Phase 5 tables. Same reason as the
    // v140 backstop above -- a parallel branch that claims 143 or higher
    // for something else would carry a device past the `from < 143`
    // block without ever creating these tables.
    await _assertMediaPhase5Schema();

    // v106 backstop: re-assert connector-suggestion columns (the helper
    // is self-guarding when the suggestions table is absent).
    await _assertConnectorSuggestionColumns();

    // v107 backstop: re-assert connected accounts schema.
    await _assertConnectedAccountsSchema();

    // v108 backstop: re-assert media_subscriptions.hlc.
    await _assertMediaSubscriptionsHlc();

    // v109 backstop (issue #553): re-assert the certifications.buddy_id
    // column ONLY. The one-time inline-cert data copy lives in the v109
    // onUpgrade block, not here -- re-running it every open would
    // resurrect a user-deleted buddy cert from the still-present inline
    // column (dropped in v110).
    await _assertCertificationBuddyOwnerColumn();

    // v111 backstop: re-assert equipment_sets.is_default + the
    // equipment_set_geofences table (parallel-branch collision self-heal).
    await _assertEquipmentSetDefaultAndGeofenceSchema();

    // v112 backstop: re-assert equipment.thickness column.
    await _assertEquipmentThicknessColumn();

    // v113 backstop: re-assert diver_settings.cns_calculation_method.
    await _assertCnsCalculationMethodColumn();

    // v114 backstop: re-assert sync_peer_cursors.applied_hlc_high and the
    // deletion_log unique index.
    final peerCursorCols = await customSelect(
      "PRAGMA table_info('sync_peer_cursors')",
    ).get();
    final hasAppliedHlcHigh = peerCursorCols.any(
      (c) => c.read<String>('name') == 'applied_hlc_high',
    );
    if (peerCursorCols.isNotEmpty && !hasAppliedHlcHigh) {
      await customStatement(
        'ALTER TABLE sync_peer_cursors ADD COLUMN applied_hlc_high TEXT',
      );
    }
    await ensureDeletionLogIndex();

    // v120 backstop: re-assert planner Subsurface-parity columns.
    await _assertPlannerParitySchema();

    // v121 backstop: course requirement tables (parallel-branch
    // collision self-heal; createTable is idempotent).
    await Migrator(this).createTable(courseRequirements);
    await Migrator(this).createTable(courseRequirementDives);

    // v152 backstop: site features table (parallel-branch
    // version-collision self-heal; createTable is idempotent).
    await Migrator(this).createTable(siteFeatures);

    // v217 backstop: site classification tables, seed and indexes
    // (parallel-branch version-collision self-heal; all idempotent).
    await _assertSiteClassificationSchema();

    // v219 backstop: the equipment tag junction and its index
    // (parallel-branch version-collision self-heal; all idempotent).
    await _assertEquipmentTagSchema();

    // v221 backstop: the rental gear notes table (parallel-branch
    // version-collision self-heal; createTable is idempotent).
    await _assertDiveCenterGearNotesSchema();

    // v232 backstop: the trip cylinder tables and the dive_tanks link
    // (parallel-branch version-collision self-heal; all idempotent).
    await _assertTripCylindersSchema();

    // v234 backstop: the equipment sharing tables and the share pair
    // index (parallel-branch version-collision self-heal; all
    // idempotent).
    await _assertEquipmentSharingSchema();

    // v235 backstop: connection_maps and idx_sightings_dive_id
    // (parallel-branch version-collision self-heal; idempotent).
    await _assertConnectionMapsSchema();

    // v238 backstop: re-assert the saved_queries table. A database that
    // arrives by restore or sync-adopt never runs onUpgrade, and one
    // already at 239 or later skips the v238 rung.
    await _assertSavedQueriesSchema();

    // v242 backstop: the equipment service cache (local, idempotent).
    await _assertEquipmentServiceStatusTable();

    // v245 backstop: the certifications buddy index (idempotent).
    await _assertCertificationsBuddyIndex();

    // v122 backstop: re-assert service ledger schema + built-in kinds.
    // The legacy backfill is NOT here (onUpgrade only) -- re-running it
    // would resurrect user-deleted schedules.
    await _assertServiceLedgerSchema();

    // v123 backstop: re-assert safety review tables + settings columns
    // (parallel-branch collision self-heal).
    await _assertSafetyReviewSchema();

    // v124 backstop: re-assert the equipment_attributes table (schema
    // only -- the legacy-column copy must NOT run here, it would
    // resurrect attribute rows the user has cleared).
    await _assertEquipmentAttributesSchema();

    // v125 backstop: re-assert diver_settings.no_fly_preset.
    await _assertNoFlySettingsColumn();

    // v126 backstop: re-assert emergency card schema.
    await _assertEmergencyCardSchema();

    // v127 backstop: re-assert incidents table.
    await _assertIncidentsSchema();

    // v128 backstop: re-assert the pre-dive checklist tables and their
    // built-in templates (same rationale as the dive-types re-seed).
    await _assertPreDiveChecklistSchema();
    await _seedBuiltInPreDiveTemplates();

    // v129 backstop: re-assert quality_findings schema.
    await _assertQualityFindingsSchema();

    // v133 backstop: re-assert the deco stop band settings columns.
    await _assertDecoStopSettingsColumns();

    // v135 backstop: re-assert color accent toggle columns.
    await _assertAccentColorSettingsColumns();

    // v139 backstop: re-assert the cylinder configuration tables. A
    // database stranded at any lower version by a parallel-branch
    // version collision self-heals here.
    await _assertCylinderConfigSchema();

    // v142 backstop: re-assert trips.return_flight_at.
    await _assertTripReturnFlightColumn();

    // v144 backstop: re-assert the measured-visibility column and the
    // diver_settings calibration columns.
    await _assertVisibilityMetersColumn();
    await _assertVisibilityScaleColumns();

    // v150 backstop: re-assert the coordinate format column.
    await _assertCoordinateFormatColumn();

    // v151 backstop: re-assert the seascape appearance column (the
    // shared-dev-machine ladder-collision trap: a DB already at this
    // version number from a parallel branch skips onUpgrade).
    await _assertSeascapeAppearanceColumn();

    // v153 backstop: re-assert the O2 cell millivolt columns (issue
    // #810; same parallel-branch version-collision self-heal).
    await _assertO2CellMillivoltColumns();

    // v154 backstop: re-assert the site entry/exit method columns (issue
    // #1104; same parallel-branch version-collision self-heal).
    await _assertSiteEntryExitMethodColumns();

    // v155 backstop: re-assert the gas model column (issue #828). A
    // database that arrives by restore or sync-adopt never runs
    // onUpgrade, and reading settings without this column throws. This
    // also covers a database stranded at 154 by the #1104 collision.
    await _assertGasModelColumn();
    // v158 backstop: re-assert the dive_profiles owning-source column
    // (issue #1149; same parallel-branch version-collision self-heal).
    // Column only -- _backfillProfileSourceIds is a full-table pass and
    // belongs to the ladder, not to every open.
    await _assertProfileSourceIdColumn();

    // v156 backstop: re-assert the dive_plan_tanks travel-gas column
    // (same parallel-branch version-collision self-heal).
    await _assertTravelGasColumn();

    // v191 backstop: re-assert the dive_plans per-band ascent rate
    // columns. A database that arrives by restore or sync-adopt never
    // runs onUpgrade, and reading a plan without them throws.
    await _assertPlanAscentRateColumns();

    // v195 backstop: re-assert media_species.hlc. A database that
    // arrives by restore or sync-adopt never runs onUpgrade, and both
    // reading a tag and stamping one throw without the column.
    await _assertMediaSpeciesHlcColumn();

    // v196 backstop: re-assert the weight-preset tables (issue #1609),
    // same restore/sync-adopt reasoning.
    await _assertWeightPresetTables();

    // v197 backstop: re-assert dive_plans.salinity_ppt.
    await _assertPlanSalinityPptColumn();

    // v198 backstop: re-assert diver_settings.default_planner_water_type.
    await _assertDefaultPlannerWaterTypeColumn();

    // v199 backstop: re-assert certifications.additional_credentials.
    await _assertCertificationCredentialsColumn();

    // v200 backstop: re-assert the transmitter table and the source index
    // column, same restore/sync-adopt reasoning.
    await _assertTransmitterTables();
    await _assertDiveTankSourceIndexColumn();
    // v203 backstop: re-assert the equipment_components table and the
    // gear-junction provenance columns (issue #1487). A database that
    // arrives by restore or sync-adopt never runs onUpgrade.
    await _assertEquipmentComponentsTable();
    await _assertGearProvenanceColumns();

    // v202 backstop: re-assert the condition columns and tables.
    await _assertEquipmentConditionSchema();
    // v206 backstop: the condition engine toggle columns.
    await _assertConditionEngineSettingsColumns();

    // v204 backstop: re-assert diver_settings.group_trips_in_dive_list.
    await _assertGroupTripsInDiveListColumn();

    // v214 backstop: re-assert the dive_plans stop-minimums column. A
    // database that arrives by restore or sync-adopt never runs
    // onUpgrade, and reading a plan without it throws.
    await _assertPlanStopMinimumsColumn();

    // v215 backstop: re-assert the dive_plans gas-options columns. A
    // database that arrives by restore or sync-adopt never runs
    // onUpgrade, and reading a plan without them throws.
    await _assertPlanGasOptionColumns();

    // v157 backstop: re-assert the default service price columns (issue
    // #829; same parallel-branch version-collision self-heal).
    await _assertServiceCostColumns();

    // v159 backstop: re-assert the consolidation time offset column
    // (issue #1177; same parallel-branch version-collision self-heal).
    // Reading a consolidated dive's sources throws without it.
    await _assertDataSourceTimeOffsetColumn();

    // v184 backstop: re-assert the merge provenance marker (issue
    // #1451; same parallel-branch version-collision self-heal).
    // Reading any dive's sources throws without it. Only the column is
    // re-asserted here; the one-shot backfill belongs to the rung.
    await _assertDataSourceMergeSlotColumn();

    // v208 backstop: re-assert the imported-file table and the reference
    // to it (issue #478; same parallel-branch version-collision
    // self-heal).
    await _assertImportedFilesSchema();

    // v213 backstop: re-assert service_schedules.anchor_set_at (same
    // parallel-branch version-collision self-heal). Every read of a
    // schedule selects it.
    await _assertServiceScheduleAnchorSetAtColumn();

    // v160 backstop: re-assert service_kinds.default_category. A device
    // that reached 160 or higher through a parallel branch never enters
    // the `from < 160` block above, and the seed SQL below is
    // INSERT OR IGNORE, so it cannot add the column to existing rows.
    await _assertServiceCategoryColumn();

    // v160 backstop: re-assert the service_records column rename. A
    // database that arrives by restore or sync-adopt never runs
    // onUpgrade, and every read of a service record would throw.
    await _assertServiceCategoryRename();

    // v161 backstop: re-assert diver_settings.default_show_o2_cell_mv
    // (issue #1235; same parallel-branch version-collision self-heal).
    await _assertO2CellMvDefaultColumn();

    // v177 backstop: re-assert the GTR settings columns (same
    // parallel-branch version-collision self-heal). The rbt repair is
    // deliberately NOT re-run here: it is a one-shot data fix.
    await _assertGtrSettingsColumns();

    // v163 backstop: re-assert
    // diver_settings.default_show_estimated_tank_pressure (issue #731;
    // same parallel-branch version-collision self-heal).
    await _assertEstimatedTankPressureDefaultColumn();

    // v179 backstop: re-assert dives.site_suggestion_dismissed_at (same
    // parallel-branch version-collision self-heal).
    await _assertSiteSuggestionDismissedAtColumn();

    // v164 backstop: re-assert media.manual_elapsed_seconds (issue
    // #1090; same parallel-branch version-collision self-heal). The
    // media row mapper reads it on every hydration.
    await _assertMediaManualElapsedColumn();
    // v165 backstop: re-assert diver_settings.trim_tank_pressure_at_
    // surfacing (issue #1092; same parallel-branch collision self-heal).
    await _assertSurfacingPressureColumn();

    // v168 backstop: re-assert buddies.is_favorite (issue #638). A
    // database that arrives by restore or sync-adopt never runs
    // onUpgrade, and every read of a buddy would throw without it.
    await _assertBuddyFavoriteColumn();
    // v170 backstop: re-assert the diver_settings.sac_unit rename and
    // value map (discussions #354, #803; same restore / sync-adopt
    // self-heal as v160). The layout rewrite deliberately stays rung-only.
    await _assertGasConsumptionDisplayColumn();
    // v171 backstop: re-assert trip_day_weather (same parallel-branch
    // version-collision self-heal). The helper is CREATE TABLE IF NOT
    // EXISTS plus CREATE UNIQUE INDEX IF NOT EXISTS, so it is a no-op on
    // every open after the first.
    await _assertTripDayWeatherSchema();

    // v173 backstop: re-assert dive_types.short_name (same
    // parallel-branch version-collision self-heal).
    await _assertDiveTypeShortNameColumn();

    // v174 backstop: re-assert dive_types.show_in_detail_header and
    // dive_types.show_in_list_view (same parallel-branch
    // version-collision self-heal).
    await _assertDiveTypeVisibilityColumns();

    // v175 backstop: re-assert dive_computers.equipment_id (gear twins;
    // same parallel-branch version-collision self-heal). Column only:
    // backfillDiveComputerGearTwins is a full-table pass that belongs to
    // the ladder, and re-running it on every open would resurrect a gear
    // item the user deleted.
    await _assertDiveComputerEquipmentColumn();

    // v180 backstop: re-assert the dives statistics-exclusion columns
    // (same parallel-branch version-collision self-heal). Safe to re-run
    // on every open: the helper is column-only with no backfill, so it
    // cannot resurrect or overwrite diver data.
    await _assertDiveStatsExclusionColumns();

    // v181 backstop: re-assert divers.photo and buddies.photo. A database
    // that arrives by restore or sync-adopt never runs onUpgrade, and
    // every read of a diver or buddy row would throw without the column.
    await _assertProfilePhotoColumns();

    // v185 backstop: re-assert diver_settings.dive_detail_layout. Every
    // settings read selects the whole row, so a database that skipped the
    // rung would throw on the first read instead of falling back to the
    // default layout.
    await _assertDiveDetailLayoutColumn();

    // v218 backstop: re-assert the diver_settings site detail columns.
    // Every settings read selects the whole row, so a database that
    // arrives by restore or sync-adopt without them would throw on the
    // first read.
    await _assertSiteDetailColumns();
    // v223 backstop: re-assert the buddy link and outing columns. The
    // buddy and dive mappers read the whole row, so a database that
    // arrives by restore or sync-adopt without them would throw on the
    // first read.
    await _assertBuddyProfileDiveLinkColumns();
    // v182 backstop: re-assert the packed profile series tables, then
    // pack any dive that still has legacy rows and no series row. A
    // schema-version collision with a parallel branch skips the rung on
    // devices that took the other branch's number first, so this is the
    // self-heal for series tables a device would otherwise never build.
    // Cheap once packed (an indexed NOT EXISTS per legacy dive). v183
    // drops the legacy tables, and the packer no-ops once they are gone
    // (a missing table reports no columns, so neither side is packable),
    // which is what makes this safe to keep running afterwards. Note the
    // v183 rung packs for itself: beforeOpen runs after onUpgrade, so on
    // the upgrading open this call comes too late to feed the drop.
    // Best effort: the ladder's own call is where a packing failure is
    // visible and retried. Here a malformed legacy table, a series table
    // a parallel branch shaped differently, or a busy lock from the
    // second isolate must not turn into a database that cannot open.
    //
    // The schema assert is INSIDE the try for that reason, the way the
    // v182 and v183 rungs already place it. CREATE TABLE IF NOT EXISTS
    // is a no-op against an existing table of any shape, so the assert
    // goes on to CREATE INDEX ... (dive_id, is_primary): against a
    // series table lacking that column SQLite raises "no such column",
    // and outside the guard that throw failed the open on every launch
    // rather than the one self-heal it belongs to.
    try {
      await _assertProfileSeriesSchema();
      final report = await packLegacyProfileRows(this);
      if (report.failedDives > 0) {
        developer.log(
          'beforeOpen: ${report.failedDives} dive(s) could not be packed '
          'and stay in the legacy tables for a later open',
          name: 'AppDatabase',
        );
      }
      // v183 convergence: the rung skips its table drop when its own
      // pack threw, and a rung never runs twice, so without this the
      // legacy tables would survive forever on that database. Once a
      // later open's pack succeeds the samples are all in the series and
      // the tables can go. Gated on the stored version so a database
      // still below 183 (a migration fixture, or one caught mid-ladder)
      // keeps its tables until its own rung has run, and gated per table
      // on the matching series table existing, for the same reason the
      // rung is: a series table whose foreign-key parents are absent is
      // never created, and the pack over it moves nothing.
      //
      // Nested try so the log names the step that threw. A drop or purge
      // failure here is its own event, and it must not be reported as a
      // packing failure; a pack failure, by contrast, has to keep the
      // drop from running at all, which is why this sits INSIDE the
      // pack's try rather than beside it.
      try {
        if (await _storedSchemaVersion() >= 183) {
          // The purge is unconditional at 183, matching its own doc:
          // those rows describe two entities this build never exports
          // again, so they are dead whether or not the legacy tables
          // are still here. Gating it on the tables tied it to
          // something unrelated, and a device that crossed 183 through
          // a parallel branch's rung of the same number (which dropped
          // the tables itself) then kept them forever: sync_records
          // that can never be acknowledged, and tombstones riding
          // every base publish.
          if (await _legacySampleTablesPresent()) {
            await _dropPackedLegacySampleTables();
          }
          await _purgeLegacySampleBookkeeping();
        }
      } catch (e, stackTrace) {
        developer.log(
          'Backstop drop of the legacy sample tables failed; continuing',
          name: 'AppDatabase',
          error: e,
          stackTrace: stackTrace,
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Backstop pack of legacy profile rows failed; continuing',
        name: 'AppDatabase',
        error: e,
        stackTrace: stackTrace,
      );
    }

    // v186 backstop: re-assert pre_dive_checklist_template_items.
    // equipment_id (same parallel-branch version-collision self-heal).
    // Safe to re-run on every open: the helper is column-only with no
    // backfill, so it cannot resurrect or overwrite diver data.
    await _assertTemplateItemEquipmentIdColumn();

    // v187 backstop: re-assert pre_dive_session_items.overdue_services
    // (same parallel-branch version-collision self-heal). Safe to re-run
    // on every open: the helper is column-only with no backfill, so it
    // cannot resurrect or overwrite diver data.
    await _assertSessionItemOverdueServicesColumn();

    // v188 backstop: re-assert the divers insurance phone columns. Every
    // diver read selects the whole row, so a database that arrives by
    // restore or sync-adopt without the rung would throw on the first read
    // rather than merely lack the numbers.
    await _assertInsurancePhoneColumns();

    // v189 backstop: re-assert media.equipment_id and its index (same
    // parallel-branch version-collision self-heal). Safe to re-run on
    // every open: column-and-index only, no backfill, so it cannot
    // resurrect or overwrite diver data.
    await _assertMediaEquipmentIdColumn();

    // v224 backstop: re-assert the media fact clock columns (parallel
    // branch version-collision self-heal). Columns only, no backfill: a
    // null clock falls back to the row clock, so nothing is lost.
    await _assertMediaFactClockColumns();

    // v226 backstop: re-assert media.cloud_asset_id (parallel-branch
    // version-collision self-heal). Column only, so it cannot touch
    // diver data.
    await _assertMediaCloudAssetIdColumn();
    // v228 backstop: the cylinder_fills table (parallel-branch
    // version-collision self-heal; createTable is idempotent).
    await _assertCylinderFillsSchema();

    // v233 backstop: re-assert dive_data_sources.source_diver_key
    // (parallel-branch version-collision self-heal). Nullable column
    // only, so it cannot touch diver data.
    await _assertSourceDiverKeyColumn();

    // v231 backstop: re-assert the diver_settings CCR ppO2 limits
    // (parallel-branch version-collision self-heal). Defaulted columns
    // only, so it cannot touch diver data.
    await _assertCcrPpO2LimitColumns();

    // v194 backstop: re-assert dive_tanks.transmitter_serial. Every tank
    // read selects the whole row, so a database that arrives by restore
    // or sync-adopt without the rung would throw on the first read.
    // Column only, no backfill, so it cannot touch diver data.
    await _assertTankTransmitterSerialColumn();

    // v145 backstop: re-assert the gps_tracks provenance and trim columns.
    await _assertGpsTrackColumns();

    // v147 backstop: re-run the buddy_roles fold (parallel-branch
    // schema-version collision self-heal). This is safe to re-run on
    // every open, unlike the #553 inline-cert copy above, which must
    // NEVER run here -- that helper's source columns (buddies.
    // certification_level/_agency) survive until v110, so re-running it
    // in beforeOpen would resurrect a user-deleted buddy cert from
    // still-present source data. _migrateBuddyRolesToCertifications has
    // no such hazard: its own DROP TABLE makes the sqlite_master guard a
    // strict no-op the moment buddy_roles is gone, so there is no source
    // data left to resurrect from. Its purpose here is purely to protect
    // a DB whose user_version advanced past 145 without ever running the
    // v147 block -- without this backstop, that DB would carry an
    // orphaned buddy_roles table whose credentials silently vanish from
    // the UI forever (nothing else reads that table).
    await _migrateBuddyRolesToCertifications();

    // Built-in dive types are reference data: identical on every device and
    // undeletable through DiveTypeRepository. Nothing else restores them --
    // the seed runs only in onCreate and the one-shot v93 step -- yet a
    // replace-adopt clears dive_types and refills from a payload that omits
    // built-ins, and a library copied from an already-empty device carries
    // the hole with it. Re-assert on every open, mirroring the built-in
    // species seed. INSERT OR IGNORE is idempotent, and the stable slug ids
    // are exactly what dive_dive_types references, so orphaned junction
    // rows resolve again.
    final diveTypesTable = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='dive_types'",
    ).get();
    if (diveTypesTable.isNotEmpty) {
      await customStatement(kSeedBuiltInDiveTypesSql);
    }

    // Backstop for schema-version collisions (issue #395; same disease
    // as the v77/v82/v83 sync-branch incidents): a parallel branch build
    // that claims the same schema version can advance user_version past
    // the v99 block without creating its objects, and no later migration
    // would ever repair that. The ALTER is PRAGMA-guarded, so re-assert
    // the v99 object on every open. (buddy_roles was also created here
    // historically; v147 dropped it, so it must NOT be re-created below
    // -- doing so would resurrect the dropped table on every open.)
    final certCols = await customSelect(
      "PRAGMA table_info('certifications')",
    ).get();
    final hasInstructorId = certCols.any(
      (c) => c.read<String>('name') == 'instructor_id',
    );
    if (certCols.isNotEmpty && !hasInstructorId) {
      await customStatement(
        'ALTER TABLE certifications ADD COLUMN instructor_id TEXT '
        'REFERENCES buddies (id) ON DELETE SET NULL',
      );
    }

    // v100 backstop: re-assert the dive plan tables (same collision
    // disease; createTable is idempotent). Their indexes
    // (idx_dive_plan_tanks_plan_id / idx_dive_plan_segments_plan_id) are
    // in the canonical performance-index set and created by
    // ensurePerformanceIndexes below, so they are not re-declared here.
    await Migrator(this).createTable(divePlans);
    await Migrator(this).createTable(divePlanTanks);
    await Migrator(this).createTable(divePlanSegments);

    // v103 backstop: dive_roles table + built-in seed + dives.diver_role
    // column (same collision disease; all DDL idempotent). The seed is
    // guarded on the divers FK parent existing, which only matters for
    // minimal test-fixture databases.
    await Migrator(this).createTable(diveRoles);
    final diversParent = await customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' AND name='divers'",
    ).get();
    if (diversParent.isNotEmpty) {
      await customStatement(kSeedBuiltInDiveRolesSql);
    }
    final divesCols = await customSelect("PRAGMA table_info('dives')").get();
    final hasDiverRoleCol = divesCols.any(
      (c) => c.read<String>('name') == 'diver_role',
    );
    if (divesCols.isNotEmpty && !hasDiverRoleCol) {
      await customStatement('ALTER TABLE dives ADD COLUMN diver_role TEXT');
    }

    // v104 backstop: weight prediction tables + columns (same collision
    // disease; all DDL idempotent). Indexes for the new tables are in the
    // canonical performance-index set below.
    await Migrator(this).createTable(diverWeightEntries);
    await Migrator(this).createTable(divePlanEquipment);
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
    await addColumnIfMissing('dive_plans', 'planned_weight_placement', 'TEXT');

    // v105 backstop: heading column on dive_profiles.
    final profilesCols = await customSelect(
      "PRAGMA table_info('dive_profiles')",
    ).get();
    final hasHeadingCol = profilesCols.any(
      (c) => c.read<String>('name') == 'heading',
    );
    if (profilesCols.isNotEmpty && !hasHeadingCol) {
      await customStatement(
        'ALTER TABLE dive_profiles ADD COLUMN heading REAL',
      );
    }

    // Performance indexes historically existed only in onUpgrade blocks,
    // so a database created fresh at a recent schema version -- or
    // arriving via restore or sync-adopt -- never got them, and per-dive
    // child lookups degraded to full scans of million-row tables.
    // Re-assert the canonical set on every open (IF NOT EXISTS: free
    // after the first heal). ANALYZE runs inside only when something was
    // actually created.
    final createdIndexes = await ensurePerformanceIndexes(this);
    assert(() {
      if (createdIndexes.isNotEmpty) {
        developer.log(
          'Healed ${createdIndexes.length} performance indexes: '
          '${createdIndexes.join(', ')}',
          name: 'AppDatabase',
        );
      }
      return true;
    }());

    // v149 backstop (issue #1032): re-assert the tag uniqueness indexes,
    // deduping first so the creation cannot abort. A database that
    // arrives by restore or sync-adopt never runs onUpgrade, and that is
    // exactly the second device the duplicate tags came from.
    await assertTagUniqueness(this);

    // v178 backstop (issue #1360): re-assert the dive-type junction
    // uniqueness index, deduping first so the creation cannot abort. Same
    // reasoning as the tag backstop above -- a database that arrives by
    // restore or sync-adopt never runs onUpgrade, and that is exactly the
    // second device the duplicate types came from.
    await assertDiveTypeUniqueness(this);

    // Data self-heal: backfill a primary dive_data_sources row for dives
    // that have profile samples but no source row (legacy file imports).
    // Without it, the 3D/spatial/compare views spin forever on those dives.
    // Idempotent and local-only (deterministic ids, no HLC bump). Runs
    // AFTER ensurePerformanceIndexes so its per-dive EXISTS/NOT EXISTS
    // subqueries hit idx_dive_profile_series_dive_primary /
    // idx_dive_data_sources_dive_id instead of full-scanning on a
    // fresh/restored DB.
    await _backfillMissingDataSources();

    // Data self-heal (issue #1064): adopt dives.computer_id from the
    // data-source rows for dives downloaded before v1.6 stamped it.
    // Idempotent and local-only (derived from already-synced rows, no HLC
    // bump). Also AFTER ensurePerformanceIndexes, for the same reason as
    // the backfill above.
    await _backfillDiveComputerIds();

    // Data self-heal (issue #1288): register the computers that
    // file-imported dives name, so they reach the filter at all. AFTER
    // the #1064 heal above, which resolves the same column from the
    // stronger download-derived signal.
    await _backfillImportedDiveComputers();
  }
}
