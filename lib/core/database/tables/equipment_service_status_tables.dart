/// The equipment service cache the query language filters on.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/equipment_tables.dart';

/// Each active item's worst service severity for the ACTIVE diver, as
/// `ServiceDueEngine` last evaluated it (#2365 PR 3). A local cache: no
/// hlc column, so sync never reads or writes it, and a diver switch
/// rewrites it. The `serviceDue` query field reads it; an item with no
/// row reads as ok.
@DataClassName('EquipmentServiceStatusRow')
class EquipmentServiceStatus extends Table {
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// A `ServiceClockSeverity` name: ok, dueSoon or overdue.
  TextColumn get severity => text()();

  /// The worst clock's date trigger, epoch ms, when it has one.
  IntColumn get dueDate => integer().nullable()();
  IntColumn get computedAt => integer()();

  @override
  Set<Column> get primaryKey => {equipmentId};
}
