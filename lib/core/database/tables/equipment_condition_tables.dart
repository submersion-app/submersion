/// Equipment condition engine: observations, findings and reviews.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';

/// v202: a diver's post-dive gear check-in (phase 3). Synced aggregate root.
@DataClassName('EquipmentObservationRow')
class EquipmentObservations extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();
  IntColumn get observedAt => integer()();
  TextColumn get status => text()(); // 'ok' | 'issue'
  TextColumn get issueTags => text().withDefault(const Constant('[]'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// v202: one condition finding per (item, rule, slot) (phase 3). Synced the
/// way dive_safety_findings is: write-once except dismissed_at.
@DataClassName('EquipmentFindingRow')
class EquipmentFindings extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get ruleId => text()();
  TextColumn get severity => text()();
  RealColumn get value => real().nullable()();
  TextColumn get evidence => text().withDefault(const Constant('{}'))();
  TextColumn get evidenceFingerprint => text()();
  IntColumn get engineVersion => integer()();
  IntColumn get dismissedAt => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// v202: per-item marker that the condition engine has run over the current
/// inputs (phase 3). Device-local.
@DataClassName('EquipmentConditionReviewRow')
class EquipmentConditionReviews extends Table {
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  IntColumn get engineVersion => integer()();
  TextColumn get inputFingerprint => text()();
  IntColumn get reviewedAt => integer()();

  @override
  Set<Column> get primaryKey => {equipmentId};
}
