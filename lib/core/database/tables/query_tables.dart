/// Saved queries of the entity query language.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';

/// A named query a diver saved (entity query language #2365, v238, spec
/// Unit 7). [queryJson] is the versioned AST from `queryNodeToJson`, never
/// the printed text, so a grammar change cannot break stored rows; the
/// printer regenerates the text on load. [subject] is the root entity's
/// `QuerySubject.name` (`dives`, `sites`, ...). Synced with its own hlc,
/// registered like `CylinderFills`; per diver, tombstoned with the diver.
@DataClassName('SavedQueryRow')
class SavedQueries extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get subject => text()();
  TextColumn get name => text()();
  TextColumn get queryJson => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
