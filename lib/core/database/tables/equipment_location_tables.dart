/// Equipment locations: a diver's named places and each item's move log.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';

/// A diver's named places where gear can be (v268). No unique name: a
/// diver merge or a two-device race would otherwise fail; the Manage page
/// warns about a duplicate instead.
@DataClassName('EquipmentLocationRow')
class EquipmentLocations extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();

  /// An `EquipmentLocationKind` name: storage, serviceShop, person, other.
  TextColumn get kind => text().withDefault(const Constant('other'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Each item's location log (v268). The newest move by moved_at, then
/// created_at, then id is where the item is now; a null location_id
/// records a cleared location. A parent-gated child of equipment in sync.
@DataClassName('EquipmentLocationMoveRow')
class EquipmentLocationMoves extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// SET NULL so deleting a place leaves its moves reading "no location"
  /// rather than vanishing; the repository only deletes unused places.
  TextColumn get locationId => text().nullable().references(
    EquipmentLocations,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get movedAt => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
