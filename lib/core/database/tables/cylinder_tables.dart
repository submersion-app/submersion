/// Cylinder configurations, tank presets, transmitters and fills.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_profile_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';

/// A named, reusable set of cylinders. equipment_id set means "a config for
/// this rebreather"; null means a generic gas plan usable on any dive.
/// ON DELETE SET NULL demotes a config when its unit is deleted rather than
/// destroying a painstakingly entered bailout plan.
class CylinderConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One cylinder in a configuration. The spec columns are a SNAPSHOT: a tank
/// preset may populate them at edit time, but there is deliberately no FK to
/// tank_presets. A config records what the diver actually dives, so a later
/// edit to a preset must not rewrite the meaning of a saved config.
class CylinderConfigItems extends Table {
  TextColumn get id => text()();
  TextColumn get configId =>
      text().references(CylinderConfigs, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get label => text().nullable()();
  TextColumn get tankRole => text()(); // TankRole.name
  RealColumn get volumeL => real().nullable()();
  RealColumn get workingPressureBar => real().nullable()();
  TextColumn get tankMaterial => text().nullable()(); // TankMaterial.name
  RealColumn get o2Percent => real().withDefault(const Constant(21.0))();
  RealColumn get hePercent => real().withDefault(const Constant(0.0))();
  RealColumn get defaultStartPressureBar => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Custom tank presets (user-defined tank configurations)
class TankPresets extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id)(); // Owner of preset
  TextColumn get name => text()(); // Internal name/identifier
  TextColumn get displayName => text()(); // User-friendly display name
  RealColumn get volumeLiters => real()(); // Water volume in liters
  RealColumn get workingPressureBar => real()(); // Rated working pressure
  TextColumn get material => text()(); // aluminum, steel, carbonFiber
  TextColumn get description =>
      text().withDefault(const Constant(''))(); // Optional description
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Air-integration transmitter registry (issue #1365, v200). One row per
/// physical transmitter the diver owns or regularly rents, keyed on the serial
/// the computer reports, or on (dive computer, channel index) for parsers that
/// report no serial. The spec columns are a SNAPSHOT, like
/// [CylinderConfigItems]: picking a preset or a gear cylinder in the editor
/// copies its values here, and there is deliberately no FK to tank_presets.
/// Synced entity with its own hlc.
@DataClassName('TransmitterRow')
class Transmitters extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  // Normalized through normalizeTransmitterSerial before every write.
  TextColumn get transmitterSerial => text().nullable()();
  TextColumn get diveComputerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get channelIndex => integer().nullable()();
  TextColumn get label => text()();
  TextColumn get tankRole => text()(); // TankRole.name
  RealColumn get volumeL => real().nullable()();
  RealColumn get workingPressureBar => real().nullable()();
  TextColumn get tankMaterial => text().nullable()(); // TankMaterial.name
  TextColumn get presetName => text().nullable()();
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// The transmitter gear item this entry is (condition phase 3b, v206),
  /// beside [equipmentId], the cylinder it feeds. The dropout rules read an
  /// item's serials through it.
  TextColumn get transmitterEquipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cylinder fill history (issue #2334, v228). One row per fill of one
/// physical cylinder, keyed by the cylinder's passport id (an equipment
/// attribute, not a foreign key) so the history survives a deleted and
/// re-created item and can belong to a cylinder the diver does not own.
/// [equipmentId] is a convenience link resolved from the passport id at write
/// time and re-resolved by "Link an existing tag". Synced entity with its own
/// hlc, registered like [Transmitters].
@DataClassName('CylinderFillRow')
class CylinderFills extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get passportId => text()();
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get filledAt => integer()();
  RealColumn get o2Percent => real()();
  RealColumn get hePercent => real().withDefault(const Constant(0.0))();
  RealColumn get pressureBar => real().nullable()();
  RealColumn get temperatureC => real().nullable()();
  TextColumn get analyzer => text().nullable()();
  TextColumn get stationName => text().nullable()();
  // base64url Ed25519 public key from a signed record (PR 3); null for a
  // manual fill.
  TextColumn get stationKey => text().nullable()();
  // The JWS token verbatim (PR 3); the truth for every analysis column.
  TextColumn get signedRecord => text().nullable()();
  // FillSource.name: manual, qr, nfc, file, link, issued.
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
