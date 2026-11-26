/// Species covers and ID practice (issue #5027).
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/marine_life_tables.dart';

/// v383: the picture a diver chose to stand for a species. One row per
/// (diver, species), its id derived by `speciesCoverId`, so two devices
/// choosing a cover write the same row and sync keeps the newer. Kept apart
/// from `species`, whose built-in rows stop taking catalog updates once
/// anything stamps their clock.
///
/// [mediaId] and [identificationId] are soft references: a cover whose
/// media or identification goes away is ignored, never cascaded. Removing a
/// cover nulls [mediaId] rather than deleting the row, so no tombstone races
/// a later choice of the same derived id.
@DataClassName('SpeciesCoverRow')
class SpeciesCovers extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get speciesId =>
      text().references(Species, #id, onDelete: KeyAction.cascade)();
  TextColumn get mediaId => text().nullable()();
  TextColumn get identificationId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// v383: how a diver is doing at naming a species in practice, a Leitner
/// box from 1 to 5 and when it is next due. One row per (diver, species),
/// its id derived by `speciesPracticeId`; last write wins.
@DataClassName('SpeciesPracticeRow')
class SpeciesPractice extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get speciesId =>
      text().references(Species, #id, onDelete: KeyAction.cascade)();
  IntColumn get box => integer()();
  IntColumn get dueAt => integer()();
  IntColumn get rightCount => integer().withDefault(const Constant(0))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get lastPractisedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
