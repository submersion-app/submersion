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
    // v274: diver_settings.has_accepted_planning_disclaimer (issue #3120).
    // Column-only rung, no backfill: an existing diver reads false and sees
    // the disclaimer dialog once. Re-asserted in beforeOpen.
    if (from < 274) {
      await _assertHasAcceptedPlanningDisclaimerColumn();
    }
    if (from < 274) await reportProgress();
    // v275: diver_settings.default_start_pressure retyped INTEGER to REAL
    // (issue #3091). Re-asserted in beforeOpen.
    if (from < 275) {
      await _retypeDefaultStartPressureColumn();
    }
    if (from < 275) await reportProgress();
    // v276: diver_settings.icd_warnings_enabled (issue #3121). Column
    // only, defaulting on; re-asserted in beforeOpen.
    if (from < 276) {
      await _assertIcdWarningsColumn();
    }
    if (from < 276) await reportProgress();
    // v277: documents store (issue #2613). Tables re-asserted in beforeOpen;
    // the data copy runs here only, never on open.
    if (from < 277) {
      await _assertDocumentsSchema();
      await _migrateLegacyDocuments();
    }
    if (from < 277) await reportProgress();
    // v278: dives.visibility_min_meters / visibility_max_meters (issue
    // #3226). Columns only; re-asserted in beforeOpen.
    if (from < 278) {
      await _assertVisibilityRangeColumns();
    }
    if (from < 278) await reportProgress();
    // v279: dive_computer_connections (issue #3106). Table only;
    // re-asserted in beforeOpen.
    if (from < 279) {
      await _assertDiveComputerConnectionSchema();
      // Once, before this build writes any hex: every 8-digit Shearwater
      // download serial is still libdivecomputer's decimal here. The
      // every-open heal leaves 8 digits alone, since afterwards they can be
      // hex (issue #3106).
      await _healShearwaterDownloadSerialsOnUpgrade();
    }
    if (from < 279) await reportProgress();
    // v280: no data change (issue #2361). Carries the sync floor past the
    // builds that cannot parse AccountKind.webdav.
    if (from < 280) await reportProgress();
    // v281: diver_settings.trend_gap_collapse_months (issue #3251). Column
    // only, defaulting to a year; re-asserted in beforeOpen. Renumbered from
    // 278, 279 and 280, which #3226, #3106 and #2361 shipped first.
    if (from < 281) {
      await _assertTrendGapCollapseColumn();
    }
    if (from < 281) await reportProgress();
    // v283: dive_profile_series.activated_at (issue #3189). The column and
    // its one-time backfill; re-asserted in beforeOpen.
    if (from < 283) {
      await _assertProfileSeriesActivatedAt();
    }
    if (from < 283) await reportProgress();
    // v284: diver_settings.profile_color_* (issue #3012). Columns only, null
    // meaning the default colour; re-asserted in beforeOpen. Renumbered from
    // 282, which PR #3133 holds, after #3296 shipped 283.
    if (from < 284) {
      await _assertProfileMetricColorColumns();
    }
    if (from < 284) await reportProgress();
    // v285: nav_tracks.source_metadata (issue #3047). Column only, no
    // backfill; re-asserted in beforeOpen through _assertNavTracksSchema.
    if (from < 285) {
      await _assertNavTrackSourceMetadataColumn();
    }
    if (from < 285) await reportProgress();
    // v286: diver_settings.equipment_default_statuses (issue #2628). Column
    // only; re-asserted in beforeOpen.
    if (from < 286) {
      await _assertEquipmentDefaultStatusesColumn();
    }
    if (from < 286) await reportProgress();
    // v287: dive_tanks.passport_id (issue #2650). Column only, no backfill:
    // nothing recorded which tag an older tank came from. Re-asserted in
    // beforeOpen; the index is in performance_indexes.dart. Renumbered from
    // 285 and 286, which #3306 and #3319 shipped first.
    if (from < 287) {
      await _assertTankPassportIdColumn();
    }
    if (from < 287) await reportProgress();
    // v288: the dive_courses junction and the certification-side course link
    // (issue #2515). Schema re-asserted and links re-seeded in beforeOpen;
    // the certification backfill runs here only.
    if (from < 288) {
      await _assertDiveCourseSchema();
      await seedDiveCourseLinks(this);
      await backfillCertificationCourseLinks(this);
    }
    if (from < 288) await reportProgress();
    // v289: shared dive-site library tables and dive_sites.shared_library_id
    // (issue #2567), plus the key, trust and backup columns added before it
    // shipped. Idempotent; re-asserted in beforeOpen, which is how a database
    // already past 289 gains the later columns. Renumbered from 288 after
    // #2515 shipped 288.
    if (from < 289) {
      await _assertSharedLibrarySchema();
    }
    if (from < 289) await reportProgress();
    // v290: dive_plan_segments.split_at_configured_rate (issue #3264).
    // Column only, defaulting off; re-asserted in beforeOpen. Renumbered
    // from 277, 282 then 286, as earlier rungs shipped or were claimed
    // first.
    if (from < 290) {
      await _assertSegmentSplitAtRateColumn();
    }
    if (from < 290) await reportProgress();
    // v291: shared_libraries.description (issue #3389). Column only, read
    // from each library's info.json at the next sync; re-asserted in
    // beforeOpen through _assertSharedLibrarySchema.
    if (from < 291) {
      await _assertSharedLibrarySchema();
    }
    if (from < 291) await reportProgress();
    // v292: shared_libraries.removals_json (issue #3481). Column only, filled
    // from the library's removal records at the next sync; re-asserted in
    // beforeOpen through _assertSharedLibrarySchema.
    if (from < 292) {
      await _assertSharedLibrarySchema();
    }
    if (from < 292) await reportProgress();
    // v293: connected_accounts.location (issue #3482). Column only, written
    // when a device saves or signs in to an S3 or WebDAV account;
    // re-asserted in beforeOpen through _assertConnectedAccountsSchema.
    if (from < 293) {
      await _assertConnectedAccountsSchema();
    }
    if (from < 293) await reportProgress();
    // v294: clears certifications.photo_front / photo_back wherever the
    // v277 copy put the card in the documents store (issue #3502). Data
    // step, rung only. 293 is claimed by the accounts work (#3482).
    if (from < 294) {
      await _clearCopiedCardPhotoColumns();
    }
    if (from < 294) await reportProgress();
    // v295: connected_accounts.nickname (issue #3522). Column only, written
    // when the diver renames an account; re-asserted in beforeOpen through
    // _assertConnectedAccountsSchema.
    if (from < 295) {
      await _assertConnectedAccountsSchema();
    }
    if (from < 295) await reportProgress();
    // v296: media.color_adjustment and diver_settings.auto_color_correction
    // (issue #3520). Re-asserted in beforeOpen. Renumbered from 292,
    // claimed first by #3481.
    if (from < 296) {
      await _assertColorCorrectionColumns();
    }
    if (from < 296) await reportProgress();

    // v297: trip_checklist_sections + trip_checklist_items.section_id,
    // backfilled from category, which is then dropped (issue #3360). Raises
    // minimumCompatibleSchemaVersion to 297 (see database.dart).
    if (from < 297) {
      await _assertAndBackfillTripChecklistSections();
    }
    if (from < 297) await reportProgress();

    // v298: checklist_template_sections + checklist_template_items.section_id,
    // backfilled from category, which is then dropped (issue #3360). Raises
    // minimumCompatibleSchemaVersion to 298 (see database.dart).
    if (from < 298) {
      await _assertAndBackfillChecklistTemplateSections();
    }
    if (from < 298) await reportProgress();

    // v299: pre_dive_checklist_template_sections +
    // pre_dive_checklist_template_items.section_id, backfilled from
    // section (non-built-in templates only; built-ins get stable ids via
    // the seed, re-asserted in beforeOpen), which is then dropped (issue
    // #3360). Raises minimumCompatibleSchemaVersion to 299 (see
    // database.dart).
    if (from < 299) {
      await _assertAndBackfillPreDiveTemplateSections();
    }
    if (from < 299) await reportProgress();

    // v300: pre_dive_session_sections + pre_dive_session_items.section_id,
    // backfilled from section, which is then dropped (issue #3360). Raises
    // minimumCompatibleSchemaVersion to 300 (see database.dart) -- the
    // last of the four checklist-sections table groups.
    if (from < 300) {
      await _assertAndBackfillPreDiveSessionSections();
    }
    if (from < 300) await reportProgress();

    // v301: logbook rules and their run history (issue #3513). Tables
    // only; re-asserted in beforeOpen through _assertRuleSchema.
    // Renumbered from 292, then 296, then 297 as main took each.
    if (from < 301) {
      await _assertRuleSchema();
    }
    if (from < 301) await reportProgress();

    // v302: media_stores.account_id (issue #3482). Column only, no
    // backfill; re-asserted in beforeOpen.
    if (from < 302) await _assertMediaStoresAccountColumn();
    if (from < 302) await reportProgress();

    // v303: media.remote_store_id (issue #3482). Column only, no backfill;
    // re-asserted in beforeOpen.
    if (from < 303) await _assertMediaRemoteStoreColumn();
    if (from < 303) await reportProgress();

    // v304: diver_settings planner Setup-accordion global defaults (issue
    // #3552). Columns only; re-asserted in beforeOpen through
    // _assertPlannerDefaultColumns. Renumbered from 302 as #3482 shipped
    // 302-303 first.
    if (from < 304) {
      await _assertPlannerDefaultColumns();
    }
    if (from < 304) await reportProgress();

    // v305: dive_plans Setup-accordion columns created NOT NULL in the
    // initial schema drop that constraint, so a plan can store "unset,
    // follow Settings" (issue #3552). Table rebuild; re-asserted in
    // beforeOpen through _assertDivePlanSetupFieldsNullable. Review focus:
    // this rewrites dive_plans' stored schema in place - see the helper's
    // doc comment for why it is safe (transactional, additive-only
    // substitution of the targeted NOT NULL clauses). Renumbered from 303.
    if (from < 305) {
      await _assertDivePlanSetupFieldsNullable();
    }
    if (from < 305) await reportProgress();

    // v306: dive_plan_missions battery_reserve_fraction and walk_speed_mps
    // made nullable (issue #3552) - the DPV Team counterpart of v305.
    // Table rebuild; re-asserted in beforeOpen through
    // _assertDivePlanMissionFieldsNullable. Renumbered from 304.
    if (from < 306) {
      await _assertDivePlanMissionFieldsNullable();
    }
    if (from < 306) await reportProgress();

    // v307: diver_settings air-break/turn-pressure defaults and
    // dive_plans.air_breaks_explicitly_off (issue #3552, follow-up to
    // v304-306). Additive columns only, re-asserted in beforeOpen through
    // _assertAirBreaksTurnPressureDefaultColumns. Renumbered from 305.
    if (from < 307) {
      await _assertAirBreaksTurnPressureDefaultColumns();
    }
    if (from < 307) await reportProgress();

    // v308: reserve pressure and gradient factors join the live-resolve
    // group (issue #3552, follow-up to v304-307) - dive_plans columns made
    // nullable (table rebuild), diver_settings gains the reserve-pressure
    // default (gfLow/gfHigh already had one). Re-asserted in beforeOpen
    // through _assertDivePlanReserveAndGfNullable. Renumbered from 306.
    if (from < 308) {
      await _assertDivePlanReserveAndGfNullable();
    }
    if (from < 308) await reportProgress();

    // v309: media and document tags (issue #1970). Column-and-table rung, no
    // backfill: existing tags stay off media and documents. Re-asserted in
    // beforeOpen through _assertMediaAndDocumentTagSchema.
    if (from < 309) {
      await _assertTagScopeColumns();
      await _assertMediaAndDocumentTagSchema();
    }
    if (from < 309) await reportProgress();

    // v310: diver_settings.downloads_follow_computer_owner (issue #2050).
    // Column only, on by default; re-asserted in beforeOpen. Renumbered from
    // 309 as #3605 shipped 309 first.
    if (from < 310) await _assertDownloadOwnerColumn();
    if (from < 310) await reportProgress();

    // v311: the profiles a trip or site is shared with when it is not
    // shared with everyone (issue #2151). Table-only rung, no backfill;
    // re-asserted in beforeOpen. Renumbered from 309 and 310, which #1970
    // and #2050 took.
    if (from < 311) {
      await _assertTripSharesSchema();
      await _assertSiteSharesSchema();
    }
    if (from < 311) await reportProgress();

    // v312: dive_tanks.extra_regulator_ids (issue #3375). Column only, no
    // backfill: a tank's single regulator stays the first. Re-asserted in
    // beforeOpen through _assertTankExtraRegulatorIds. Renumbered from 310
    // and 311 as #3611 and #2151 shipped them first.
    if (from < 312) {
      await _assertTankExtraRegulatorIds();
    }
    if (from < 312) await reportProgress();

    // v313: dive_centers.is_permanently_closed (issue #3379). Column only, no
    // backfill: every existing center stays open. Re-asserted in beforeOpen
    // through _assertDiveCenterClosedColumn. Renumbered from 310 and 312,
    // which #2050 and #3375 took.
    if (from < 313) {
      await _assertDiveCenterClosedColumn();
    }
    if (from < 313) await reportProgress();

    // v314: cylinder_config_items.deco_switch_depth (issue #3567), the MOD
    // set by hand on a saved cylinder. Column only, no backfill;
    // re-asserted in beforeOpen. Renumbered from 304, which #3552 took.
    if (from < 314) await _assertCylinderConfigItemModColumn();
    if (from < 314) await reportProgress();

    // v315: diver_settings.omit_unused_oc_gases (issue #3668). Column only,
    // off by default; re-asserted in beforeOpen.
    if (from < 315) await _assertOmitUnusedOcGasesColumn();
    if (from < 315) await reportProgress();

    // v317: a tank's last visual inspection and last hydro dates become its
    // VIP and hydro clocks' baselines (issue #3662), where the clock has no
    // baseline and no service of its kind. Data only, one time: from here
    // on the equipment save writes them, and sync repeats it for tanks from
    // peers below v317. 316 is held by PR #3685.
    if (from < 317) await backfillTankInspectionBaselines();
    if (from < 317) await reportProgress();

    // v318: the computer tissue snapshot keeps only what has no dive column
    // (issue #2555). Moves the CNS, OTU and deco model stored snapshots
    // held into dives and the primary source where those are empty. New
    // imports no longer write them, and SyncService runs the same move after
    // applying a peer's rows, for a dive an older peer still sends in the
    // old shape. 317 is #3662 (tank inspection baselines); 316 is held by
    // PR #3685.
    if (from < 318) await _moveComputerTissueScalars();
    if (from < 318) await reportProgress();
  }
}
