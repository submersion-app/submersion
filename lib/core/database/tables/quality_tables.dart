/// Findings of the Data Quality Assistant.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_profile_tables.dart';
import 'package:submersion/core/database/tables/dive_tables.dart';

/// Data-quality findings produced by the Data Quality Assistant detectors.
/// One row per (dive, detector, discriminator). Ids are deterministic
/// UUIDv5 values so independent scans on two devices converge on the same
/// row. A user dismissal is a status update, never a delete -- deterministic
/// ids would otherwise resurrect a dismissed finding on the next rescan. (The
/// scan pipeline itself may still delete a finding that no longer reproduces;
/// that path writes a sync tombstone.)
@DataClassName('QualityFindingRow')
class QualityFindings extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();

  /// The other dive for cross-dive findings (duplicates, splits, overlaps).
  TextColumn get relatedDiveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();

  /// Source computer for source-scoped findings.
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get detectorId => text()();
  IntColumn get detectorVersion => integer()();
  TextColumn get category => text()();
  TextColumn get severity => text()();
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// JSON object of numeric arguments; the UI renders localized messages
  /// from these. Never store prose.
  TextColumn get params => text().withDefault(const Constant('{}'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
