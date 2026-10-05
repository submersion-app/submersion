/// Insights: dismissed observations (issue #2381).
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';

/// v265: one row per dismissed Insights observation. The id is derived
/// from (diver, rule, fingerprint) by `observationDismissalId`, so two
/// devices that dismiss the same observation write the same row and sync
/// merges it as a plain upsert. Undo clears [dismissedAt]; the feature
/// never deletes rows, so no tombstone races a later re-dismissal.
@DataClassName('InsightObservationDismissalRow')
class InsightObservationDismissals extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get ruleId => text()();
  TextColumn get fingerprint => text()();
  IntColumn get dismissedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
