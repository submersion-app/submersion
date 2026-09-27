/// App-level state: legacy settings, cached map regions, notifications,
/// import presets and view configuration.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';

/// Application settings key-value store (legacy - kept for backward compatibility)
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Cached map regions for offline use
class CachedRegions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get minLat => real()();
  RealColumn get maxLat => real()();
  RealColumn get minLng => real()();
  RealColumn get maxLng => real()();
  IntColumn get minZoom => integer()();
  IntColumn get maxZoom => integer()();
  IntColumn get tileCount => integer()();
  IntColumn get sizeBytes => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get lastAccessedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tracks scheduled notifications to enable smart rescheduling
class ScheduledNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// v122: the service schedule this reminder belongs to (null = legacy
  /// single-clock reminder). Local-only table, not synced.
  TextColumn get scheduleId => text().nullable()();
  IntColumn get scheduledDate => integer()(); // Unix timestamp
  IntColumn get reminderDaysBefore => integer()(); // 7, 14, or 30
  IntColumn get notificationId => integer()(); // Platform notification ID
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User-saved CSV import presets (synced across devices; carries an hlc column)
class CsvPresets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get presetJson => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stores the active view configuration per (diver, view_mode).
class ViewConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get viewMode => text()();
  TextColumn get configJson => text()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Named presets per (diver, view_mode).
class FieldPresets extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get viewMode => text()();
  TextColumn get name => text()();
  TextColumn get configJson => text()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
