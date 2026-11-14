/// What an equipment set carries besides its own gear (issue #4525): other
/// sets, weight presets and cylinder configurations.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/cylinder_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/weight_tables.dart';

/// A set that another set includes (v364). The outer set's gear is its own
/// plus that of every set it includes. One level only: a set that includes
/// sets is never itself included. A parent-gated child of `equipment_sets`
/// keyed by its own id, like `weight_preset_entries`; the pair is unique.
@DataClassName('EquipmentSetIncludeRow')
class EquipmentSetIncludes extends Table {
  TextColumn get id => text()();

  /// The outer set.
  TextColumn get setId =>
      text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();

  /// The set whose gear, weights and tanks the outer set also applies.
  TextColumn get includedSetId =>
      text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();

  /// Position among the outer set's included sets.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  /// This row's own clock, stamped when it is marked pending.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A weight preset an equipment set applies with its gear (v364). The
/// preset's entries are copied onto the dive; nothing links back.
@DataClassName('EquipmentSetWeightPresetRow')
class EquipmentSetWeightPresets extends Table {
  TextColumn get id => text()();
  TextColumn get setId =>
      text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();
  TextColumn get presetId =>
      text().references(WeightPresets, #id, onDelete: KeyAction.cascade)();

  /// Position among the set's weight presets.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  /// This row's own clock, stamped when it is marked pending.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A cylinder configuration an equipment set applies with its gear (v364).
/// Its cylinders are merged into the dive's tanks; nothing links back.
@DataClassName('EquipmentSetCylinderConfigRow')
class EquipmentSetCylinderConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get setId =>
      text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();
  TextColumn get configId =>
      text().references(CylinderConfigs, #id, onDelete: KeyAction.cascade)();

  /// Position among the set's cylinder configurations.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  /// This row's own clock, stamped when it is marked pending.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
