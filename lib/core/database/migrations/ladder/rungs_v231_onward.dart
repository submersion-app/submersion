part of '../app_database_migrations.dart';

/// The rungs that take a database to schema version 231 and above.
///
/// New rungs are appended here. When this file nears 800 lines, give
/// it a closed range like its neighbours and start the next one.
extension RungsFromV231 on AppDatabase {
  Future<void> _rungsFromV231(
    Migrator m,
    int from,
    Future<void> Function() reportProgress,
  ) async {
    // v231: diver_settings CCR ppO2 limits (issue #2342). Column-only
    // rung, no backfill.
    if (from < 231) {
      await _assertCcrPpO2LimitColumns();
    }
    if (from < 231) await reportProgress();

    // v232: trip cylinder slots, their ledger and the dive_tanks link
    // (issue #2325). Tables and one nullable column, no backfill.
    if (from < 232) {
      await _assertTripCylindersSchema();
    }
    if (from < 232) await reportProgress();
    // v233: dive_data_sources.source_diver_key (issue #1921). Column
    // only, no backfill: null means "not recorded", which resync treats
    // as "check the file for a second diver's match".
    if (from < 233) {
      await _assertSourceDiverKeyColumn();
    }
    if (from < 233) await reportProgress();
    // v234: equipment sharing (issue #2046). Table-only rung, no
    // backfill: no existing row changes.
    if (from < 234) {
      await _assertEquipmentSharingSchema();
    }
    if (from < 234) await reportProgress();
    // v235: saved Connections maps and the sightings dive index (issue
    // #2322). Table-and-index rung, no backfill.
    if (from < 235) {
      await _assertConnectionMapsSchema();
    }
    if (from < 235) await reportProgress();
    // v237: diver_settings.show_dive_figure (issue #2326). Column-only
    // rung, default off, no backfill.
    if (from < 237) {
      await _assertShowDiveFigureColumn();
    }
    if (from < 237) await reportProgress();
    // v238: saved_queries (issue #2365). A new synced table, so onUpgrade
    // need only create it; idempotent and re-asserted in the beforeOpen
    // backstop, which is what reaches a database already past 238.
    if (from < 238) {
      await _assertSavedQueriesSchema();
    }
    if (from < 238) await reportProgress();
    // v239: regulator service and O2 clean apply to first and second
    // stages (issue #2275). A one-time UPDATE of two built-in rows; not
    // in the backstop, as v202's built-in backfill is not.
    if (from < 239) {
      await _backfillRegulatorPartServiceKinds();
    }
    if (from < 239) await reportProgress();
    // v240: index dive_profile_events by dive (#1926). Scoped event
    // tombstones delete and match events by dive, and the table had no
    // index on it. Index-only rung; the floor rise it ships with is for
    // the tombstones, not for this. Re-asserted in beforeOpen.
    if (from < 240) {
      await _assertProfileEventsDiveIdIndex();
    }
    if (from < 240) await reportProgress();
    // v241: tank_pressure_series.source_id (issue #2440), backfilled
    // where the source is unambiguous.
    if (from < 241) {
      await _assertTankSeriesSourceIdColumn();
      await _backfillTankSeriesSourceIds();
    }
    if (from < 241) await reportProgress();
    // v242: the equipment service cache (issue #2365). Table-only rung;
    // re-asserted in beforeOpen.
    if (from < 242) {
      await _assertEquipmentServiceStatusTable();
    }
    if (from < 242) await reportProgress();
    // v244: DPV mission planner (issue #2086). Table-only rung, no
    // backfill: a plan without a mission row has no mission. Re-asserted
    // in beforeOpen.
    if (from < 244) {
      await _assertDivePlanMissionSchema();
    }
    if (from < 244) await reportProgress();
    // v245: index certifications by buddy (issue #2365). Index-only rung;
    // re-asserted in beforeOpen.
    if (from < 245) {
      await _assertCertificationsBuddyIndex();
    }
    if (from < 245) await reportProgress();
    // v247: the Explore derived metrics (issue #2195). Table-only rung, no
    // backfill: the startup sweep fills it. Re-asserted in beforeOpen.
    if (from < 247) {
      await _assertDerivedMetricsTable();
    }
    if (from < 247) await reportProgress();
    // v248: gear packed for a trip (issue #2338). Table-only rung, no
    // backfill; re-asserted in beforeOpen.
    if (from < 248) {
      await _assertTripEquipmentSchema();
    }
    if (from < 248) await reportProgress();
    // v249: the trip fill forecast's inputs (issue #2325, PR 4). Columns
    // only, no backfill; re-asserted in beforeOpen. 248 is #2585.
    if (from < 249) {
      await _assertTripFillForecastColumns();
    }
    if (from < 249) await reportProgress();
    // v250: a profile's hidden shared trips and sites (issue #2594).
    // Table-only rung, no backfill; re-asserted in beforeOpen.
    if (from < 250) {
      await _assertTripHidesSchema();
      await _assertSiteHidesSchema();
    }
    if (from < 250) await reportProgress();
    // v251: dive_tanks.source_id (issue #2716), backfilled where the
    // source is unambiguous. 250 is profile hides (#2594).
    if (from < 251) {
      await _assertDiveTankSourceIdColumn();
      await _backfillDiveTankSourceIds();
    }
    if (from < 251) await reportProgress();
    // v252: nav_tracks.diver_id, the route's owner (issue #2691 follow-up),
    // backfilled from each linked route's dive. The column is re-asserted in
    // beforeOpen; the backfill stays in the rung. 251 is
    // dive_tanks.source_id (#2716).
    if (from < 252) {
      await _assertNavTrackDiverIdColumn();
      await _backfillNavTrackDiverIds();
    }
    if (from < 252) await reportProgress();
    // v253: the settings a safety review was computed from (issue #2592).
    // Column only, no backfill; re-asserted in beforeOpen, which is what reaches a
    // database already at 254 (#2595 merged first).
    if (from < 253) {
      await _assertSafetyReviewInputsHashColumn();
    }
    if (from < 253) await reportProgress();
    // v254: dive_tanks.role_source, where a cylinder's role came from
    // (issue #2595). Column only, no backfill: a stored role's origin is
    // unknown, and a re-parse fills it. Re-asserted in beforeOpen. 253 is
    // the safety review inputs (#2592).
    if (from < 254) {
      await _assertTankRoleSourceColumn();
    }
    if (from < 254) await reportProgress();
    // v255: a safety stop is no decompression ceiling (issue #2550). Drops
    // the ceilings safety stop samples carried from every stored series.
    // Rung only: new imports no longer write them, and every reader ignores
    // one that still arrives from an older peer. 254 is dive_tanks.role_source
    // (#2595), 253 safety review inputs (#2592).
    if (from < 255) {
      await _scrubSafetyStopCeilings();
    }
    if (from < 255) await reportProgress();
    // v256: dives.computer_tissue_json (issue #1977). Column-only rung, no
    // backfill: null reads as "the computer reported no tissue state".
    if (from < 256) {
      await _assertComputerTissueColumn();
    }
    if (from < 256) await reportProgress();
    // v257: metadata-only profile revision history over existing
    // dive_profile_series rows (#1197). One history row per series id,
    // no sample/blob duplication. Re-asserted in beforeOpen.
    if (from < 257) {
      await _assertProfileSeriesHistorySchema();
      await _backfillProfileSeriesHistoryRows();
    }
    if (from < 257) await reportProgress();
    // v258: gas_switches.computer_id (issue #2582), backfilled from each
    // switch's cylinder as the column is added. Sits below 259, which main
    // shipped first, so the beforeOpen backstop is what reaches a database
    // already at 259, backfill included.
    if (from < 258) {
      await _assertGasSwitchComputerIdColumn();
    }
    if (from < 258) await reportProgress();
    // v259: dive_tanks.usage_duration (issue #1496). Column only, no
    // backfill: only a re-import can supply what the source recorded.
    // Re-asserted in beforeOpen. 258 is held by an open branch (#2828).
    if (from < 259) {
      await _assertTankUsageDurationColumn();
    }
    if (from < 259) await reportProgress();
    // v260: dive_tanks.shared_computer_ids (issue #2560), then infer the
    // shared cylinders of dives consolidated before the fold recorded them.
    // beforeOpen repeats both on every open for dives that arrive later.
    if (from < 260) {
      await _assertTankSharedComputerIds();
    }
    if (from < 260) await reportProgress();
    // v261: drop diver_settings.default_ceiling_source (issue #767), unread
    // since the ceiling line lost its source toggle (#755). Re-asserted in
    // beforeOpen.
    if (from < 261) {
      await _dropDefaultCeilingSourceColumn();
    }
    if (from < 261) await reportProgress();
    // v262: diver_settings columns for settings that now sync (issue
    // #2948): certification and course list view modes, and the profile
    // "metrics follow viewport" and pSCR ratio prefs. Column only; each
    // device adopts its old pref on load. Re-asserted in beforeOpen.
    if (from < 262) {
      await _assertSyncedDeviceSettingsColumns();
    }
    if (from < 262) await reportProgress();
    // v263: diver_settings.distance_unit (issue #2030), backfilled from each
    // diver's depth unit as the column is added. Re-asserted in beforeOpen.
    if (from < 263) {
      await _assertDistanceUnitColumn();
    }
    if (from < 263) await reportProgress();
    // v264: diver_settings.default_show_late_gas_switches (issue #2939).
    // Column only, defaulting on. Re-asserted in beforeOpen.
    if (from < 264) {
      await _assertLateGasSwitchSettingColumn();
    }
    if (from < 264) await reportProgress();
    // v265: Insights observation dismissals (synced) and the muted-rules
    // column on diver_settings (#2381). Additive; re-asserted in beforeOpen.
    if (from < 265) await _assertInsightObservationsSchema();
    if (from < 265) await reportProgress();
    // v266: media.site_category and media.display_size (issue #1039).
    // Columns only, no backfill: null is an uncategorized tile, which is how
    // every existing attachment already renders. Re-asserted in beforeOpen.
    // Renumbered from 263 (main shipped #2030 there).
    if (from < 266) {
      await _assertMediaSiteAttachmentColumns();
    }
    if (from < 266) await reportProgress();
    // v267: custom certification agencies and levels (issue #690). Table
    // and index only, no backfill: stored agency/level text are built-in
    // enum names, which stay valid ids. Re-asserted in beforeOpen.
    // Renumbered from 265 and 266, which main shipped first.
    if (from < 267) {
      await _assertCustomCertificationSchema();
    }
    if (from < 267) await reportProgress();
    // v268: equipment locations and their move log (issue #3037).
    // Re-asserted in beforeOpen.
    if (from < 268) {
      await _assertEquipmentLocationSchema();
    }
    if (from < 268) await reportProgress();
    // v269: diver_settings.hidden_built_in_ids (issue #401). Column-only
    // rung, no backfill: null reads back as "nothing hidden".
    if (from < 269) {
      await _assertHiddenBuiltInIdsColumn();
    }
    if (from < 269) await reportProgress();
    // v270: dive_weights.label and weight_preset_entries.label, a diver's
    // own name for a weight (issue #956). Defaulted columns, no backfill:
    // existing rows read '' (unnamed). Re-asserted in beforeOpen.
    if (from < 270) {
      await _assertWeightLabelColumns();
    }
    if (from < 270) await reportProgress();
    // v271: certification currency (issue #2267). Three synced tables and
    // the seeded built-in rule catalog, no backfill. Re-asserted in
    // beforeOpen. 268 is held by an open branch.
    if (from < 271) {
      await _assertCertificationCurrencySchema();
    }
    if (from < 271) await reportProgress();
    // v272: the role junctions (issue #1221), several roles per person on a
    // dive. Table-only rung, no backfill; re-asserted in beforeOpen.
    // Renumbered from 262, 264, 267, 270 and 271 as main shipped those; 268
    // is held by an open branch (#3043).
    if (from < 272) {
      await _assertDiveRoleLinkSchema();
    }
    if (from < 272) await reportProgress();
    // v273: TDI's own certification structure (issue #3072), replacing the
    // generic tech ladder it shared with IANTD and PSAI. One-shot data fix:
    // rewrites the eight unambiguous legacy TDI certification levels to
    // their new names and extends the currency rules that named the old
    // ones. Deliberately not re-asserted in beforeOpen, same convention as
    // other one-shot data fixes in this ladder.
    if (from < 273) {
      await _migrateTdiCertificationStructure();
    }
    if (from < 273) await reportProgress();
  }
}
