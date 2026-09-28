part of '../app_database_migrations.dart';

/// The rungs that take a database to schema versions 149 to 230.
extension RungsV149ToV230 on AppDatabase {
  Future<void> _rungsV149ToV230(
    Migrator m,
    int from,
    Future<void> Function() reportProgress,
  ) async {
    if (from < 149) {
      // Duplicate tags (issue #1032). The helper dedupes BEFORE creating
      // the unique indexes and its dedupe is total (rowid/id tie-breaks),
      // so no tie can survive to abort the index creation -- the failure
      // mode v148 documents. Self-guarding on the tables existing.
      await assertTagUniqueness(this);
    }
    if (from < 149) await reportProgress();
    // v150: the diver's GPS coordinate notation (issue #1041).
    if (from < 150) {
      await _assertCoordinateFormatColumn();
    }
    if (from < 150) await reportProgress();
    // v151: per-diver seascape terrain appearance (synced; PR #1073).
    if (from < 151) {
      await _assertSeascapeAppearanceColumn();
    }
    if (from < 151) await reportProgress();
    // v152: site features annotation table (slice 2).
    if (from < 152) {
      await Migrator(this).createTable(siteFeatures);
    }
    if (from < 152) await reportProgress();
    // v153: raw O2 cell output in millivolts (issue #810).
    if (from < 153) {
      await _assertO2CellMillivoltColumns();
    }
    if (from < 153) await reportProgress();
    // v154: site-level entry/exit method (issue #1104).
    if (from < 154) {
      await _assertSiteEntryExitMethodColumns();
    }
    if (from < 154) await reportProgress();
    // v155: selectable gas model for every pressure-to-volume
    // conversion (issue #828).
    if (from < 155) {
      await _assertGasModelColumn();
    }
    if (from < 155) await reportProgress();
    // v156: dive_plan_tanks travel-gas flag (lost-gas contingency
    // planning for stage/deco/diluent cylinders also used on descent).
    if (from < 156) {
      await _assertTravelGasColumn();
    }
    if (from < 156) await reportProgress();
    // v157: default service price on kinds and schedules (issue #829).
    if (from < 157) {
      await _assertServiceCostColumns();
    }
    if (from < 157) await reportProgress();
    // v158: owning-source FK on dive_profiles (issue #1149), plus the
    // one-time attribution of existing rows.
    if (from < 158) {
      await _assertProfileSourceIdColumn();
      await _backfillProfileSourceIds();
    }
    if (from < 158) await reportProgress();
    // v159: the consolidation time offset carried on a folded-in
    // source, so a re-parse can put its strand back on the dive's
    // clock (issue #1177).
    if (from < 159) {
      await _assertDataSourceTimeOffsetColumn();
    }
    if (from < 159) await reportProgress();
    // v160: default category on service_kinds, prefilled into a new
    // maintenance record, plus the service_records category rename
    // (service type unification).
    if (from < 160) {
      await _assertServiceCategoryColumn();
      await _assertServiceCategoryRename();
    }
    if (from < 160) await reportProgress();
    // v161: default_show_o2_cell_mv on diver_settings (issue #1235).
    if (from < 161) {
      await _assertO2CellMvDefaultColumn();
    }
    if (from < 161) await reportProgress();
    // v163: default_show_estimated_tank_pressure on diver_settings
    // (issue #731).
    if (from < 163) {
      await _assertEstimatedTankPressureDefaultColumn();
    }
    if (from < 163) await reportProgress();
    // v164: media.manual_elapsed_seconds (issue #1090).
    if (from < 164) {
      await _assertMediaManualElapsedColumn();
    }
    if (from < 164) await reportProgress();
    // v165: trim_tank_pressure_at_surfacing on diver_settings (#1092).
    if (from < 165) {
      await _assertSurfacingPressureColumn();
    }
    if (from < 165) await reportProgress();
    // v166: place_name_language on diver_settings (issue #1187).
    if (from < 166) {
      await _assertPlaceNameLanguageColumn();
    }
    if (from < 166) await reportProgress();
    // v168 (issue #638): buddies.is_favorite, so frequently-dived buddies
    // can be pinned to the top of the "Add buddy" picker regardless of
    // sort.
    if (from < 168) {
      await _assertBuddyFavoriteColumn();
    }
    if (from < 168) await reportProgress();
    // v170: diver_settings.sac_unit -> gas_consumption_display and the
    // saved dive-table layouts that named the old sacRate column
    // (discussions #354, #803).
    if (from < 170) {
      await _assertGasConsumptionDisplayColumn();
      await _rewriteLegacySacRateLayouts();
    }
    if (from < 170) await reportProgress();
    // v171: trip_day_weather, fetched per-day weather for trip days whose
    // dives supply none.
    if (from < 171) {
      await _assertTripDayWeatherSchema();
    }
    if (from < 171) await reportProgress();
    // v173: dive_types.short_name, an optional diver-set abbreviation
    // for custom dive types.
    if (from < 173) {
      await _assertDiveTypeShortNameColumn();
    }
    if (from < 173) await reportProgress();
    // v174: dive_types.show_in_detail_header and
    // dive_types.show_in_list_view, per-type badge-row visibility.
    if (from < 174) {
      await _assertDiveTypeVisibilityColumns();
    }
    if (from < 174) await reportProgress();
    // v175: dive_computers.equipment_id (gear twins). The backfill that
    // seeds the twins and links existing dives runs on the same rung; the
    // column has to land first. Renumbered from 169, which main overtook.
    if (from < 175) {
      await _assertDiveComputerEquipmentColumn();
      await backfillDiveComputerGearTwins(this);
    }
    if (from < 175) await reportProgress();
    // v177: GTR (gas time remaining) settings on diver_settings, and a
    // one-time repair of dive_profiles.rbt for rows that came through
    // libdivecomputer, which reports minutes into a seconds column.
    if (from < 177) {
      await _assertGtrSettingsColumns();
      await _scaleLibdcRbtMinutesToSeconds();
    }
    if (from < 177) await reportProgress();
    if (from < 178) {
      // Duplicate dive types (issue #1360). The helper dedupes BEFORE
      // creating the unique index and its dedupe is total (`id`
      // tie-breaks), so no tie can survive to abort the index creation --
      // the failure mode v148 documents. Self-guarding on the tables
      // existing.
      await assertDiveTypeUniqueness(this);
    }
    if (from < 178) await reportProgress();
    // v179: dives.site_suggestion_dismissed_at (site suggestion dismissal).
    if (from < 179) {
      await _assertSiteSuggestionDismissedAtColumn();
    }
    if (from < 179) await reportProgress();
    // v180: dives.excluded_from_stats and dives.excluded_from_gas_stats
    // (issues #526 and #1272). Column-only rung, no backfill: every
    // pre-existing row correctly defaults to included.
    if (from < 180) {
      await _assertDiveStatsExclusionColumns();
    }
    if (from < 180) await reportProgress();
    // v181: divers.photo and buddies.photo, the profile photo blobs.
    if (from < 181) {
      await _assertProfilePhotoColumns();
    }
    if (from < 181) await reportProgress();
    // v182: packed profile series tables, then pack every legacy
    // row-per-sample row into them. Both steps are idempotent (IF NOT
    // EXISTS DDL; INSERT OR IGNORE on ids derived from the identity
    // tuple), so a retry after a failed ladder, or a collision re-run,
    // is safe. v183 below drops the legacy tables.
    //
    // Wrapped the way the v183 rung below is, and for the same reason:
    // `profileSampleOf` casts unchecked, so one malformed legacy row
    // (a text timestamp, say) would otherwise throw out of onUpgrade,
    // `_runUpgradeLadder` would rethrow, and the database could not be
    // opened on any relaunch. Nothing is dropped here, so continuing
    // costs nothing: the legacy tables stay, and the v183 rung below or
    // the beforeOpen backstop packs them later. The schema assert is
    // inside the try for the same reason it is in v183: both the v183
    // rung and the backstop re-assert it, so swallowing it here cannot
    // leave the ladder with a schema no later step rebuilds.
    // Deliberately redundant with the v183 rung below: `from < 182`
    // implies `from < 183`, so on a single upgrade both packs run and
    // the second finds everything covered. Kept because the v182 SCHEMA
    // has to be correct on its own (a rung inserted between the two
    // later, or a ladder interrupted between them, would otherwise
    // leave a 182 database with legacy rows and no series), and because
    // the cost is now one pass per distinct identity rather than per
    // sample: see legacyCoverageIdentityColumns.
    if (from < 182) {
      try {
        await _assertProfileSeriesSchema();
        final report = await packLegacyProfileRows(this);
        if (report.failedDives > 0) {
          // Per-dive isolation means the pass as a whole succeeded, so
          // this is the only place the skipped dives are visible. The
          // residue count keeps their legacy table for a later open.
          developer.log(
            'v182: ${report.failedDives} dive(s) could not be packed and '
            'stay in the legacy tables for a later open',
            name: 'AppDatabase',
          );
        }
      } catch (e, stackTrace) {
        developer.log(
          'v182: packing legacy profile rows failed; keeping the legacy '
          'tables so no samples are lost',
          name: 'AppDatabase',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    if (from < 182) await reportProgress();
    // v183: the legacy row-per-sample tables are gone. Their sync
    // bookkeeping goes with them: pending records and tombstones for
    // entity types no peer exports. Idempotent (IF NOT EXISTS DDL,
    // INSERT OR IGNORE, IF EXISTS, DELETE), so a retried ladder is safe.
    // The pages come back at the one VACUUM in
    // DatabaseService._runUpgradeLadder.
    //
    // The pack repeats here rather than relying on the v182 rung above.
    // A device that reached 182 through a PARALLEL BRANCH's rung of the
    // same number never ran ours, so `from < 182` is false for it and
    // nothing has packed its rows; the beforeOpen backstop cannot save
    // it either, because drift runs beforeOpen AFTER onUpgrade and the
    // rows would already be dropped. Packing here is a no-op once
    // packed (one indexed NOT EXISTS per legacy dive).
    //
    // Two steps with different preconditions:
    //  - The bookkeeping purge is UNCONDITIONAL. Those rows describe
    //    entities nothing exports any more, so deleting them is correct
    //    whether or not the pack succeeded.
    //  - The table drop is CONDITIONAL, per table, on that pack having
    //    actually moved the samples. A series table a parallel branch
    //    shaped differently makes every packer INSERT fail; dropping
    //    anyway would destroy the only copy of those samples, and
    //    letting the exception out would leave a database that cannot
    //    open at all (backstop_resilience_test.dart pins that). A pack
    //    that returned normally is not enough on its own either: when a
    //    series table's foreign-key parents are absent
    //    (`dive_data_sources` for profiles, `dive_tanks` for pressures)
    //    `_assertProfileSeriesSchema` creates no series table, the
    //    packer finds nothing to pack into and returns having packed
    //    nothing, so `_dropPackedLegacySampleTables` requires the
    //    matching series table as well. Skipping a drop leaves a correct
    //    database that merely still carries the old table, and the
    //    beforeOpen backstop below drops it on the first later open
    //    whose pack succeeds.
    if (from < 183) {
      var packed = true;
      try {
        await _assertProfileSeriesSchema();
        final report = await packLegacyProfileRows(this);
        if (report.failedDives > 0) {
          // Per-dive isolation means the pass as a whole succeeded, so
          // this is the only place the skipped dives are visible. The
          // residue count keeps their legacy table for a later open.
          developer.log(
            'v183: ${report.failedDives} dive(s) could not be packed and '
            'stay in the legacy tables for a later open',
            name: 'AppDatabase',
          );
        }
      } catch (e, stackTrace) {
        packed = false;
        developer.log(
          'v183: packing legacy profile rows failed; keeping the legacy '
          'tables so no samples are lost',
          name: 'AppDatabase',
          error: e,
          stackTrace: stackTrace,
        );
      }
      // Guarded like the beforeOpen backstop's own copy of these two
      // steps, and for the same reason: a busy lock from the second
      // isolate, or a legacy table shape the residue count cannot read,
      // must not turn into a database that cannot open. onUpgrade
      // rethrows, so an escape here replays on every relaunch, while
      // skipping the drop costs only a table the backstop retires on a
      // later open.
      try {
        await _purgeLegacySampleBookkeeping();
        if (packed) {
          await _dropPackedLegacySampleTables();
        }
      } catch (e, stackTrace) {
        developer.log(
          'v183: purging or dropping the legacy sample tables failed; '
          'the backstop retries on a later open',
          name: 'AppDatabase',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    if (from < 183) await reportProgress();
    // v184: the marker a sequential Combine stamps on the provenance
    // rows it carries, plus a backfill for dives combined before it
    // existed (issue #1451).
    if (from < 184) {
      await _assertDataSourceMergeSlotColumn();
      await _backfillMergeSourceSlots();
    }
    if (from < 184) await reportProgress();
    // v185: diver_settings.dive_detail_layout. Column-only rung, no
    // backfill: a null reads back as the detailed layout, which is what
    // every existing diver was already getting.
    if (from < 185) {
      await _assertDiveDetailLayoutColumn();
    }
    if (from < 185) await reportProgress();
    // v186: pre_dive_checklist_template_items.equipment_id (issue #814).
    // Column-only rung, no backfill: every pre-existing item correctly
    // defaults to unlinked.
    if (from < 186) {
      await _assertTemplateItemEquipmentIdColumn();
    }
    if (from < 186) await reportProgress();
    // v187: pre_dive_session_items.overdue_services (issue #814 phase 2).
    // Column-only rung, no backfill: every pre-existing resolved item
    // correctly reads back as "nothing known" until it is next resolved.
    if (from < 187) {
      await _assertSessionItemOverdueServicesColumn();
    }
    if (from < 187) await reportProgress();
    // v188: divers.insurance_emergency_phone + divers.insurance_phone
    // (issue #1522). Column-only rung, no backfill.
    if (from < 188) {
      await _assertInsurancePhoneColumns();
    }
    if (from < 188) await reportProgress();
    // v189: media.equipment_id (issue #1517). Column-and-index rung, no
    // backfill: every pre-existing media row correctly reads back as
    // unattached to any gear.
    if (from < 189) {
      await _assertMediaEquipmentIdColumn();
    }
    if (from < 189) await reportProgress();
    // v190: recompress dive_data_sources.raw_data in place (issue #227).
    // No DDL. Guarded per row, so a blob that will not pack is left as it
    // is rather than failing the ladder. No beforeOpen backstop: the
    // backstops re-assert schema a partial upgrade may have missed, and
    // this rung changes none.
    if (from < 190) {
      await _recompressRawDiveData();
    }
    if (from < 190) await reportProgress();
    // v191: per-band planner ascent rates. Additive columns with
    // defaults, so an existing plan picks up the standard 6/3/1 m/min
    // ascent bands and its computed schedule redistributes time from the
    // stops into the ascent. Renumbered from 188: main landed the
    // insurance-phone, media-equipment-link and raw-data recompression
    // rungs at 188-190 while this branch was open.
    if (from < 191) {
      await _assertPlanAscentRateColumns();
    }
    if (from < 191) await reportProgress();
    // v194: dive_tanks.transmitter_serial, the air-integration
    // transmitter each downloaded tank was read from. Nullable, no
    // backfill: the serial is only known from a fresh download or
    // re-parse of the stored raw data. 192 and 193 are held by other
    // open branches.
    if (from < 194) {
      await _assertTankTransmitterSerialColumn();
    }
    if (from < 194) await reportProgress();
    // v195: media_species gains its own clock (issue #1638). Additive
    // nullable column. The rows already on disk stay NULL here and are
    // stamped by SyncRepository.backfillMissingHlc at the start of the
    // next sync, which is also what publishes them to peers. Renumbered
    // from 192, which is held by another open branch.
    if (from < 195) {
      await _assertMediaSpeciesHlcColumn();
    }
    if (from < 195) await reportProgress();
    // v196: weight_presets + weight_preset_entries (issue #1609).
    // Table-only rung, no backfill: a diver with no saved rig is the
    // correct starting state for everyone.
    if (from < 196) {
      await _assertWeightPresetTables();
    }
    if (from < 196) await reportProgress();
    // v197: custom planner salinity (ppt) for deco density. Renumbered
    // from 192: main took 194 through 196 while this branch was open.
    if (from < 197) {
      await _assertPlanSalinityPptColumn();
    }
    if (from < 197) await reportProgress();
    // v198: default planner water type on diver_settings. Renumbered
    // from 193 for the same reason as 197.
    if (from < 198) {
      await _assertDefaultPlannerWaterTypeColumn();
    }
    if (from < 198) await reportProgress();
    // v199: certifications.additional_credentials (dual credentials).
    // Column-only rung, no backfill. Renumbered from 197: main took 197
    // and 198 while this branch was open.
    if (from < 199) {
      await _assertCertificationCredentialsColumn();
    }
    if (from < 199) await reportProgress();
    // v200: transmitter registry (issue #1365) and the parsed-tank source
    // index on dive_tanks (issue #1314). No backfill: null means
    // "same as tank_order".
    if (from < 200) {
      await _assertTransmitterTables();
      await _assertDiveTankSourceIndexColumn();
    }
    if (from < 200) await reportProgress();
    // v201: the O2 cell linearity link (issue #986). Column-only rung,
    // no backfill: no existing item is a linearity item, and null is the
    // correct value for all three columns.
    if (from < 201) {
      await _assertTemplateItemSourceIdColumn();
      await _assertSessionItemSourceColumns();
    }
    if (from < 201) await reportProgress();
    // v202: equipment condition intelligence, phase 1. Additive columns
    // on six tables, the four condition tables, and a ONE-TIME backfill
    // of exposure defaults on the built-in kinds. The backfill is not in
    // the backstop: a diver may clear a default later. Taken while the
    // linearity link held 201 on its own branch; both now sit in order.
    if (from < 202) {
      await _assertEquipmentConditionSchema();
      await _backfillBuiltInExposureDefaults();
    }
    if (from < 202) await reportProgress();
    // v203: equipment assemblies (issue #1487). The equipment_components
    // template table plus two nullable provenance columns on each gear
    // junction. Additive, no backfill. Renumbered from 202.
    if (from < 203) {
      await _assertEquipmentComponentsTable();
      await _assertGearProvenanceColumns();
    }
    if (from < 203) await reportProgress();
    // v204: diver_settings.group_trips_in_dive_list (issue #1193).
    // Column-only rung, no backfill.
    if (from < 204) {
      await _assertGroupTripsInDiveListColumn();
    }
    if (from < 204) await reportProgress();
    // v206: condition engine toggles (condition phase 3b). Column-only
    // rung on diver_settings, no backfill: the defaults (engine on, no
    // rules disabled) are what every existing diver wants. A device
    // already at the shipped v207 skips this step and gets the columns
    // from the beforeOpen backstop.
    if (from < 206) {
      await _assertConditionEngineSettingsColumns();
    }
    if (from < 206) await reportProgress();
    // v207: an updated_at on the three composite-natural-key gear
    // junctions (issue #1728), backfilled from the parent each junction
    // rides. Numbered 207 because 205 and 206 are claimed by the
    // condition-intelligence branches still open. Idempotent, and
    // re-asserted in the beforeOpen backstop: a junction stranded without
    // the column is silently unprotected against a stale peer tombstone,
    // and the loss it lets through cannot be undone by a later sync.
    if (from < 207) {
      await _assertJunctionUpdatedAtColumns();
    }
    if (from < 207) await reportProgress();
    // v208: the stored original file a file-imported dive can be
    // re-parsed from, and the reference that names it (issue #478).
    if (from < 208) {
      await _assertImportedFilesSchema();
    }
    if (from < 208) await reportProgress();
    // v210: dive_tanks.equipment_id ON DELETE SET NULL, a table rebuild
    // (see _assertDiveTankEquipmentSetNull). Re-asserted in the
    // beforeOpen backstop, which runs it before foreign keys are
    // switched on.
    if (from < 210) {
      await _assertDiveTankEquipmentSetNull();
      await _assertChildHlcColumns();
    }
    if (from < 210) await reportProgress();
    // v211: diver_settings.auto_tag_imports (issue #998). Column-only
    // rung, no backfill. Existing rows default to on, so a device that
    // upgrades keeps auto-tagging its imports until the diver turns it
    // off. Renumbered from 208: main's own v208 (issue #478) and v210
    // (#1769) landed while this branch was open.
    if (from < 211) {
      await _assertAutoTagImportsColumn();
    }
    if (from < 211) await reportProgress();
    // v213: service_schedules.anchor_set_at. Column-only, no backfill:
    // a null keeps the pre-v213 rule for every existing baseline.
    if (from < 213) {
      await _assertServiceScheduleAnchorSetAtColumn();
    }
    if (from < 213) await reportProgress();
    // v214: dive_plans.stop_minimums_json (replan-this-dive minimum stop
    // durations). Additive nullable column, no backfill. Renumbered from
    // 201, then 209, then 211: main shipped 211 and 213 while this branch
    // was open.
    if (from < 214) {
      await _assertPlanStopMinimumsColumn();
    }
    if (from < 214) await reportProgress();
    // v215: dive_plans gas-options columns (SAC factor, problem solving
    // time, ppO2 bottom/deco overrides, best-mix END, O2 narcotic
    // override). Additive, defaults preserve prior behavior. Renumbered
    // from 202, then 212: stop-minimums took 214.
    if (from < 215) {
      await _assertPlanGasOptionColumns();
    }
    if (from < 215) await reportProgress();
    // v217: dive site types and tags (issue #1765). Table-and-column
    // rung, no backfill beyond the built-in seed.
    if (from < 217) {
      await _assertTagScopeColumns();
      await _assertSiteClassificationSchema();
    }
    if (from < 217) await reportProgress();
    // v218: diver_settings site detail columns. Column-only rung, no
    // backfill: null reads back as the default order and layout.
    if (from < 218) {
      await _assertSiteDetailColumns();
    }
    if (from < 218) await reportProgress();
    // v219: equipment tags (issue #1942). Column-and-table rung, no
    // backfill: existing tags stay off equipment.
    if (from < 219) {
      await _assertTagScopeColumns();
      await _assertEquipmentTagSchema();
    }
    if (from < 219) await reportProgress();
    // v220: equipment_sets.auto_apply_on_computer_import (issue #1020).
    // Column-only rung, no backfill: null/0 reads back as off.
    if (from < 220) {
      await _assertEquipmentSetComputerAutoApplyColumn();
    }
    if (from < 220) await reportProgress();
    // v221: rental gear memory (issue #2075). Table-only rung, no
    // backfill.
    if (from < 221) {
      await _assertDiveCenterGearNotesSchema();
    }
    if (from < 221) await reportProgress();
    // v222: diver_settings.seascape_vertical_exaggeration_overrides
    // (issue #2141 follow-up). Column-only rung, no backfill: null
    // reads back as fully automatic for every site.
    if (from < 222) {
      await _assertSeascapeVerticalExaggerationOverridesColumn();
    }
    if (from < 222) await reportProgress();
    // v223: buddy profile links and dive outings (issue #2002).
    // Column-only rung, no backfill: null reads back as "not linked"
    // and "no siblings".
    if (from < 223) {
      await _assertBuddyProfileDiveLinkColumns();
    }
    if (from < 223) await reportProgress();
    // v224: the two media fact clocks, backfilled from the row clock so
    // an existing row starts with a clock on every group.
    if (from < 224) {
      await _assertMediaFactClockColumns();
      await _backfillMediaFactClocks();
    }
    if (from < 224) await reportProgress();
    // v226: media.cloud_asset_id. Column only, no backfill.
    if (from < 226) {
      await _assertMediaCloudAssetIdColumn();
    }
    if (from < 226) await reportProgress();
    // v227: diver_settings.hidden_tank_preset_ids (issue #2305).
    // Column-only rung, no backfill: null reads back as "none hidden".
    if (from < 227) {
      await _assertHiddenTankPresetIdsColumn();
    }
    if (from < 227) await reportProgress();
    // v228: cylinder fill history (issue #2334). Table-only rung, no
    // backfill.
    if (from < 228) {
      await _assertCylinderFillsSchema();
    }
    if (from < 228) await reportProgress();
    // v229: equipment_sets.show_figure (issue #2326). Column-only rung,
    // default off, no backfill.
    if (from < 229) {
      await _assertEquipmentSetShowFigureColumn();
    }
    if (from < 229) await reportProgress();
    // v230: nav_tracks -- measured underwater routes from Seacraft ENC
    // navigation consoles and similar IMU-equipped computers (spec
    // 2026-09-10-underwater-nav-track-design.md, issues #1195, #1445).
    // A new synced table, so onUpgrade need only create it; idempotent
    // and re-asserted in the beforeOpen backstop against the
    // parallel-branch version collisions noted above.
    if (from < 230) {
      await _assertNavTracksSchema();
    }
    if (from < 230) await reportProgress();
  }
}
