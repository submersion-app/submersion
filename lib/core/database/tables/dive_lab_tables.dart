/// Saved Dive Lab scenarios.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';

/// Saved "what if" scenarios on a logged dive (Dive Lab, v236). Inputs only:
/// the branch point, the mode and the interventions; outcomes are always
/// recomputed. Synced like dive plans (hlc column, deletion_log tombstones).
class DiveScenarios extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Runtime seconds on the dive's primary profile where the timelines part.
  IntColumn get branchSeconds => integer()();

  /// ScenarioMode name: `replay` or `replan`.
  TextColumn get mode => text().withDefault(const Constant('replay'))();

  /// Versioned JSON envelope (scenario_intervention_codec: formatVersion +
  /// interventions). A kind the reader does not know fails loudly on decode.
  TextColumn get interventionsJson => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
