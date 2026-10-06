import 'package:drift/drift.dart';

import 'package:submersion/core/database/raw_dive_data_codec.dart';
import 'package:submersion/core/database/tables/app_tables.dart';
import 'package:submersion/core/database/tables/buddy_tables.dart';
import 'package:submersion/core/database/tables/certification_currency_tables.dart';
import 'package:submersion/core/database/tables/cylinder_tables.dart';
import 'package:submersion/core/database/tables/dive_plan_tables.dart';
import 'package:submersion/core/database/tables/dive_derived_metrics_tables.dart';
import 'package:submersion/core/database/tables/dive_plan_mission_tables.dart';
import 'package:submersion/core/database/tables/dive_profile_tables.dart';
import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_condition_tables.dart';
import 'package:submersion/core/database/tables/equipment_service_status_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/marine_life_tables.dart';
import 'package:submersion/core/database/tables/media_tables.dart';
import 'package:submersion/core/database/tables/pre_dive_tables.dart';
import 'package:submersion/core/database/tables/quality_tables.dart';
import 'package:submersion/core/database/tables/insight_tables.dart';
import 'package:submersion/core/database/tables/query_tables.dart';
import 'package:submersion/core/database/tables/safety_tables.dart';
import 'package:submersion/core/database/tables/service_tables.dart';
import 'package:submersion/core/database/tables/site_tables.dart';
import 'package:submersion/core/database/tables/sync_tables.dart';
import 'package:submersion/core/database/tables/tag_tables.dart';
import 'package:submersion/core/database/tables/track_tables.dart';
import 'package:submersion/core/database/tables/trip_tables.dart';
import 'package:submersion/core/database/tables/weight_tables.dart';
import 'package:submersion/core/database/migrations/app_database_migrations.dart';

export 'package:submersion/core/database/tables/app_tables.dart';
export 'package:submersion/core/database/tables/buddy_tables.dart';
export 'package:submersion/core/database/tables/certification_currency_tables.dart';
export 'package:submersion/core/database/tables/cylinder_tables.dart';
export 'package:submersion/core/database/tables/dive_plan_tables.dart';
export 'package:submersion/core/database/tables/dive_derived_metrics_tables.dart';
export 'package:submersion/core/database/tables/dive_plan_mission_tables.dart';
export 'package:submersion/core/database/tables/dive_profile_tables.dart';
export 'package:submersion/core/database/tables/dive_tables.dart';
export 'package:submersion/core/database/tables/diver_tables.dart';
export 'package:submersion/core/database/tables/equipment_condition_tables.dart';
export 'package:submersion/core/database/tables/equipment_service_status_tables.dart';
export 'package:submersion/core/database/tables/equipment_tables.dart';
export 'package:submersion/core/database/tables/marine_life_tables.dart';
export 'package:submersion/core/database/tables/media_tables.dart';
export 'package:submersion/core/database/tables/pre_dive_tables.dart';
export 'package:submersion/core/database/tables/quality_tables.dart';
export 'package:submersion/core/database/tables/insight_tables.dart';
export 'package:submersion/core/database/tables/query_tables.dart';
export 'package:submersion/core/database/tables/safety_tables.dart';
export 'package:submersion/core/database/tables/service_tables.dart';
export 'package:submersion/core/database/tables/site_tables.dart';
export 'package:submersion/core/database/tables/sync_tables.dart';
export 'package:submersion/core/database/tables/tag_tables.dart';
export 'package:submersion/core/database/tables/track_tables.dart';
export 'package:submersion/core/database/tables/trip_tables.dart';
export 'package:submersion/core/database/tables/weight_tables.dart';
export 'package:submersion/core/database/migrations/app_database_migrations.dart';

part 'database.g.dart';

// ============================================================================
// Database Class
// ============================================================================

/// Prefix of the deterministic id for a synthesized/backfilled primary data
/// source -- the row a dive gets when it has profile samples but no
/// dive_data_sources row (older file imports). Shared by the beforeOpen
/// backfill (`_backfillMissingDataSources`) and the read-time
/// synthesis ([DiveRepository.getProfilesByDataSource]) so the id a consumer
/// sees before the heal equals the id persisted afterward. Never change it:
/// existing databases already carry rows with this exact prefix.
const String kLegacyDataSourceIdPrefix = 'legacy-src-';

/// Full deterministic data-source id for [diveId]. See
/// [kLegacyDataSourceIdPrefix].
String legacyDataSourceId(String diveId) => '$kLegacyDataSourceIdPrefix$diveId';

