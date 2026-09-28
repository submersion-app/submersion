/// Safety reviews, emergency chambers and incidents.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';

/// Marker row recording that the safety review engine has analyzed a dive.
/// Lets zero-findings (clean) dives be distinguished from never-analyzed
/// dives without replaying the profile. Write-once child of Dives: no HLC
/// columns; sync uses markRecordPending/logDeletion like DiveProfileEvents.
class DiveSafetyReviews extends Table {
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get engineVersion => integer()();
  IntColumn get reviewedAt => integer()();

  @override
  Set<Column> get primaryKey => {diveId};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// One safety review observation for a dive (see SafetyFinding entity).
/// Write-once child of Dives except for dismissed_at, which toggles.
class DiveSafetyFindings extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get ruleId => text()(); // SafetyRuleId.dbValue
  TextColumn get severity => text()(); // SafetySeverity.dbValue
  IntColumn get startTimestamp => integer().nullable()();
  IntColumn get endTimestamp => integer().nullable()();
  RealColumn get value => real().nullable()();
  IntColumn get engineVersion => integer()();
  IntColumn get dismissedAt => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// v210: this child's own clock, stamped when it is marked pending. The
  /// merge refuses a remote copy strictly older than the local one, so a
  /// stale full row from a peer cannot overwrite a newer local edit
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();
}

/// User-added hyperbaric chamber entries for the offline emergency card
/// (bundled chambers stay asset-resident). Aggregate root with HLC for
/// cross-device conflict resolution.
class EmergencyChambers extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get country => text()();
  TextColumn get city => text().nullable()();
  TextColumn get phone => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Near-miss incident reports (safety phase 4). Standalone aggregate root
/// with optional dive link; the link is severed (not cascaded) on dive
/// deletion so the report survives. Synced between the diver's devices but
/// deliberately absent from every outbound exporter.
class Incidents extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().nullable().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();

  /// v202: the item an equipment incident attributes to.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get occurredAt => integer()();
  TextColumn get category => text()();
  TextColumn get severity => text()();
  TextColumn get narrative => text()();
  TextColumn get contributingFactors => text().nullable()();
  TextColumn get lessonsLearned => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
