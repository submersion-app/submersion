/// Diver profiles and their settings.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

/// Diver profiles (multi-account support)
class Divers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();

  /// Deprecated, superseded by [photo]. Never written for divers; kept so a
  /// database that predates v181 still maps.
  TextColumn get photoPath => text().nullable()();

  /// Profile photo: a 512x512 square JPEG produced by
  /// `lib/core/services/images/profile_photo_codec.dart`. Stored on the row so
  /// it syncs with the diver rather than depending on a device-local path.
  BlobColumn get photo => blob().nullable()();
  // Emergency contact
  TextColumn get emergencyContactName => text().nullable()();
  TextColumn get emergencyContactPhone => text().nullable()();
  TextColumn get emergencyContactRelation => text().nullable()();
  // Medical info
  TextColumn get medicalNotes => text().withDefault(const Constant(''))();
  TextColumn get bloodType => text().nullable()();
  TextColumn get allergies => text().nullable()();
  TextColumn get medications => text().nullable()();
  IntColumn get medicalClearanceExpiryDate =>
      integer().nullable()(); // Unix timestamp
  // Secondary emergency contact
  TextColumn get emergencyContact2Name => text().nullable()();
  TextColumn get emergencyContact2Phone => text().nullable()();
  TextColumn get emergencyContact2Relation => text().nullable()();
  // Insurance
  TextColumn get insuranceProvider => text().nullable()();
  TextColumn get insurancePolicyNumber => text().nullable()();
  IntColumn get insuranceExpiryDate => integer().nullable()(); // Unix timestamp

  /// The insurer's 24-hour dive emergency assistance line, and its general or
  /// office line (issue #1522). Without these the emergency card can only lead
  /// with the regional diver hotline, which is the wrong first call for a
  /// diver insured by anyone else.
  TextColumn get insuranceEmergencyPhone => text().nullable()();
  TextColumn get insurancePhone => text().nullable()();
  // General
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  // Prior dive experience (issue #331): per-diver lifetime offsets for dives
  // logged before the diver started using Submersion. Null = none.
  IntColumn get priorDiveCount => integer().nullable()();
  IntColumn get priorDiveTimeSeconds => integer().nullable()();
  IntColumn get divingSince => integer().nullable()(); // year, e.g. 1990

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-diver settings (v16)
class DiverSettings extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id)();
  // Unit settings
  TextColumn get depthUnit => text().withDefault(const Constant('meters'))();
  TextColumn get temperatureUnit =>
      text().withDefault(const Constant('celsius'))();
  TextColumn get pressureUnit => text().withDefault(const Constant('bar'))();
  TextColumn get volumeUnit => text().withDefault(const Constant('liters'))();
  TextColumn get weightUnit =>
      text().withDefault(const Constant('kilograms'))();
  TextColumn get altitudeUnit => text().withDefault(const Constant('meters'))();

  /// v263: geographic distance unit, a DistanceUnit name (issue #2030).
  /// Backfilled from depth_unit as the column is added.
  TextColumn get distanceUnit =>
      text().withDefault(const Constant('kilometers'))();

  /// v170: renamed from sacUnit. Holds a GasConsumptionDisplay name (sac,
  /// rmv, both). The Drift getter name is also the sync wire key, so this
  /// rename raises minimumCompatibleSchemaVersion; see
  /// SyncDataSerializer._renamedWireKeys for the receiving-side tolerance.
  TextColumn get gasConsumptionDisplay =>
      text().withDefault(const Constant('both'))();

  /// v155: which equation of state converts cylinder pressure to gas volume.
  ///
  /// 'real' reproduces the compressibility-corrected math the app used
  /// unconditionally before the preference existed, so upgrading changes
  /// nobody's numbers; 'ideal' matches hand calculation (issue #828).
  TextColumn get gasModel => text().withDefault(const Constant('real'))();

  /// v193: default water type for a new dive plan (salt, fresh, custom).
  TextColumn get defaultPlannerWaterType =>
      text().withDefault(const Constant('salt'))();
  TextColumn get defaultCurrency => text().withDefault(const Constant('USD'))();

  /// v144: per-diver calibration deciding which measured distances count as
  /// excellent/good/moderate/poor visibility.
  ///
  /// Presentational only -- dives always store the measured distance, so
  /// changing this re-labels a logbook without altering any dive. Defaults to
  /// 'tropical', which reproduces the thresholds hardcoded before v144 so
  /// upgrading re-labels nobody's existing dives.
  TextColumn get visibilityScalePreset =>
      text().withDefault(const Constant('tropical'))();

  /// Custom calibration thresholds in meters, used only when
  /// [visibilityScalePreset] is 'custom'.
  RealColumn get visibilityScaleExcellentM => real().nullable()();
  RealColumn get visibilityScaleGoodM => real().nullable()();
  RealColumn get visibilityScaleModerateM => real().nullable()();

  /// v150: how GPS coordinates are rendered and entered (issue #1041).
  ///
  /// Presentational only -- coordinates are always stored as decimal-degree
  /// doubles, so changing this re-renders every site without altering a
  /// single stored value. Defaults to 'decimalDegrees', which is what the app
  /// showed before v150.
  TextColumn get coordinateFormat =>
      text().withDefault(const Constant('decimalDegrees'))();

  /// v151: seascape terrain appearance (ramp range/banding, contour mode
  /// and custom levels, steep-wall angle) as one JSON blob, per-diver so
  /// it syncs. Nullable ON PURPOSE: null marks a row that predates v151
  /// and has never held a value, which is what lets a device adopt its
  /// legacy device-local pref exactly once (see SettingsNotifier).
  TextColumn get seascapeAppearance => text().nullable()();

  /// v222: per-site manual override of the site terrain's vertical
  /// exaggeration (issue #2141 follow-up), keyed by dive site id, JSON
  /// object of `siteId` to `factor`. Per-diver so it syncs, like
  /// [seascapeAppearance]. Null/missing key means "use the automatic
  /// value" for that site.
  TextColumn get seascapeVerticalExaggerationOverrides => text().nullable()();
  // Time/Date format settings
  TextColumn get timeFormat =>
      text().withDefault(const Constant('twelveHour'))();
  TextColumn get dateFormat => text().withDefault(const Constant('mmmDYYYY'))();
  // Theme
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  TextColumn get themePreset =>
      text().withDefault(const Constant('submersion'))();
  // Color accents (optional per-surface icon tinting; all default off)
  BoolColumn get accentNavIcons =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get accentSectionHeaders =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get accentListIcons =>
      boolean().withDefault(const Constant(false))();
  // Locale (language preference: 'system', 'en', 'es', 'fr', etc.)
  TextColumn get locale => text().withDefault(const Constant('system'))();
  // Language for reverse-geocoded place names, ISO 639-1 (issue #1187, v166)
  TextColumn get placeNameLanguage =>
      text().withDefault(const Constant('en'))();
  // Defaults
  TextColumn get defaultDiveType =>
      text().withDefault(const Constant('recreational'))();
  RealColumn get defaultTankVolume =>
      real().withDefault(const Constant(12.0))();
  IntColumn get defaultStartPressure =>
      integer().withDefault(const Constant(200))();
  TextColumn get defaultTankPreset =>
      text().nullable().withDefault(const Constant('al80'))();
  BoolColumn get applyDefaultTankToImports =>
      boolean().withDefault(const Constant(false))();
  // Decompression settings
  IntColumn get gfLow => integer().withDefault(const Constant(30))();
  IntColumn get gfHigh => integer().withDefault(const Constant(70))();
  RealColumn get ppO2MaxWorking => real().withDefault(const Constant(1.4))();
  RealColumn get ppO2MaxDeco => real().withDefault(const Constant(1.6))();
  // CCR ppO2 limits (v231, issue #2342): the diver's default setpoints and
  // the ppO2 a diluent may reach on a flush, which sets its MOD.
  RealColumn get ccrSetpointLow => real().withDefault(const Constant(0.7))();
  RealColumn get ccrSetpointHigh => real().withDefault(const Constant(1.3))();
  RealColumn get ccrDiluentModPpO2 => real().withDefault(const Constant(1.6))();
  IntColumn get cnsWarningThreshold =>
      integer().withDefault(const Constant(80))();
  RealColumn get ascentRateWarning => real().withDefault(const Constant(9.0))();
  RealColumn get ascentRateCritical =>
      real().withDefault(const Constant(12.0))();
  BoolColumn get showCeilingOnProfile =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showAscentRateColors =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showNdlOnProfile =>
      boolean().withDefault(const Constant(true))();
  RealColumn get lastStopDepth => real().withDefault(const Constant(3.0))();
  RealColumn get decoStopIncrement => real().withDefault(const Constant(3.0))();
  // coverage:ignore-start
  /// Index of AscentGasSet (0 = allCarried). Drives the ideal-gas ascent set.
  IntColumn get ascentGasSet => integer().withDefault(const Constant(0))();
  // coverage:ignore-end
  BoolColumn get o2Narcotic => boolean().withDefault(const Constant(true))();
  RealColumn get endLimit => real().withDefault(const Constant(30.0))();
  BoolColumn get useDiveComputerCnsData =>
      boolean().withDefault(const Constant(false))();
  // The per-metric data sources stay at DEFAULT 1 (calculated) even though a
  // new diver gets computer (#1859): that default lives in AppSettings, which
  // every settings row is written from. Sync fills a key missing from an
  // older peer's payload with this column default and writes it over the
  // local row, so a 0 here would move existing libraries to computer.
  // Applies to the GTR and deco stop sources below too. The ceiling line has
  // no source (#755); its column was dropped in v261 (#767).
  IntColumn get defaultNdlSource => integer().withDefault(const Constant(1))();
  IntColumn get defaultTtsSource => integer().withDefault(const Constant(1))();
  IntColumn get defaultCnsSource => integer().withDefault(const Constant(1))();
  // Gas time remaining on the profile chart (v177). Source is a
  // MetricDataSource index: 0 = computer, 1 = calculated. Reserve is bar.
  IntColumn get defaultGtrSource => integer().withDefault(const Constant(1))();
  RealColumn get gtrReservePressure =>
      real().withDefault(const Constant(50.0))();
  // CNS calculation method: 'classic' | 'shearwater' | 'subsurface' (v113)
  TextColumn get cnsCalculationMethod =>
      text().withDefault(const Constant('shearwater'))();
  // Deco stop band on the profile chart (v133). Source is a MetricDataSource
  // index: 0 = computer, 1 = calculated.
  BoolColumn get showDecoStopsOnProfile =>
      boolean().withDefault(const Constant(true))();
  IntColumn get defaultDecoStopSource =>
      integer().withDefault(const Constant(1))();
  // Post-dive safety review (safety features phase 1, v123)
  BoolColumn get safetyReviewEnabled =>
      boolean().withDefault(const Constant(true))();
  // JSON array of SafetyRuleId.dbValue strings; null/absent = none disabled.
  TextColumn get safetyReviewDisabledRules => text().nullable()();
  // Flying-after-diving conservatism (NoFlyPreset.dbValue, v125).
  TextColumn get noFlyPreset =>
      text().withDefault(const Constant('standard'))();
  // v202: exposure thresholds for service clocks. Stored metric.
  RealColumn get coldWaterThresholdC =>
      real().withDefault(const Constant(10.0))();
  RealColumn get deepDiveThresholdM =>
      real().withDefault(const Constant(30.0))();
  RealColumn get highO2ThresholdPercent =>
      real().withDefault(const Constant(40.0))();
  // v206: condition engine master toggle and the disabled rule ids (JSON
  // list of ConditionRuleId.dbValue); null or absent = none disabled.
  BoolColumn get conditionEngineEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get conditionDisabledRules => text().nullable()();
  // Emergency card (v126): hidden bundled chamber ids (JSON list) and a
  // manual region override (ISO country code).
  TextColumn get hiddenChamberIds => text().nullable()();
  TextColumn get emergencyRegion => text().nullable()();

  /// v227: built-in tank presets the diver hid from the pickers (issue
  /// #2305), JSON list of preset slugs. Null or absent = none hidden.
  TextColumn get hiddenTankPresetIds => text().nullable()();
  // Appearance settings
  BoolColumn get showDepthColoredDiveCards =>
      boolean().withDefault(const Constant(false))();
  // Card coloring settings (v35)
  TextColumn get cardColorAttribute =>
      text().withDefault(const Constant('none'))();
  TextColumn get cardColorGradientPreset =>
      text().withDefault(const Constant('ocean'))();
  IntColumn get cardColorGradientStart => integer().nullable()();
  IntColumn get cardColorGradientEnd => integer().nullable()();
  // Tissue visualization settings
  TextColumn get tissueColorScheme =>
      text().withDefault(const Constant('classic'))();
  TextColumn get tissueVizMode =>
      text().withDefault(const Constant('heatMap'))();
  BoolColumn get showMapBackgroundOnDiveCards =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showMapBackgroundOnSiteCards =>
      boolean().withDefault(const Constant(false))();
  // Dive profile markers
  BoolColumn get showMaxDepthMarker =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showPressureThresholdMarkers =>
      boolean().withDefault(const Constant(false))();
  // Dive list view mode (v51)
  TextColumn get diveListViewMode =>
      text().withDefault(const Constant('detailed'))();

  /// Fold consecutive same-trip dives under a trip header in the dive list
  /// (v204, issue #1193). Off by default: grouping changes the structure of
  /// the list, so existing divers opt in rather than being reorganised.
  BoolColumn get groupTripsInDiveList =>
      boolean().withDefault(const Constant(false))();

  /// Pre-populate every import with a "{source} Import {date}" tag (v211,
  /// issue #998). On by default, matching the wizard's long-standing
  /// behavior; divers who find the tags pile up too fast can turn this off
  /// from the tag management screen. This is only the starting point for a
  /// new import session -- the review step's Import Options sheet lets the
  /// diver override it for that one import without touching this default.
  BoolColumn get autoTagImports =>
      boolean().withDefault(const Constant(true))();
  // List view modes for other features (v52)
  TextColumn get siteListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get tripListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get equipmentListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get buddyListViewMode =>
      text().withDefault(const Constant('detailed'))();
  TextColumn get diveCenterListViewMode =>
      text().withDefault(const Constant('detailed'))();
  // Map style (v67)
  TextColumn get mapStyle =>
      text().withDefault(const Constant('openStreetMap'))();
  // Auto site matching sensitivity (v76): strict | balanced | relaxed
  TextColumn get siteMatchSensitivity =>
      text().withDefault(const Constant('balanced'))();
  // Read cylinder end pressure at surfacing rather than at the end of the
  // recording (v165, issue #1092).
  BoolColumn get trimTankPressureAtSurfacing =>
      boolean().withDefault(const Constant(true))();
  // Dive profile chart defaults
  TextColumn get defaultRightAxisMetric =>
      text().withDefault(const Constant('temperature'))();
  BoolColumn get defaultShowTemperature =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get defaultShowPressure =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get defaultShowHeartRate =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowSac =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowEvents =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get defaultShowPpO2 =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowPpN2 =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowPpHe =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowGasDensity =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowGf =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowSurfaceGf =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowMeanDepth =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowTts =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowGtr =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowCns =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowOtu =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get defaultShowGasSwitchMarkers =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get defaultShowGasTimeline =>
      boolean().withDefault(const Constant(false))();
  // v161: default visibility for the per-cell O2 mV traces (issue #1235).
  BoolColumn get defaultShowO2CellMv =>
      boolean().withDefault(const Constant(false))();
  // v163: whether synthesized ("(est.)") tank pressure lines are drawn on the
  // profile chart at all (issue #731). Defaults to true, preserving the
  // behavior estimates shipped with. Ignored for coverage for the reason
  // given below: the declaration is a codegen input, never executed. Its
  // default is pinned by migration_v163_estimated_tank_pressure_default_test.
  // coverage:ignore-start
  BoolColumn get defaultShowEstimatedTankPressure =>
      boolean().withDefault(const Constant(true))();
  // coverage:ignore-end
  // Drift column declarations are codegen inputs shadowed by the generated
  // table at runtime, so this line is never executed (every sibling column
  // getter is likewise uncovered). The default is verified via the migration
  // and settings tests, not by exercising this declaration.
  // coverage:ignore-start
  BoolColumn get defaultShowAscentRateLine =>
      boolean().withDefault(const Constant(false))();
  // coverage:ignore-end
  // coverage:ignore-start
  BoolColumn get defaultShowPhotoMarkers =>
      boolean().withDefault(const Constant(true))();
  // coverage:ignore-end
  // Notification settings (v26)
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get serviceReminderDays =>
      text().withDefault(const Constant('[7, 14, 30]'))(); // JSON array
  TextColumn get reminderTime =>
      text().withDefault(const Constant('09:00'))(); // HH:mm format
  // v122: days before a trip to nag about gear due before trip end.
  IntColumn get tripServiceLeadDays =>
      integer().withDefault(const Constant(14))();
  // Data source badge visibility (v55)
  BoolColumn get showDataSourceBadges =>
      boolean().withDefault(const Constant(true))();
  // v237: the diver figure in the dive detail equipment card (issue #2326),
  // off by default for every diver.
  BoolColumn get showDiveFigure =>
      boolean().withDefault(const Constant(false))();
  // Dive detail section order and visibility (v56) — JSON array
  TextColumn get diveDetailSections => text().nullable()();
  // Dive detail page layout: detailed | list (v185). A stored "compact",
  // from before that layout was dropped, reads back as detailed.
  TextColumn get diveDetailLayout => text().nullable()();
  // Site detail page card order, visibility and fold state (v218): JSON
  // array in the dive_detail_sections format. Null reads as the defaults.
  TextColumn get siteDetailSections => text().nullable()();
  // Site detail page layout: detailed | list (v218). Null reads as detailed.
  TextColumn get siteDetailLayout => text().nullable()();
  // Table view profile panel default visibility (v61)
  BoolColumn get showProfilePanelInTableView =>
      boolean().withDefault(const Constant(true))();
  // Per-section details pane visibility in table view (v63)
  BoolColumn get showDetailsPaneDives =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneSites =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneBuddies =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneTrips =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneEquipment =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneDiveCenters =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneCertifications =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showDetailsPaneCourses =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
