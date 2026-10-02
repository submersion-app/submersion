/// Service records, kinds and schedules, with their built-in seeds.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';

/// Catalog of service kinds (hydro, VIP, regulator service, ...).
/// Built-ins are reference data: seeded on create/upgrade/open, skipped by
/// sync export, undeletable through the repository. Custom kinds sync.
@DataClassName('ServiceKindRow')
class ServiceKinds extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();

  /// JSON array of EquipmentType names this kind suggests for, e.g. '["tank"]'.
  TextColumn get applicableTypes => text().withDefault(const Constant('[]'))();
  IntColumn get defaultIntervalDays => integer().nullable()();
  IntColumn get defaultIntervalDives => integer().nullable()();
  RealColumn get defaultIntervalHours => real().nullable()();

  /// v202: JSON object of ExposureUnit name to interval for the units that
  /// have no column of their own ({"coldDives": 50}). '{}' means none.
  TextColumn get exposureIntervals =>
      text().withDefault(const Constant('{}'))();

  /// v154: default price for this maintenance, prefilled into a new service
  /// record. Nullable currency means "no opinion, use the diver's default
  /// currency"; a NOT NULL default would make every task silently claim USD.
  RealColumn get defaultCost => real().nullable()();
  TextColumn get defaultCurrency => text().nullable()();

  /// v160: the category prefilled into a new service record logged against
  /// this service type. Nullable because a custom type has no opinion until
  /// the diver gives it one; a NOT NULL default would make every custom type
  /// silently claim "annual".
  TextColumn get defaultCategory => text().nullable()();

  /// Auto-create a schedule when matching equipment is created.
  BoolColumn get autoAttach => boolean().withDefault(const Constant(false))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One service clock per (equipment item, service kind). Next-due is always