@DriftDatabase(
  tables: [
    Divers,
    DiverSettings,
    Trips,
    Dives,
    DiveProfileSeries,
    DiveSites,
    DiveTanks,
    Equipment,
    DiveEquipment,
    DiveWeights,
    DiverWeightEntries,
    DivePlanEquipment,
    EquipmentSets,
    EquipmentSetItems,
    EquipmentSetGeofences,
    QualityFindings,
    EquipmentAttributes,
    EquipmentComponents,
    Species,
    Sightings,
    Media,
    MediaEnrichment,
    MediaSpecies,
    PendingPhotoSuggestions,
    MediaRepairLog,
    MediaSmartAlbums,
    Settings,
    Buddies,
    DiveBuddies,
    Certifications,
    ServiceRecords,
    DiveCenters,
    Tags,
    DiveTags,
    DiveDiveTypes,
    DiveTypes,
    DiveRoles,
    // Custom certification agencies and levels (v261, issue #690)
    CustomCertificationAgencies,
    CustomCertificationLevels,
    TankPresets,
    WeightPresets,
    WeightPresetEntries,
    Transmitters,
    DiveComputers,
    DiveDataSources,
    ImportedFiles,
    DiveProfileEvents,
    DiveSafetyReviews,
    DiveSafetyFindings,
    EmergencyChambers,
    Incidents,
    DiveSensorSummaries,
    // Explore derived metrics (v247, issue #2195), local only
    DiveDerivedMetricsRows,
    EquipmentObservations,
    EquipmentFindings,
    EquipmentConditionReviews,
    GasSwitches,
    TankPressureSeries,
    TideRecords,
    // Site-species junction
    SiteSpecies,
    SiteFeatures,
    // Site classification (v217, issue #1765)
    SiteTypes,
    SiteSiteTypes,
    SiteTags,
    // Equipment tags (v219, issue #1942)
    EquipmentTags,
    // Equipment sharing and its event log (v234, issue #2046)
    EquipmentShares,
    EquipmentOwnershipEvents,
    // Equipment service cache for the query language (v242, issue
    // #2365), local only
    EquipmentServiceStatus,
    // Saved queries (v238, issue #2365)
    SavedQueries,
    // Training courses (v1.5)
    Courses,
    // Course requirement tracker (v121)
    CourseRequirements,
    CourseRequirementDives,
    // Sync tables
    SyncMetadata,
    SyncRecords,
    DeletionLog,
    SyncPeerCursors,
    LocalPublishStates,
    // Maps & Visualization
    CachedRegions,
    // Notifications
    ScheduledNotifications,
    // User-defined custom fields
    DiveCustomFields,
    // Liveaboard tracking (v2.0)
    LiveaboardDetailRecords,
    TripItineraryDays,
    TripDayWeather,
    ChecklistTemplates,
    ChecklistTemplateItems,
    TripChecklistItems,
    // Pre-dive checklists (spec 2026-07-16-pre-dive-checklist)
    PreDiveChecklistTemplates,
    PreDiveChecklistTemplateItems,
    PreDiveSessions,
    PreDiveSessionItems,
    // GPS surface track logging (discussion #289)
    GpsTracks,
    GpsTrackPointsLocal,
    // Measured underwater routes (spec 2026-09-10-underwater-nav-track-design.md,
    // issues #1195 and #1445)
    NavTracks,
    // Saved dive plans (planner redesign Phase 2)
    DivePlans,
    DivePlanTanks,
    DivePlanSegments,
    // DPV mission planner (v244, issue #2086)
    DivePlanMissions,
    DivePlanMissionLegs,
    DivePlanMissionMembers,
    // CSV import presets (local-only)
    CsvPresets,
    // Column view configuration
    ViewConfigs,
    FieldPresets,
    MediaSubscriptions,
    MediaSubscriptionState,
    NetworkCredentialHosts,
    MediaFetchDiagnostics,
    MediaStores,
    ConnectedAccounts,
    ServiceKinds,
    ServiceSchedules,
    CylinderConfigs,
    CylinderConfigItems,
    // Rental gear memory (v221, issue #2075)
    DiveCenterGearNotes,
    // Cylinder fill history (v228, issue #2334)
    CylinderFills,
    // Trip cylinder slots and their ledger (v232, issue #2325)
    TripCylinders,
    TripCylinderEvents,
    // Saved Connections maps (v235, issue #2322)
    ConnectionMaps,
    // Gear packed for a trip (v248, issue #2338)
    TripEquipment,
    // A profile's hidden shared trips and sites (v250, issue #2594)
    TripHides,
    SiteHides,
    // Insight observation dismissals (v265)
    InsightObservationDismissals,
    // Certification currency (v271, issue #2267)
    CertificationCurrencyRules,
    CertificationCurrencyPrefs,
    CertificationCurrencyEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  final void Function(int currentStep, int totalSteps)? onMigrationProgress;

  AppDatabase(super.e, {this.onMigrationProgress});

  /// The current schema version as a static constant so that pre-open checks
  /// (e.g. version-mismatch guard) can reference it without an instance.
  static const int currentSchemaVersion = 271;

  /// The oldest schema whose reader can apply this build's sync payloads
  /// without loss or misinterpretation (the compatibility floor).
  ///
  /// Stamped into every published manifest's `schemaVersion` field, which
  /// shipped readers compare against their own schema to decide whether to
  /// hold a peer (changeset_reader.dart). Keeping the floor low lets older
  /// builds keep syncing across additive schema changes; the receiving-side
  /// overlay merge (issue #474) preserves columns an older peer omits, and
  /// test/core/services/sync/cross_version_roundtrip_test.dart locks that in.
  ///
  /// Raise this to the NEW schema version ONLY when a migration:
  ///  - drops, renames, or retypes an existing synced column,
  ///  - changes the meaning or units of an existing column's values,
  ///  - removes or folds a synced entity (the v147 buddyRoles case),
  ///  - tightens a constraint an old writer's payloads would violate.
  /// Do NOT raise it for new tables or synced entities, new nullable or
  /// defaulted columns, new indexes, dedupe passes, or data repairs that
  /// preserve meaning. When raising it, extend the round-trip test's
  /// projection so the new boundary stays covered.
  ///
  /// Raised 137 -> 160 by the service type unification: v160 renames the
  /// synced column service_records.service_type to service_category, which
  /// the first rule above classifies as breaking. Peers below 160 are held
  /// until they update. Note the gate is one-directional, so this does NOT
  /// protect us from THEIR payloads; SyncDataSerializer._withRenamedKeys
  /// carries the receiving-side tolerance.
  ///
  /// Raised 160 -> 170 by the SAC/RMV split: v170 renames the synced column
  /// diver_settings.sac_unit to gas_consumption_display and replaces its
  /// unit spellings with lane names, which the first two rules classify as
  /// breaking. Peers below 170 are held until they update. Their payloads
  /// still arrive here; _renamedWireKeys plus the value map in
  /// _applyDiverSettingDefaults carry the receiving-side tolerance.
  ///
  /// Raised 170 -> 183 by the packed profile series: v182 replaces the synced
  /// entities diveProfiles and tankPressureProfiles with diveProfileSeries and
  /// tankPressureSeries, which the first rule above classifies as breaking.
  /// Peers below 183 are held until they update. Their payloads still arrive
  /// here; SyncData keeps the two legacy keys inbound-only and
  /// SyncDataSerializer.packLegacySamples packs them into series on apply.
  ///
  /// 183 rather than 182, even though 182 is the rung that made the change:
  /// no released build was ever stamped 182. Shipped devices are at 180, the
  /// 181 rung shipped in PR #1390, and 182 and 183 land in the same release,
  /// so nothing in the fleet is held by 183 that 182 did not already hold.
  /// The extra step records that v183, not v182, is the rung that drops the
  /// legacy tables and purges their `deletion_log` rows. The floor is stamped
  /// on this device's own payloads and only holds readers below it; the gate
  /// is one-directional and does nothing to inbound payloads from an older
  /// peer. See `_purgeLegacySampleBookkeeping` in the migration library for
  /// why those inbound legacy rows stay safe without the purged tombstones.
  ///
  /// Raised 183 -> 210 by the cylinder gear link: v210 lets a gear item a
  /// cylinder is linked to be deleted (dive_tanks.equipment_id now sets null
  /// on delete), so this build publishes equipment tombstones an older
  /// reader cannot apply. Its code deletes the equipment row directly under
  /// the old NO ACTION link, the delete fails, the sync moves past it, and
  /// the item lingers there for good. That is an old reader misapplying our
  /// payload, which is what this floor exists to prevent. Peers below 210
  /// are held until they update. Their own payloads still arrive here, and
  /// a live tank row still pointing at an item deleted here has its link
  /// cleared by [SyncService.parentRefs].
  ///
  /// Raised 210 -> 224 by the media fact clocks: v224 splits a media row's
  /// device-stamped facts (the upload stamps and the verification pair) onto
  /// their own clocks, so this build publishes a media row whose ROW clock
  /// did not move when only its facts changed. An older reader knows nothing
  /// of the fact clocks and applies media as a blind upsert, so it would take
  /// the whole row and overwrite a caption it holds that is newer than ours.
  /// That is an old reader misapplying our payload, which is what this floor
  /// exists to prevent. Peers below 224 are held until they update; their own
  /// payloads still arrive here, and this build's merge reads a missing fact
  /// clock as the row clock, so an old peer's writes still order correctly
  /// (media sync program spec 5.1).
  ///
  /// Raised 224 -> 240 by scoped event tombstones (#1926): this build
  /// replaces the per-row tombstones a split, re-import or re-parse wrote for
  /// a dive's events with one tombstone for the whole set. An older reader
  /// knows nothing of the scope type and stores it as an inert unknown
  /// entity, so the events it names stay on that device for good. That is an
  /// old reader misapplying our payload, which is what this floor exists to
  /// prevent. Peers below 240 are held until they update; their own payloads
  /// still arrive here, and the merge's scope guard keeps their copies of
  /// deleted events from coming back.
  static const int minimumCompatibleSchemaVersion = 240;

  /// Every schema version that has a migration block in onUpgrade.
  /// Used to calculate progress step counts. When adding a new migration,
  /// append the new version number here.
  static const List<int> migrationVersions = [
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    60,
    61,
    62,
    63,
    64,
    65,
    66,
    67,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    77,
    78,
    79,
    80,
    81,
    82,
    83,
    84,
    85,
    86,
    87,
    88,
    89,
    90,
    91,
    92,
    93,
    94,
    95,
    96,
    97,
    98,
    99,
    100,
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112,
    113,
    114,
    // v120 claimed in-worktree for the planner Subsurface-parity columns;
    // 115-119 belong to other branches and interleave at merge time.
    120,
    // v121: course requirement tracker tables (renumbered from v114 at merge
    // time; v114 became the tombstone-GC migration on main).
    121,
    // v122: gear service ledger (renumbered from v115 as main advanced past
    // it; see schema-version ladder).
    122,
    // v123: post-dive safety review tables + diver safety settings columns
    // (renumbered from v115 as main advanced past it at merge time).
    123,
    // v124: equipment type-specific attributes (renumbered from v115/v123 as
    // main advanced past it at merge time; see schema-version ladder).
    124,
    // v125: diver_settings.no_fly_preset column (safety phase 2, no-fly
    // countdown). Renumbered from v117/v124 as main advanced past it at merge
    // time.
    125,
    // v126: emergency_chambers table + emergency card settings columns
    // (renumbered from v118 as main advanced past it at merge time).
    126,
    // v127: incidents table (near-miss log, safety phase 4). Renumbered from
    // v119 as main advanced past it at merge time.
    127,
    // v128: pre-dive checklist tables + built-in template seeds (renumbered
    // from v117/v127 as main advanced past it at merge time).
    128,
    // v129: quality_findings table for the Data Quality Assistant (renumbered
    // from v118 as main advanced past it at merge time).
    129,
    // v130: media_enrichment.hlc so a photo's depth/time association syncs.
    130,
    // v131: reconcile legacy service intervals edited after the v122 backfill
    // into General service clocks (deletion-log guarded).
    131,
    // v132: backfill dives whose bottom_time was wrongly stored equal to
    // runtime by older imports, recomputing it from the primary profile.
    132,
    // v133: deco stop band columns on diver_settings (renumbered from v130 as
    // main advanced past it at merge time).
    133,
    // v134: media compressed-rendition columns (adjustable upload quality
    // Phase A). Renumbered from v130 as main advanced past it at merge time.
    134,
    // v135: color accent toggle columns on diver_settings.
    135,
    136,
    // v137: dives.weather_code, plus a one-time clear of the English weather
    // prose this app generated itself so it can be re-rendered localized.
    137,
    // v138 is reserved by the divelogs.de branch (connected_accounts.diver_id).
    // v139: cylinder_configs + cylinder_config_items (reusable diluent and
    // bailout setups).
    139,
    // v140: media.retain_in_library (Media section Phase 1).
    140,
    // v141: diver_settings.default_currency (default currency for priced
    // items). Renumbered from v138 and then v139 as those went to the
    // divelogs.de branch and the cylinder configs respectively.
    141,
    // v142: trips.return_flight_at (return-flight dive-window countdown).
    142,
    // v143: media_repair_log (per-device) + media_smart_albums (synced),
    // Media section Phase 5. Main reserved this number for PR #894 and
    // continued at v144, so it lands here without renumbering.
    143,
    // v144: dives.visibility_meters plus the diver_settings visibility scale
    // calibration columns (measured visibility replaces the tropical-biased
    // bucket enum).
    144,
    // v145: gps_tracks provenance, label, and non-destructive trim bounds.
    // Renumbered from v144 as main took that step for the visibility scale
    // work at merge time.
    145,
    // v146: recompute machine-derived bottom times that the retired
    // square-profile heuristic collapsed on multilevel dives.
    146,
    // v147: fold buddy_roles (professional credentials, issue #395) into
    // buddy-owned certifications rows and drop the table (spec
    // 2026-08-08-buddy-professional-roles-fold). Originally authored as v145;
    // renumbered when PR #908 reserved 145 and v146 landed first.
    147,
    // v148: site media attachments (issues #211/#627): media(site_id) query
    // index plus the site-side dedupe cleanup and partial unique index
    // mirroring the dive-side v38 pair.
    148,
    // v149: duplicate tags (issue #1032): collapse `tags` rows sharing a
    // (diver scope, case-folded name) and `dive_tags` rows sharing a
    // (dive, tag), then add the two unique indexes that stop them recurring.
    149,
    // v150: diver_settings.coordinate_format (issue #1041): the diver's GPS
    // coordinate notation. Presentational only -- coordinates stay decimal
    // degrees in storage.
    150,
    // v151: diver_settings.seascape_appearance (PR #1073): the seascape
    // terrain appearance knobs as one JSON blob, per-diver so they sync.
    // Nullable so pre-v151 rows can adopt the legacy device-local pref.
    151,
    // v152: site_features (seascape program slice 2): diver-placed
    // annotations on a site, synced LWW.
    152,
    // v153 (issue #810): raw O2 cell output in millivolts on dive_profiles.
    153,
    // v154 (issue #1104): dive_sites.entry_method / exit_method, the site's
    // typical way in and out of the water.
    154,
    // v155 (issue #828): gas model preference on diver_settings, selecting
    // ideal or real gas for every pressure-to-volume conversion. Renumbered
    // from 154, which #1104 claimed first on main.
    155,
    // v156: dive_plan_tanks.is_travel_gas: flags a cylinder as also
    // breathed on the descent, independent of its role, so the lost-gas
    // contingency can cover stage/deco/diluent/pony/etc. cylinders used
    // that way. Renumbered from 155, which #828 claimed first on main.
    156,
    // v157 (issue #829): default service price on service_kinds and
    // service_schedules, prefilled when a maintenance record is logged.
    // Renumbered from 154 and then 156, which #1104, #828 and #1127 claimed
    // first on main.
    157,
    // v158 (issue #1149): owning-source FK on dive_profiles. Renumbered
    // from 154 and then 156, which #1104, #1127 and #829 claimed first
    // on main.
    158,
    // v159 (issue #1177): dive_data_sources.time_offset_seconds, the shift
    // multi-computer consolidation applied to a folded-in source's timeline.
    // Without it a re-parse re-inserts the secondary strand on the raw
    // download's clock and it slides away from the primary's. Renumbered
    // from 158, which #1149 claimed first on main.
    159,
    // v160 (service type unification): service_kinds.default_category, the
    // category prefilled when a maintenance record is logged, plus the
    // service_records.service_type -> service_category rename. Renumbered
    // from 158 and then 159, which #1149 and #1177 claimed first on main.
    160,
    // v161: diver_settings.default_show_o2_cell_mv, a persisted default for
    // the per-cell O2 mV toggle on the profile chart (issue #1235).
    161,
    // v163: diver_settings.default_show_estimated_tank_pressure, the switch
    // that suppresses synthesized "(est.)" tank pressure lines on the profile
    // chart (issue #731). v162 is skipped rather than missing: main was at
    // v161 when that branch was cut, and this branch had already written 162.
    // Two branches writing the same scalar auto-merge with no conflict
    // marker, so #731 took 163 instead and 162 stays permanently unused.
    163,
    // v164: media.manual_elapsed_seconds, the diver's own placement of a
    // media item in the dive when its capture time is wrong (issue #1090).
    // Renumbered from 162, which #731 landed past while this branch was open.
    164,
    // v165: diver_settings.trim_tank_pressure_at_surfacing, which decides
    // whether an import reads cylinder end pressure at the moment of
    // surfacing rather than at the end of the recording (issue #1092).
    // Renumbered from 163, which #731 landed on main while this branch
    // was open. Main reserved this number while the branch was open, so it
    // lands here without renumbering.
    165,
    // v166: diver_settings.place_name_language, the synced language used for
    // reverse-geocoded country/region/town/body of water (issue #1187).
    // Renumbered from 162, which #731 landed past while this branch was open.
    166,
    // v167 is likewise absent: it is claimed by issue #1269 (PR #1276) on a
    // branch that is still open.
    // v168 (issue #638): buddies.is_favorite, so frequently-dived buddies can
    // be pinned to the top of the "Add buddy" picker regardless of sort.
    // Renumbered from 161, which #1235 landed on main while this branch was
    // open.
    168,
    // v170: diver_settings.sac_unit -> gas_consumption_display (a lane
    // choice: sac, rmv, both) plus the rewrite of saved dive-table layouts
    // that named the old sacRate column (discussions #354, #803). 167 and 169
    // are deliberately absent, not missing: 167 is permanently skipped (main
    // landed 168 past it, so PR #1276 moved its rung up), and 169 belongs to
    // PR #1320 (dive-computer gear twins).
    170,
    // v171: trip_day_weather, fetched historical weather for trip days whose
    // dives supply none. Renumbered from 168, which PR #1237 (issue #638,
    // buddies.is_favorite) had already claimed and pushed; that claim was
    // local and unpushed when this branch picked its number, so an open-PR
    // scan could not see it.
    // 165, 167 and 169 are deliberately absent, not missing: 165 is claimed by
    // PR #1290, while 167 and 169 are permanently skipped. main landed past
    // both while their branches were open, so PR #1276 moved to 173 and
    // PR #1320 to 175. This ladder is non-contiguous by design; the audit
    // asserts monotonic, unique, and scalar == max, never contiguous.
    171,
    // v173: dive_types.short_name, an optional diver-set abbreviation for
    // custom dive types (mirrors the fixed built-in abbreviations). Issue
    // #1269 (this PR). Renumbered up from 167, then 171, as main kept
    // landing past this branch's claim while it was open; main's own v171
    // comment above already reserves 173 for this PR, so that's the number
    // landed here directly.
    173,
    // v174: dive_types.show_in_detail_header and dive_types.show_in_list_view,
    // per-type toggles for which badge rows a diver's types appear in.
    // Issue #1269 follow-up.
    174,
    // v175 (gear twins): dive_computers.equipment_id, the equipment row that
    // represents a registered computer as gear, so a downloaded dive lists the
    // computer that logged it alongside the rest of the diver's kit. Issue
    // #1320. Renumbered from 169: main reserved 169 for this branch but landed
    // 170 past it, and a rung below the shipped version never runs its
    // onUpgrade step, so the gear-twin backfill would silently never execute.
    // 171, 173 and 174 then landed as well (trip_day_weather and the two
    // dive_types columns above), so this takes 175, which main's own v171
    // comment already reserves for it. 169 is now permanently skipped, as are
    // 162 and 167.
    175,
    // v177: GTR settings on diver_settings and the dive_profiles.rbt
    // minutes-to-seconds repair.
    177,
    // v178: one dive_dive_types row per (dive, type), collapsing the
    // duplicates the unguarded v92 seed minted on every device and the sync
    // merge then unioned by row id. Issue #1360. (That comment originally
    // recorded PR #1328 as holding 176; #1328 has since moved to 179, the
    // rung below.)
    178,
    // v179: dives.site_suggestion_dismissed_at, the synced per-dive dismissal
    // of the photo / dive-computer site suggestion. Renumbered twice while
    // this branch was open -- from 172 when main landed 173-175, then from
    // 176 when main landed 177 (GTR) -- because a rung below the shipped
    // version never runs its onUpgrade step: a database already at the
    // shipped version gains the column only through the beforeOpen backstop.
    // 178 shipped with the dive-type uniqueness work while this branch was
    // open, so this sits above it. 162, 167, 169 and 176 are skipped; the
    // ladder is non-contiguous by design.
    179,
    // v180 (statistics exclusion): dives.excluded_from_stats and
    // dives.excluded_from_gas_stats, letting a diver keep a dive in the
    // logbook while removing it from statistics. Issues #526 and #1272.
    // Renumbered from 178: main landed 178 (dive-type uniqueness) and 179
    // (site-suggestion dismissal) while this branch was open, and a rung
    // at or below the shipped version never runs its onUpgrade step.
    // Column-only rung with no backfill, so the beforeOpen backstop is
    // safe to re-run.
    180,
    // v181: divers.photo and buddies.photo, the profile photo blobs. Claimed
    // against origin/main at 180, having been renumbered from 180 when PR
    // #1374 (statistics exclusion) landed and took that rung while this
    // branch held only its design docs. A rung at or below the shipped
    // version merges with no conflict marker and its onUpgrade step then
    // never runs, so re-verify this number if this branch sits open while
    // main advances again.
    181,
    // v182 (packed profile series, spec 2026-08-28-profile-sample-storage):
    // dive_profile_series and tank_pressure_series, one zlib columnar blob
    // per (dive, computer, source, is_primary) group and per (dive, tank,
    // computer) group, packed from the row-per-sample tables by
    // packLegacyProfileRows with ids derived from the identity tuple so every
    // device converges (the #1360 lesson). The legacy tables stay until the
    // consumers move; the same PR retires them in a later plan. 176 remains
    // skipped; the ladder is non-contiguous by design. Numbered 182 because
    // PR #1390 (profile photos) took 181.
    182,
    // v183 (packed profile series, plan 2e): drop the row-per-sample
    // dive_profiles and tank_pressure_profiles tables and purge the sync
    // bookkeeping that named them. Every reader moved to the series tables
    // in plans 2b to 2d, so the rows have no consumer left. The rung packs
    // once more before it drops, because a device that reached 182 through
    // a parallel branch's rung never ran ours and the beforeOpen backstop
    // only runs AFTER onUpgrade: by then the rows would be gone.
    183,
    // v184 (issue #1451): dive_data_sources.merge_source_slot, the marker a
    // sequential Combine stamps on the provenance rows it carries so the
    // display can collapse the halves of one dive back into one source.
    // Backfilled for dives combined before this rung shipped.
    184,
    // v185 (issue #1476): diver_settings.dive_detail_layout, the dive detail
    // page's layout choice. Column-only rung, no backfill: a null reads back
    // as the detailed layout, which is what every existing diver was already
    // getting. Numbered 185 because PR #1451 took 184 while this branch was
    // open; the column is nullable and additive either way, so the
    // compatibility floor stays at 183.
    185,
    // v186: pre_dive_checklist_template_items.equipment_id, the remembered
    // single-equipment link for an 'equipment'-typed template item. Chosen
    // at session start (not in the template editor), mirroring the
    // equipmentSet flow. Issue #814. Column-only rung, no backfill, so the
    // beforeOpen backstop is safe to re-run. Renumbered from 181: main
    // landed 181 through 185 while this branch was open, and a rung at or
    // below the shipped version never runs its onUpgrade step.
    186,
    // v187: pre_dive_session_items.overdue_services, the frozen snapshot of
    // overdue-service entries for a resolved checklist item (issue #814
    // phase 2). Column-only rung, no backfill: every pre-existing row
    // correctly reads back as null (no frozen snapshot), which the UI
    // already treats as "nothing known" for a resolved legacy row.
    // Renumbered from 182 for the same reason as 186 above.
    187,
    // v188: divers.insurance_emergency_phone and divers.insurance_phone, the
    // insurer's 24h assistance line and office line (issue #1522). Column-only
    // rung, no backfill: nothing in an existing database can tell us an
    // insurer's hotline, so every pre-existing row correctly reads back as
    // "not recorded" and the card keeps leading with the regional hotline.
    188,
    // v189: media.equipment_id plus idx_media_equipment_id (issue #1517).
    // The link that files an invoice, receipt or warranty document against a
    // piece of gear. Column-and-index rung, no backfill, so the beforeOpen
    // backstop is safe to re-run. Renumbered from 188: main took that step
    // for the insurance phone columns while this branch was open, and a rung
    // at or below the shipped version never runs its onUpgrade step.
    189,
    // v190: recompress dive_data_sources.raw_data in place (issue #227).
    // No DDL; the column's SQL type is unchanged and only the stored bytes
    // move. Guarded per row: the self-describing header means a row this
    // rung skips keeps reading correctly forever, so a blob left
    // uncompressed costs space and nothing else. Numbered 190 because main
    // took 188 and 189 while this branch was open.
    190,
    // v191: per-band planner ascent rates (9/6/3/1 m/min TDI phases).
    // Renumbered from 188, which was itself renumbered from 185 and 184:
    // main landed the insurance-phone, media-equipment-link and raw-data
    // recompression rungs (188-190) while this branch was open, and a rung
    // at or below the shipped version never runs its onUpgrade step.
    191,
    194,
    // v195: media_species.hlc, so a species tag on a photo publishes in an
    // incremental changeset instead of waiting for a full base publish
    // (issue #1638). Additive nullable column; the one-time stamp of the
    // rows already on disk is SyncRepository.backfillMissingHlc, which runs
    // at the start of every sync. Renumbered from 192: main landed the
    // transmitter-serial rung at 194 while this branch was open, 192 and 193
    // are held by other open branches, and a rung at or below the shipped
    // version never runs its onUpgrade step.
    195,
    // v196: weight_presets + weight_preset_entries (issue #1609). Renumbered
    // from 192 then 195 -- main also landed the media-species-clock rung (195)
    // while this branch was open (192 and 193 are held by other branches).
    196,
    // v197: dive_plans.salinity_ppt, custom planner water salinity for deco.
    // Renumbered from 192: main landed the transmitter-serial, media-species
    // clock and weight-preset rungs (194 through 196) while this branch was
    // open, and a rung at or below the shipped version never runs its
    // onUpgrade step.
    197,
    // v198: diver_settings.default_planner_water_type (salt/fresh/custom).
    // Renumbered from 193 for the same reason as 197.
    198,
    // v199: certifications.additional_credentials -- extra (agency, level)
    // pairs the same physical card grants (e.g. an FFESSM N1 that is also a
    // CMAS 1-star). Additive nullable TEXT (a JSON array); no backfill, a
    // null reads back as "just the primary agency/level". Renumbered from
    // 197: main landed the planner salinity and water-type rungs (197, 198)
    // while this branch was open.
    199,
    // v200: transmitters registry table (issue #1365) and
    // dive_tanks.source_tank_index (issue #1314).
    200,
    // v201: the O2 cell linearity link (issue #986). Took 201 rather than
    // 200 because #1365 held 200 on its own branch while this one was open;
    // #1365 has since landed, so the two sit in order.
    201,
    202,
    // 203: equipment assemblies (issue #1487). Renumbered from 202, which
    // condition intelligence took while this branch was open.
    203,
    // v204: diver_settings.group_trips_in_dive_list -- inline collapsible
    // trip groups in the dive list (issue #1193). Additive defaulted boolean,
    // no backfill. Renumbered from 202 and then 201: the linearity link,
    // condition intelligence and assemblies all landed while this branch was
    // open, and a rung at or below the shipped version never runs its
    // onUpgrade step.
    204,
    // 206: condition engine toggles on diver_settings (condition phase 3b).
    // 205 is unused. v207 shipped in 1.7.8 while this branch was open, so
    // a device already at 207 skips this step; the beforeOpen backstop
    // adds the columns there instead.
    206,
    // v207: an updated_at on the three composite-natural-key gear junctions
    // (issue #1728). 204 landed on main while this branch was open and 205
    // and 206 are claimed by the condition-intelligence branches, so this
    // rung takes 207; the list only counts remaining steps for progress
    // reporting and is non-contiguous by design.
    207,
    // v208 (issue #478): the imported_files table plus
    // dive_data_sources.imported_file_id, the original logbook file a
    // file-imported dive can be re-parsed from. Table-and-column rung, no
    // backfill, so the beforeOpen backstop is safe to re-run. Renumbered from
    // 185: main landed 185 through 207 while this branch was open, and a rung
    // at or below the shipped version never runs its onUpgrade step.
    208,
    // v210: dive_tanks.equipment_id ON DELETE SET NULL. The link was NO
    // ACTION from the initial schema, so deleting a gear item a cylinder
    // was linked to failed. Rebuilds the table from its stored definition.
    // Also an hlc column on the 19 child tables exported through their
    // parent, so a stale copy from a peer cannot overwrite a newer edit.
    210,
    // v211: diver_settings.auto_tag_imports (issue #998). Additive defaulted
    // boolean, no backfill. Renumbered from 208: main's own v208 (issue
    // #478) and v210 (#1769) landed while this branch was open, and a rung
    // at or below the shipped version never runs its onUpgrade step.
    211,
    // v213: service_schedules.anchor_set_at, so a baseline date the diver
    // sets outranks the service records logged before it. Column-only, no
    // backfill.
    213,
    // v214: dive_plans.stop_minimums_json (replan-this-dive minimum stop
    // durations). Additive nullable column, no backfill. Renumbered from 201,
    // then 209, then 211: main shipped 211 and 213 while this branch was open,
    // and a rung at or below the shipped version never runs its onUpgrade
    // step. The 212 main reserved for this branch is below 213 and so is dead
    // for the same reason.
    214,
    // v215: dive_plans gas-options columns (sac_factor, problem_solving_
    // minutes, pp_o2_bottom, pp_o2_deco, best_mix_end_meters, o2_narcotic).
    // Renumbered from 202, then 212, for the same collisions; stop-minimums
    // took 214.
    215,
    // v217: dive site types and tags (issue #1765). Three new tables
    // (site_types, site_site_types, site_tags), the built-in site type seed,
    // both junction unique indexes, and tags.applies_to_dives /
    // applies_to_sites. Additive only, so the compatibility floor stays.
    // Renumbered from 212, then 214: main shipped 213, 214 and 215 while
    // this branch was open, and 216 is claimed by the site detail sections
    // work.
    217,
    // v218: diver_settings.site_detail_sections and site_detail_layout, the
    // Site Details page's card order, visibility, fold state and layout
    // (issue #1884). Additive nullable columns, no backfill. Takes 218, not
    // 216: open PR #1860 holds 216 (metric-source defaults) and 217 (site
    // types and tags) shipped first, and a rung at or below the shipped
    // version never runs its onUpgrade step, so this one sits above both.
    218,
    // v219: equipment tags (issue #1942). tags.applies_to_equipment (off for
    // every existing tag) and the equipment_tags junction with its
    // (equipment_id, tag_id) unique index. Additive only, so the
    // compatibility floor stays.
    219,
    // v220: equipment_sets.auto_apply_on_computer_import (issue #1020).
    // Additive column, default off. Renumbered from 219: #1964 (equipment
    // tags) shipped first and claimed it.
    220,
    // v221: rental gear memory (issue #2075). dive_center_gear_notes, a
    // child of dive_centers. Table-only rung, no backfill, so the
    // compatibility floor stays. Sits above v220 (#1980), which shipped
    // while this was in review.
    221,
    // v222: diver_settings.seascape_vertical_exaggeration_overrides (issue
    // #2141 follow-up). Additive column, default null. Compatibility floor
    // stays: an older reader simply never sees the per-site overrides.
    222,
    // v223: buddies.linked_diver_id (a buddy that IS a local profile) and
    // dives.outing_id (sibling dives mirrored from one save), issue #2002.
    // Additive nullable columns, no backfill, so the floor stays at 210.
    // Renumbered four times: equipment tags took 219, the computer-set
    // auto-apply column took 220, rental gear memory took 221 and the
    // per-site vertical exaggeration overrides took 222 while this branch
    // was open, and a rung at or below the shipped version never runs.
    223,
    // v224: media.upload_facts_hlc and verify_facts_hlc, the two fact
    // clocks (media sync program spec 5.1). Columns plus a backfill from
    // the row clock, and the one rung on this ladder that DOES move the
    // compatibility floor: a reader without them cannot order fact writes.
    // Renumbered from 223, which buddy profile links took while this was
    // in review.
    224,
    // v226: media.cloud_asset_id, the PhotoKit cloud identifier (media sync
    // program spec 6.2). Column only; the one-time backfill runs after a
    // sync, not here. Additive and nullable, so the floor stays at 224.
    // 225 is held by PR #1978 (tissue loading import).
    226,
    // v227: diver_settings.hidden_tank_preset_ids (issue #2305). Additive
    // nullable column, no backfill. The floor stays: an older reader simply
    // shows every built-in preset. Renumbered from 225, which is held by PR
    // #1978, after v226 landed while this was in review.
    227,
    // v228: cylinder_fills, the fill history keyed by passport id (issue
    // #2334). Table-only rung, no backfill, floor stays at 224. Renumbered
    // from 227, which hidden tank presets (#2305) took while this was in
    // review.
    228,
    // v229: equipment_sets.show_figure, the per-set diver figure switch
    // (issue #2326). Additive, default off, no backfill, so the floor stays.
    // Kept below v230, which main shipped first with 229 reserved for this
    // rung: a database already at 230 skips this step, and the beforeOpen
    // backstop adds the column there.
    229,
    // v230: nav_tracks -- measured underwater routes from Seacraft ENC
    // navigation consoles and similar IMU-equipped computers (issues #1195,
    // #1445). Table-only rung, additive, so the floor stays at 224.
    // Renumbered from 209, then 228: main shipped cylinder fills (#2364) as
    // 228 while this branch was open, and 229 is claimed by the diver
    // figure branch (#2372). A rung at or below the shipped version never
    // runs its onUpgrade step.
    230,
    // v231: diver_settings CCR ppO2 limits (issue #2342): setpoint low,
    // setpoint high and the diluent's flush ppO2. Additive defaulted
    // columns, no backfill, so the floor stays at 224. Renumbered from 228,
    // then 230: main shipped cylinder fills (#2364) as 228 and nav tracks
    // (#1772) as 230 while this was open, and 229 is claimed by #2372,
    // #2331 and #2407.
    231,
    // v232: trip-scale gas logistics, phase 1 (issue #2325). trip_cylinders
    // and trip_cylinder_events, two children of trips, and the nullable
    // dive_tanks.trip_cylinder_id link. Tables and one column, no backfill,
    // so the floor stays at 224. Renumbered from 228 while in review: main
    // shipped cylinder fills (#2364) as 228, nav tracks (#1772) as 230 and
    // CCR ppO2 limits (#2387) as 231, and 229 is held by #2372.
    232,
    // v233: dive_data_sources.source_diver_key (issue #1921), so a resync
    // replays the importing diver's copy of a shared MacDive dive. Additive
    // nullable column, no backfill (only a re-parse of each stored file
    // could recover it), so the floor stays at 224. Taken while 232 was
    // claimed by several open branches; trip cylinders (#2331) shipped it.
    233,
    // v234: equipment sharing (issue #2046). Two tables, equipment_shares
    // with its (equipment_id, diver_id) unique index and
    // equipment_ownership_events, plus two lookup indexes. Additive only, so
    // the compatibility floor stays. Renumbered from 228, 229, 232 and 233:
    // cylinder fills (#2364) took 228, 229 is claimed by the diver figure
    // branch (#2372), nav tracks (#1772) took 230, CCR ppO2 limits (#2342)
    // took 231, trip cylinders (#2325) took 232 and the dive source diver
    // key (#1921) took 233 while this was open.
    234,
    // v235: connection_maps, saved Connections maps per diver, plus the
    // idx_sightings_dive_id index the species maps join on (issue #2322).
    // Table-and-index rung, no backfill, so it does not move the floor.
    // Renumbered from 232 and 234: trip cylinders (#2331) shipped 232, the
    // MacDive source diver key (#1921) 233 and equipment sharing (#2046) 234.
    235,
    // v237: diver_settings.show_dive_figure, the diver-wide switch for the
    // figure in the dive detail equipment card (issue #2326). Additive,
    // default off, no backfill, so the floor it needs stays at 224. Taken
    // above 235 and 236, which open branches claimed when this was cut,
    // and kept below v239, which main shipped first: a database already
    // past it skips this step, and the beforeOpen backstop adds the column.
    237,
    // v238: saved_queries, a diver's named query trees (issue #2365, spec
    // Unit 7). Table-only rung, additive, floor stays at 224. Renumbered
    // from 234 when equipment sharing (#2411) shipped it. Kept below
    // v239, which main shipped with 238 left for this rung: a database
    // already at 239 skips this step, and the beforeOpen backstop creates
    // the table there.
    238,
    // v239: the built-in regulator service and O2 clean kinds also apply to
    // first and second stages (issue #2275). A one-time UPDATE of two
    // built-in rows, which sync never exports, so the floor stays. 235 to
    // 238 were claimed by open branches when this was taken.
    239,
    // v240: idx_dive_profile_events_dive_id for scoped event tombstones
    // (#1926), which delete and match events by dive; also raises the floor
    // to 240. Renumbered from 233 and then 235: main shipped 233 (#1921),
    // 234 (#2046) and 239 (#2275) while this was open.
    240,
    // v241: tank_pressure_series.source_id (issue #2440), backfilled where
    // the source is unambiguous. Additive nullable column, so the floor
    // stays at 240. Renumbered from 232 and then 240 while in review: main
    // shipped 232 to 234, 239 (#2275) and 240 (#1926) while this was open.
    // Kept below v242, which main shipped with 241 left for this rung: a
    // database already at 242 skips this step, the beforeOpen backstop
    // adds the column there, and its series stay unattributed, which every
    // reader already handles.
    241,
    // v242: equipment_service_status, the local service-due cache the
    // query language's serviceDue field reads (issue #2365, PR 3). A table
    // with no hlc, never synced, so the floor does not move. 241 was held
    // by #2493 when this was taken.
    242,
    // v244: DPV mission planner (issue #2086). dive_plan_missions,
    // dive_plan_mission_legs and dive_plan_mission_members, children of
    // dive_plans. Table-only rung, no backfill; an older reader keeps the
    // new entity types as inert unknowns, so the floor stays at 240.
    // Renumbered from 241: #2493 took it, main shipped 242 (#2541) and
    // an open branch claims 243 (#2409).
    244,
    // v245: idx_certifications_buddy_id (issue #2365, PR 4). Index-only;
    // the floor does not move. 243 was held by #2409 and 244 went to
    // #2086 when this was taken.
    245,
    // v247: dive_derived_metrics, the Explore derived metrics the dive query
    // fields read (issue #2195, phase 2). A table with no hlc, never synced,
    // so the floor does not move. 246 is held by #2409 (open).
    247,
    // v248: trip_equipment, gear packed for a trip (issue #2338).
    // Table-only rung, no backfill; the floor does not move. 246 is held by
    // #2409 and 247 went to #2195 (Explore derived metrics).
    248,
    // v249: the trip fill forecast's inputs (issue #2325, PR 4): trips
    // divers sharing and dives per day, itinerary planned dives, dive
    // center fill hours. Additive columns, so the floor does not move. 248
    // is trip_equipment (#2338).
    249,
    // v250: trip_hides and site_hides, the shared trips and sites a profile
    // has hidden from itself (issue #2594). Table-only rung, no backfill;
    // an older peer keeps the new entity types as inert unknowns, so the
    // floor does not move. #2562 and #2409 held stale claims below 249
    // when this was taken.
    250,
    // v251: dive_tanks.source_id (issue #2716), the data source a tank row
    // came from, so two computer-less sources' copies of one cylinder come
    // apart; backfilled where unambiguous. Additive nullable column, so the
    // floor stays at 240. 250 is trip_hides and site_hides (#2594).
    251,
    // v252: nav_tracks.diver_id, the route's owner, backfilled from each
    // linked route's dive (issue #2691 follow-up). Additive nullable column,
    // so the floor does not move. 251 is dive_tanks.source_id (#2716).
    252,
    // v253: dive_safety_reviews.inputs_hash, the settings a review was
    // computed from (issue #2592). An additive nullable column, so the floor
    // does not move: the receiving overlay keeps it when an older peer's
    // payload omits it. Merged after v254 (#2595): a database already at 254
    // never runs this rung, and the beforeOpen backstop adds the column.
    253,
    // v254: dive_tanks.role_source, where a cylinder's role came from
    // (issue #2595). An additive nullable column, so the floor does not
    // move. 251 is dive_tanks.source_id (#2716) and 252
    // nav_tracks.diver_id (#2703); 253 is
    // dive_safety_reviews.inputs_hash (#2592).
    254,
    // v255: drops the ceilings safety stop samples carried from every
    // stored profile series (issue #2550): a safety stop is no deco
    // obligation, and its depth drew a deco stop band. Rewrites blobs in
    // place without moving their sync stamp; an older peer's copy still
    // reads as a safety stop, so the floor does not move. 254 is
    // dive_tanks.role_source (#2595), 253 safety review inputs (#2592).
    255,
    // v256: dives.computer_tissue_json, the tissue state a dive computer
    // reports for the dive (import of Garmin, Shearwater, Suunto, Ratio and
    // UDDF tissue data, issue #1977). Additive nullable column, no
    // backfill, so the floor stays. Renumbered from 220 and then 241: main
    // shipped 220 to 255 while this was open.
    256,
    // v257: metadata-only profile revision history over existing
    // dive_profile_series rows (#1197). No profile samples are copied:
    // history rows point at existing series ids and track parent/branch
    // relations. Local-only table, so the floor stays. Renumbered from 246
    // and then 256: main shipped 247 through 256 while this branch was open.
    257,
    // v258: gas_switches.computer_id, the computer whose reading a switch
    // came from (issue #2582), backfilled from the switch's cylinder.
    // Additive nullable column, so the floor stays. Sits below 259, which
    // main shipped first; a database already at 259 gains the column and
    // its backfill through the beforeOpen backstop.
    258,
    // v259: dive_tanks.usage_duration, how long a cylinder was breathed as
    // the source log recorded it (issue #1496). An additive nullable
    // column, so the floor does not move: an older peer's payload omits it
    // and the row keeps null. 258 is held by an open branch (#2828).
    259,
    // v260: dive_tanks.shared_computer_ids, the other computers on a
    // consolidated dive that logged the same cylinder, so each computer is
    // analysed on its own gas plan (issue #2560). Additive nullable column
    // plus a local, deterministic backfill, so the floor stays. Renumbered
    // from 241, 248, 250 and 251 while this was open; gas_switches.computer_id,
    // which the analysis also reads, is v258 (#2582).
    260,
    // v261: drops diver_settings.default_ceiling_source (issue #767), unread
    // since the ceiling line lost its source toggle at v137 (#755). Dropping
    // a synced column normally raises the floor, but every reader the floor
    // admits (240 and up) ignores the value and fills a missing key from its
    // column default, so nothing it applies is lost or misread and the floor
    // stays. Inbound, the generated fromJson ignores the legacy key.
    261,
    // v262: diver_settings certification/course list view modes and the
    // formerly device-local profile "metrics follow viewport" and pSCR
    // ratio (issue #2948). Additive columns, so the floor stays.
    262,
    263,
    // v264: diver_settings.default_show_late_gas_switches (issue #2939).
    // Additive column with a default, so the floor stays.
    264,
    // v265: insight_observation_dismissals (synced) and
    // diver_settings.insights_muted_observation_rules (#2381). Additive, so
    // the floor stays. Renumbered several times while this was open (262 is
    // held by #2991; 261, 263 and 264 landed first).
    265,
    // v266: media.site_category and media.display_size, a site attachment's
    // category and size override (issue #1039). Additive nullable columns,
    // so the floor stays. Renumbered from 263, which main shipped first
    // (#2030); 262 is claimed by an open branch.
    266,
    // v267: custom certification agencies and levels (issue #690). Two new
    // synced tables and an index, no data migration, so the floor stays.
    // Renumbered from 265 and 266, which main shipped first.
    267,
    // v269: diver_settings.hidden_built_in_ids, the built-in dive types,
    // roles, site types, service types and pre-dive templates each diver hid
    // from the pickers (issue #401). Additive nullable column, no backfill,
    // so the floor stays. Renumbered several times while this was open; 268
    // is held by an open branch (#3043).
    269,
    // v270: dive_weights.label and weight_preset_entries.label, a diver's own
    // name for a weight (issue #956). Additive defaulted columns, so the
    // floor stays: an older peer's payload omits the key and the row keeps
    // its local value or the '' default. Renumbered as other rungs shipped
    // first (261 through 269); 268 is held by an open branch (#3043).
    270,
    // v271: certification currency (issue #2267): the rule catalog with its
    // built-in seed, per certification overrides and the event ledger. New
    // synced tables only, so the floor stays. Built-in rules are reference
    // data, re-seeded by INSERT OR IGNORE from onCreate, the rung and
    // beforeOpen. Renumbered from 261, 262, 266, 267 and 269 as main shipped
    // those first (and then 270); 268 is held by an open branch.
    271,
  ];

  /// Returns the number of migration steps that will execute when upgrading
  /// from [fromVersion] to [currentSchemaVersion].
  static int migrationStepCount(int fromVersion) {
    return migrationVersions.where((v) => v > fromVersion).length;
  }

  @override
  int get schemaVersion => currentSchemaVersion;

  /// The upgrade ladder, the helpers its rungs call and the backstops
  /// that run on every open live in `migrations/`, outside this library.
  /// drift_dev resolves all of this library while it generates code, so
  /// what is declared here is paid for on every build (issue #2502).
  @override
  MigrationStrategy get migration => buildMigrationStrategy();
}
