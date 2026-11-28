/// Media held back from older devices (issue #5122).
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

/// The media rows this device has left out of its sync exports because they
/// are kept with no dive, site or gear while a device in the library still
/// runs a build that would delete them (its orphan sweep and delete
/// cascades predate `retain_in_library`). Each id is released, and the row
/// and its children stamped again so the next export carries them, once
/// every device can keep them or the row gains a place.
///
/// Device-local and never synced. No column is named `hlc` on purpose: the
/// sync registration guard treats any such table as synced.
@DataClassName('HeldMediaEntry')
class HeldMedia extends Table {
  TextColumn get mediaId => text()();

  /// When this device first held the row back, in epoch milliseconds.
  IntColumn get heldAt => integer()();

  @override
  Set<Column> get primaryKey => {mediaId};
}
