/// The download connections each dive computer has reached the library by.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_profile_tables.dart';

/// The ways one dive computer has reached the library (v279, issue #3106):
/// a direct transport (BLE, Bluetooth Classic, USB, infrared), a file
/// format, or a cloud provider. One row per (computer, kind, detail), on a
/// deterministic id so two devices recording the same connection converge.
///
/// No unique index on purpose: a unique constraint on a replicated table
/// makes an inbound sync insert throw instead of merge.
@DataClassName('DiveComputerConnectionRow')
class DiveComputerConnections extends Table {
  TextColumn get id => text()();
  TextColumn get computerId =>
      text().references(DiveComputers, #id, onDelete: KeyAction.cascade)();

  /// `ble`, `bluetoothClassic`, `usb`, `infrared`, `file` or `cloud`.
  TextColumn get kind => text()();

  /// The file format (`ImportFormat.name`) or cloud provider; null for a
  /// direct transport.
  TextColumn get detail => text().nullable()();

  IntColumn get firstUsedAt => integer()();
  IntColumn get lastUsedAt => integer()();

  /// Device-local: this device's BLE identifier or USB port. Never synced,
  /// because another host's identifier never applies here.
  TextColumn get address => text().nullable()();

  /// Device-local: when this device last used the connection, which picks
  /// the transport a saved-computer download uses here. Never synced.
  IntColumn get localLastUsedAt => integer().nullable()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