/// computed (baseline date, else the newest ServiceRecord of the kind, else
/// purchase and creation dates) -- never stored, so dive logging does not
/// churn sync rows.
@DataClassName('ServiceScheduleRow')
class ServiceSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get serviceKindId =>
      text().references(ServiceKinds, #id, onDelete: KeyAction.cascade)();

  /// Per-item overrides; null = inherit the kind's default interval.
  IntColumn get intervalDays => integer().nullable()();
  IntColumn get intervalDives => integer().nullable()();
  RealColumn get intervalHours => real().nullable()();

  /// v202: per-item overrides for the map units; a key absent here inherits
  /// the kind's map entry.
  TextColumn get exposureIntervals =>
      text().withDefault(const Constant('{}'))();

  /// v154: per-item default price, overriding the kind's. Most specific wins,
  /// so two rebreathers serviced at different shops each keep their own
  /// figure. Null inherits the kind's value.
  RealColumn get defaultCost => real().nullable()();
  TextColumn get defaultCurrency => text().nullable()();

  /// The diver's baseline date: where the clock counts from (e.g. last hydro
  /// before app adoption). It outranks the ServiceRecords of the kind until
  /// one logged after [anchorSetAt] is dated on or after it. Fallback chain
  /// with no baseline: newest record, purchaseDate, then createdAt.
  IntColumn get anchorDate => integer().nullable()();

  /// v213: when the diver set [anchorDate]. Null on every baseline set
  /// before v213 (and on legacy clocks), which keeps the pre-v213 rule for
  /// them: any record of the kind outranks the baseline.
  IntColumn get anchorSetAt => integer().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Equipment service records
class ServiceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// v160: renamed from serviceType. The Drift getter name is also the sync
  /// wire key, so this rename raises minimumCompatibleSchemaVersion; see
  /// SyncDataSerializer._withRenamedKeys for the receiving-side tolerance
  /// that the floor cannot provide.
  TextColumn get serviceCategory =>
      text()(); // annual, repair, inspection, etc.

  /// v122: which service kind this record fulfills (resets that clock).
  /// Plain text (no FK) so records survive custom-kind deletion.
  TextColumn get serviceKindId => text().nullable()();
  IntColumn get serviceDate => integer()();
  TextColumn get provider => text().nullable()(); // Shop or technician name
  RealColumn get cost => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  IntColumn get nextServiceDue => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Built-in service kinds: identical on every device, stable slug ids
/// (service_schedules.service_kind_id references them), INSERT OR IGNORE
/// so re-running is a no-op. Intervals per tech-diving convention.
/// The category each built-in service type prefills, by stable slug id.
///
/// The v160 migration reads this map directly (existing installs).
/// [kSeedBuiltInServiceKindsSql] cannot: it is a const SQL string, so it
/// repeats the same categories as inline literals (fresh installs). The two
/// are held in step by migration_v160_service_category_test.dart, which pins
/// both the slug set and the category each slug is seeded with. Change one
/// and change the other.
const Map<String, String> kBuiltInServiceKindCategories = {
  'hydro': 'inspection',
  'vip': 'inspection',
  'bcd-inspection': 'inspection',
  'o2-clean': 'cleaning',
  'regulator-service': 'annual',
  'rebreather-annual': 'annual',
  'general-service': 'annual',
  'computer-battery': 'replacement',
  'transmitter-battery': 'replacement',
  'scrubber-repack': 'replacement',
  'o2-cell-replacement': 'replacement',
  'drysuit-seals': 'repair',
};

const String kSeedBuiltInServiceKindsSql = '''
  INSERT OR IGNORE INTO service_kinds
    (id, diver_id, name, applicable_types, default_interval_days,
     default_interval_dives, default_interval_hours, auto_attach,
     default_category, exposure_intervals, is_built_in, created_at,
     updated_at)
  SELECT t.id, NULL, t.name, t.types, t.days, t.dives, t.hours, t.auto,
         t.category, t.exposure, 1, n.now_ms, n.now_ms
  FROM (
    SELECT 'hydro' AS id, 'Hydrostatic test' AS name, '["tank"]' AS types,
           1825 AS days, NULL AS dives, NULL AS hours, 1 AS auto,
           'inspection' AS category, '{}' AS exposure
    UNION ALL SELECT 'vip', 'Visual inspection (VIP)', '["tank"]',
           365, NULL, NULL, 1, 'inspection', '{}'
    -- v202: O2 cleaning applies to regulators too now that a cylinder can
    -- name the regulator breathed from it; 50 high-O2 hours is a starting
    -- point, not a manufacturer figure. v239 (issue #2275): both regulator
    -- kinds also name the first and second stages a regulator splits into
    -- (#1487); kBackfillRegulatorPartServiceKindsSql holds the same lists.
    UNION ALL SELECT 'o2-clean', 'O2 clean',
           '["tank","regulator","firstStage","secondStage"]', 365,
           NULL, NULL, 0, 'cleaning', '{"o2Hours":50}'
    UNION ALL SELECT 'regulator-service', 'Regulator service',
           '["regulator","firstStage","secondStage"]', 365, 100, NULL, 1,
           'annual', '{"coldDives":50}'
    UNION ALL SELECT 'computer-battery', 'Computer battery',
           '["computer","battery"]', 730, NULL, NULL, 1, 'replacement', '{}'
    -- v202: 250 h sits below the roughly 300 h published for common
    -- transmitters.
    UNION ALL SELECT 'transmitter-battery', 'Transmitter battery',
           '["transmitter","battery"]', 365, NULL, 250.0, 1, 'replacement',
           '{}'
    UNION ALL SELECT 'bcd-inspection', 'BCD/wing inspection', '["bcd"]',
           365, NULL, NULL, 1, 'inspection', '{}'
    UNION ALL SELECT 'drysuit-seals', 'Drysuit seals', '["drysuit"]',
           730, NULL, NULL, 0, 'repair', '{"saltHours":200}'
    -- A scrubber is consumed by loop time, not by the calendar, so this is
    -- the only built-in with an hours-only clock. 3.0 h is conservative
    -- across the 2-6 h range real units are rated for; the diver overrides
    -- it per unit via ServiceSchedule.intervalHours.
    UNION ALL SELECT 'scrubber-repack', 'Scrubber repack', '["rebreather"]',
           NULL, NULL, 3.0, 1, 'replacement', '{}'
    UNION ALL SELECT 'o2-cell-replacement', 'O2 cell replacement',
           '["rebreather","o2Cell"]', 365, NULL, NULL, 1, 'replacement', '{}'
    UNION ALL SELECT 'rebreather-annual', 'Rebreather annual service',
           '["rebreather"]', 365, NULL, NULL, 1, 'annual', '{}'
    UNION ALL SELECT 'general-service', 'General service', '[]',
           NULL, NULL, NULL, 0, 'annual', '{}'
  ) t
  CROSS JOIN (SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms) n
''';

/// v239 (issue #2275): the built-in regulator service and O2 clean kinds
/// also apply to first and second stages. Issue #1487 split a regulator into
/// part types, but these two kinds still named only `regulator`, so a new
/// second stage could be offered nothing but "General service". A hose is
/// left out: it is inspected or replaced, not serviced.
///
/// One-time, from the v239 rung only (fresh installs get the same lists from
/// [kSeedBuiltInServiceKindsSql]). Gated on is_built_in, so a diver's own
/// kind keeps the types they chose. updated_at is left alone: built-ins are
/// reference data that sync never exports. Held in step with the seed by
/// migration_v239_regulator_part_service_kinds_test.
const String kBackfillRegulatorPartServiceKindsSql = '''
  UPDATE service_kinds SET
    applicable_types = CASE id
      WHEN 'regulator-service'
        THEN '["regulator","firstStage","secondStage"]'
      WHEN 'o2-clean'
        THEN '["tank","regulator","firstStage","secondStage"]'
      ELSE applicable_types END
  WHERE is_built_in = 1 AND id IN ('regulator-service', 'o2-clean')
''';

/// v202: exposure defaults for the built-in kinds on existing installs.
/// Starting points, not manufacturer figures; a schedule overrides them.
/// Held in step with the seed SQL by migration_v202_equipment_condition_test.
const String kBackfillBuiltInExposureDefaultsSql = '''
  UPDATE service_kinds SET
    exposure_intervals = CASE id
      WHEN 'regulator-service' THEN '{"coldDives":50}'
      WHEN 'o2-clean' THEN '{"o2Hours":50}'
      WHEN 'drysuit-seals' THEN '{"saltHours":200}'
      ELSE exposure_intervals END,
    applicable_types = CASE id
      WHEN 'o2-clean' THEN '["tank","regulator"]'
      WHEN 'computer-battery' THEN '["computer","battery"]'
      WHEN 'transmitter-battery' THEN '["transmitter","battery"]'
      WHEN 'o2-cell-replacement' THEN '["rebreather","o2Cell"]'
      ELSE applicable_types END,
    default_interval_hours = CASE id
      WHEN 'transmitter-battery' THEN 250.0
      ELSE default_interval_hours END
  WHERE is_built_in = 1
''';
