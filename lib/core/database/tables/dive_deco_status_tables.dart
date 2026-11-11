/// The computed deco verdicts the query language's `deco` field reads.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';

/// Whether each dive that records no deco signal had a decompression
/// obligation, as the app's own dive analysis judged it under its own
/// diver's settings (issue #4461): the same verdict the Insights deco card
/// and the dive's DECO badge give. Kept current for the active diver's
/// dives, and refreshed for another profile's before a query on that
/// profile. A local cache: no hlc column, so sync never reads or writes it.
/// The `deco` query field reads it after a dive's recorded signal; a dive
/// with no row is unclassified.
@DataClassName('DiveDecoStatusRow')
class DiveDecoStatus extends Table {
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();

  /// Whether the analysis found a decompression obligation on the dive.
  BoolColumn get hadDeco => boolean()();

  /// When this verdict was written, epoch ms.
  IntColumn get computedAt => integer()();

  @override
  Set<Column> get primaryKey => {diveId};
}
