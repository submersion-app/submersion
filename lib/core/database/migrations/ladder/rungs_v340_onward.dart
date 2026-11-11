part of '../app_database_migrations.dart';

/// The rungs that take a database to schema version 340 and above.
///
/// New rungs are appended here. When this file nears 800 lines, give
/// it a closed range like its neighbours and start the next one.
///
/// A rung that rewrites stored values in place (not one that only adds
/// columns or copies them) lists the column in `changeLogRewrittenColumns`,
/// so a revert will not put back a value from before the rewrite.
extension RungsFromV340 on AppDatabase {
  Future<void> _rungsFromV340(
    Migrator m,
    int from,
    Future<void> Function() reportProgress,
  ) async {
    // v340: a combined dive's water temperature, CNS at the end and OTU
    // describe the whole dive again rather than its first segment (issue
    // #4136). Data only, so the compatibility floor does not move.
    if (from < 340) await repairCombinedDiveSummaries(this);
    if (from < 340) await reportProgress();

    // v341: dive_plan_series, a saved repetitive dive series, and the
    // dive_plans / dive_plan_tanks columns that place a plan in one (issue
    // #3565). Table and columns only, no backfill: a plan with no series is
    // a one-dive series. Re-asserted in beforeOpen. Renumbered from 339 and
    // then 340, which upstream claimed first for issues #3361 and #4136.
    if (from < 341) {
      await _assertDivePlanSeriesTable();
      await _assertDivePlanSeriesColumns();
    }
    if (from < 341) await reportProgress();

    // v342: dive_plans.fixed_start, whether a planned dive's start was set by
    // the diver rather than following from its surface interval, and
    // dive_plans.setting_overrides, the setting groups a dive keeps its own
    // values for (issue #3565, phase 2). Defaulted, no backfill. Re-asserted
    // in beforeOpen.
    if (from < 342) await _assertDivePlanPhase2Columns();
    if (from < 342) await reportProgress();

    // v343: diver_settings.first_day_of_week, the day a week starts on
    // (issue #4232). Defaulted to 'auto', no backfill. Re-asserted in
    // beforeOpen.
    if (from < 343) await _assertFirstDayOfWeekColumn();
    if (from < 343) await reportProgress();

    // v344: nav_tracks.source_file, the original file a route was imported
    // from (issue #4231). A nullable column with no backfill: a route
    // imported before keeps none until it is updated from its file.
    // Re-asserted in beforeOpen.
    if (from < 344) await _assertNavTrackSourceFileColumn();
    if (from < 344) await reportProgress();

    // v345: cylinder_pairings, two cylinders linked as a twin set over a
    // range of days, cylinder_fills.filled_together_id and
    // dive_tanks.twin_passport_id (issue #4242). Table and nullable columns
    // only, no backfill. Re-asserted in beforeOpen.
    if (from < 345) await _assertTwinSetSchema();
    if (from < 345) await reportProgress();

    // v346: an item's last service date is its newest service record's
    // again where logging an older record had moved it back (issue #4201).
    // Data only, so the compatibility floor does not move. Numbered 346 so
    // an open PR that also claimed 343 can take 345.
    if (from < 346) await _repairLastServiceDates();
    if (from < 346) await reportProgress();

    // v347: diver_settings.show_photo_background_on_dive_cards and the
    // photo overlay opacity per theme. Columns only, defaulted; re-asserted
    // in beforeOpen.
    if (from < 347) await _assertDiveCardPhotoBackgroundColumn();
    if (from < 347) await reportProgress();

    // v348: dive_derived_metrics.gas_use_s and gas_use_avg_depth_m, the
    // underwater time and depth whole-dive SAC and RMV divide by, and where
    // surface breathing stretched them (issue #2930). Nullable columns on a
    // device-local cache, no backfill: the engine version bump makes the
    // sweep rebuild every row. Plus dive_tanks.surface_breathing_duration,
    // minutes the diver enters, synced and nullable. Re-asserted in
    // beforeOpen.
    if (from < 348) await _assertDerivedMetricsGasUseColumns();
    if (from < 348) await _assertTankSurfaceBreathingColumn();
    if (from < 348) await reportProgress();

    // v349: an empty dives.water_temp takes the temperature the dive's source
    // rows measured; a download kept it on the source row only (issue #4333).
    // Data only, so the compatibility floor does not move. It fills empty
    // columns and rewrites none, so changeLogRewrittenColumns needs no entry.
    // Numbered 349 so open PR #4327, which claimed 347, can take 348.
    if (from < 349) await fillDiveWaterTempsFromSources(this);
    if (from < 349) await reportProgress();

    // v350: sightings.abundance, whether a sighting was only seen, sorted
    // into a REEF group, or counted exactly (issue #4337). A nullable
    // column with no backfill: null means the count is exact, so every
    // existing sighting reads as before. Raises the sync floor (see
    // minimumCompatibleSchemaVersion). Re-asserted in beforeOpen. Numbered
    // 350: main holds 349 and open PR #4327 is to take 348.
    if (from < 350) await _assertSightingAbundanceColumn();
    if (from < 350) await reportProgress();

    // v351: diver_settings.equipment_collapsed_groups, the Equipment page's
    // folded group keys (issue #4184). Nullable, no backfill. Re-asserted in
    // beforeOpen.
    if (from < 351) await _assertEquipmentCollapsedGroupsColumn();
    if (from < 351) await reportProgress();

    // v352: media.observation_id, the check-in a gear photo backs up, and
    // equipment.cover_media_id, the photo that stands for an item (issue
    // #3355). Nullable columns, no backfill. Re-asserted in beforeOpen.
    // Numbered 352: main holds 350, 351 and 354, and left 352 for this.
    if (from < 352) await _assertEquipmentPhotoColumns();
    if (from < 352) await reportProgress();

    // v354: dives.is_draft, a dive marked at the site that waits for its
    // readings (issue #637). Defaulted, no backfill, so the compatibility
    // floor does not move. Numbered 354: main holds 351 and open work
    // claims 352 and 353.
    if (from < 354) await _assertDiveIsDraftColumn();
    // v354 too: dive_health_records, Apple Health readings per dive.
    if (from < 354) await _assertDiveHealthRecordsTable();
    if (from < 354) await reportProgress();

    // v356: a merge slot on every source row of a dive that has no primary
    // row and no slot yet, one per display strand, so a combine the v184
    // rung could not classify keeps a re-parse off its rows after a
    // consolidation gives it a primary row (issue #4367). Data only, so the
    // compatibility floor does not move. It fills empty slots and rewrites
    // none, so changeLogRewrittenColumns needs no entry. Numbered 356: main
    // holds 354 and open work claims 352, 353 and 355.
    if (from < 356) await stampCombinedDiveSourceSlots(this);
    if (from < 356) await reportProgress();

    // v357: dive_profile_series.is_edit, the synced mark that a series is
    // the diver's manual edit (issue #4386). Nullable, no backfill: a series
    // written before it stays unknown. Re-asserted in beforeOpen. Numbered
    // 357 because main holds 356; renumbered from 353, then 355.
    if (from < 357) await _assertProfileSeriesIsEditColumn();
    if (from < 357) await reportProgress();

    // v358: a dive's rating back on the 1 to 5 star scale where a UDDF
    // import stored the file's 1 to 10 value, or 0 for an unrated dive
    // (issue #4415). Data only, so the compatibility floor does not move.
    // It rewrites dives.rating, so changeLogRewrittenColumns lists it.
    if (from < 358) await _repairOutOfScaleDiveRatings();
    if (from < 358) await reportProgress();

    // v359: diver_settings.pin_profile_on_scroll, whether dive details pins
    // a profile strip (issue #4423). Column only, defaulted on; re-asserted
    // in beforeOpen.
    if (from < 359) await _assertPinProfileOnScrollColumn();
    if (from < 359) await reportProgress();

    // v360: diver_settings.show_country_flags, the switch for the flags
    // beside site locations and trips (issue #4426). Defaulted on, no
    // backfill, so the compatibility floor does not move. Re-asserted in
    // beforeOpen. Renumbered from 359, which main took for #4423.
    if (from < 360) await _assertShowCountryFlagsColumn();
    if (from < 360) await reportProgress();

    // v361: dive_sites.country_code, the site's ISO country code (issue
    // #4426), backfilled from the country text each site already holds where
    // that text names one country. Nullable and offline, so the floor does
    // not move. The column is re-asserted in beforeOpen; the backfill runs
    // here only. Renumbered from 360.
    if (from < 361) await _assertSiteCountryCodeColumn();
    if (from < 361) await _backfillSiteCountryCodes();
    if (from < 361) await reportProgress();
  }
}
