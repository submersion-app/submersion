import 'package:drift/drift.dart';

import 'package:submersion/core/database/raw_dive_data_codec.dart';
import 'package:submersion/core/database/tables/app_tables.dart';
import 'package:submersion/core/database/tables/buddy_tables.dart';
import 'package:submersion/core/database/tables/cylinder_tables.dart';
import 'package:submersion/core/database/tables/dive_plan_tables.dart';
import 'package:submersion/core/database/tables/dive_profile_tables.dart';
import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_condition_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/marine_life_tables.dart';
import 'package:submersion/core/database/tables/media_tables.dart';
import 'package:submersion/core/database/tables/pre_dive_tables.dart';
import 'package:submersion/core/database/tables/quality_tables.dart';
import 'package:submersion/core/database/tables/safety_tables.dart';
import 'package:submersion/core/database/tables/service_tables.dart';
import 'package:submersion/core/database/tables/site_tables.dart';
import 'package:submersion/core/database/tables/sync_tables.dart';
import 'package:submersion/core/database/tables/tag_tables.dart';
import 'package:submersion/core/database/tables/track_tables.dart';
import 'package:submersion/core/database/tables/trip_tables.dart';
import 'package:submersion/core/database/tables/weight_tables.dart';
import 'package:submersion/core/database/migrations/app_database_migrations.dart';
import 'package:submersion/core/database/migrations/migration_versions.dart';

export 'package:submersion/core/database/tables/app_tables.dart';
export 'package:submersion/core/database/tables/buddy_tables.dart';
export 'package:submersion/core/database/tables/cylinder_tables.dart';
export 'package:submersion/core/database/tables/dive_plan_tables.dart';
export 'package:submersion/core/database/tables/dive_profile_tables.dart';
export 'package:submersion/core/database/tables/dive_tables.dart';
export 'package:submersion/core/database/tables/diver_tables.dart';
export 'package:submersion/core/database/tables/equipment_condition_tables.dart';
export 'package:submersion/core/database/tables/equipment_tables.dart';
export 'package:submersion/core/database/tables/marine_life_tables.dart';
export 'package:submersion/core/database/tables/media_tables.dart';
export 'package:submersion/core/database/tables/pre_dive_tables.dart';
export 'package:submersion/core/database/tables/quality_tables.dart';
export 'package:submersion/core/database/tables/safety_tables.dart';
export 'package:submersion/core/database/tables/service_tables.dart';
export 'package:submersion/core/database/tables/site_tables.dart';
export 'package:submersion/core/database/tables/sync_tables.dart';
export 'package:submersion/core/database/tables/tag_tables.dart';
export 'package:submersion/core/database/tables/track_tables.dart';
export 'package:submersion/core/database/tables/trip_tables.dart';
export 'package:submersion/core/database/tables/weight_tables.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  final void Function(int currentStep, int totalSteps)? onMigrationProgress;

  AppDatabase(super.e, {this.onMigrationProgress});

  /// The current schema version as a static constant so that pre-open checks
  /// (e.g. version-mismatch guard) can reference it without an instance.
  static const int currentSchemaVersion = 240;

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

  /// Every schema version that has a rung in the upgrade ladder, used to
  /// calculate progress step counts. The list, with a note on what each
  /// version did, is [appMigrationVersions].
  static const List<int> migrationVersions = appMigrationVersions;

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

  // The members below are implemented in the migration library, beside
  // what they read and call. They are declared here as well so that they
  // stay instance members: an extension member is visible only to a file
  // that imports the extension, and a mock cannot stand in for it.

  /// See [SyncMigrations.ensureDeletionLogIndex].
  Future<void> ensureDeletionLogIndex() =>
      SyncMigrations(this).ensureDeletionLogIndex();

  /// See [DiveProfileMigrations.droppedLegacySampleTables].
  bool get droppedLegacySampleTables =>
      DiveProfileMigrations(this).droppedLegacySampleTables;

  /// See [CylinderMigrations.assertCylinderConfigSchemaForTest].
  Future<void> assertCylinderConfigSchemaForTest() =>
      CylinderMigrations(this).assertCylinderConfigSchemaForTest();

  /// See [ServiceMigrations.reconcileLegacyServiceSchedulesForTest].
  Future<void> reconcileLegacyServiceSchedulesForTest() =>
      ServiceMigrations(this).reconcileLegacyServiceSchedulesForTest();

  /// See [DataSourceMigrations.backfillDiveComputerIdsForTest].
  Future<void> backfillDiveComputerIdsForTest() =>
      DataSourceMigrations(this).backfillDiveComputerIdsForTest();

  /// See [DataSourceMigrations.backfillImportedDiveComputersForTest].
  Future<void> backfillImportedDiveComputersForTest() =>
      DataSourceMigrations(this).backfillImportedDiveComputersForTest();

  /// See [DataSourceMigrations.rawBlobsLeftUncompressed].
  int get rawBlobsLeftUncompressed =>
      DataSourceMigrations(this).rawBlobsLeftUncompressed;

  /// See [DataSourceMigrations.recompressedRawBlobs].
  bool get recompressedRawBlobs =>
      DataSourceMigrations(this).recompressedRawBlobs;

  /// See [DataSourceMigrations.hasUnreclaimedPages].
  bool get hasUnreclaimedPages =>
      DataSourceMigrations(this).hasUnreclaimedPages;

  /// See [DataSourceMigrations.unreclaimedPagesReason].
  String get unreclaimedPagesReason =>
      DataSourceMigrations(this).unreclaimedPagesReason;

  /// See [DataSourceMigrations.recompressRawDiveDataForTest].
  Future<void> recompressRawDiveDataForTest() =>
      DataSourceMigrations(this).recompressRawDiveDataForTest();

  /// See [DiveMigrations.clearGeneratedWeatherDescriptionsForTesting].
  Future<void> clearGeneratedWeatherDescriptionsForTesting() =>
      DiveMigrations(this).clearGeneratedWeatherDescriptionsForTesting();

  /// See [DiveProfileMigrations.relinkStrandedTankPressuresForTest].
  Future<void> relinkStrandedTankPressuresForTest() =>
      DiveProfileMigrations(this).relinkStrandedTankPressuresForTest();
}
