/// Diver weight entries and weight presets.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';

/// Dated body-mass measurements per diver (weight prediction, v104).
@DataClassName('DiverWeightEntryRow')
class DiverWeightEntries extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id)();
  IntColumn get measuredAt => integer()(); // Unix ms
  RealColumn get weightKg => real()();
  RealColumn get heightCm => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reusable weighting rigs (issue #1609): a named set of weight entries the
/// diver can save from the dive editor and apply to later dives. First-class
/// synced entity (own id + hlc), mirroring [TankPresets] / [EquipmentSets].
@DataClassName('WeightPresetRow')
class WeightPresets extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get displayName => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One weight entry inside a [WeightPresets] rig. Same shape as a [DiveWeights]
/// row minus the dive link; synced as a full child of its preset (the preset's
/// hlc gates the whole set, like [EquipmentSetItems]).
@DataClassName('WeightPresetEntryRow')
class WeightPresetEntries extends Table {
  TextColumn get id => text()();
  TextColumn get presetId =>
      text().references(WeightPresets, #id, onDelete: KeyAction.cascade)();
  TextColumn get weightType => text()();
  RealColumn get amountKg => real()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// The diver's own name for this entry, copied to and from a dive's
  /// weights (issue #956). Empty when unnamed.
  TextColumn get label => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}
