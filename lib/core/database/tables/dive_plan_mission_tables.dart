/// The DPV mission layered on a saved dive plan.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_plan_tables.dart';

/// A DPV mission layered on a saved dive plan (v241, issue #2086). At most
/// one row per plan, and no row means the plan has no mission. The row's id
/// is its plan's id; `plan_id` still carries the foreign key and the unique
/// key so a plan can never carry two.
class DivePlanMissions extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(DivePlans, #id)();

  /// Fraction of scooter burn time that must remain at the surface.
  RealColumn get batteryReserveFraction => real()();

  /// Current inherited by legs without their own; both null for none.
  RealColumn get defaultCurrentSpeedMps => real().nullable()();
  RealColumn get defaultCurrentSetsTowardDeg => real().nullable()();

  /// MissionEnvironment.name: overhead or openWater.
  TextColumn get environment =>
      text().withDefault(const Constant('overhead'))();

  /// Walking speed for a shore exit, m/s.
  RealColumn get walkSpeedMps => real().withDefault(const Constant(0.8))();

  /// Longest acceptable surface swim, metres; null for no limit.
  RealColumn get surfaceSwimLimitM => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {planId},
  ];
}

/// One outbound leg of a plan's DPV mission route (v241, issue #2086),
/// keyed to its plan like `dive_plan_segments`. The return is derived.
class DivePlanMissionLegs extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(DivePlans, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// The waypoint the leg ends at, for example "T" or "Jump 2".
  TextColumn get label => text()();
  RealColumn get distanceM => real()();
  RealColumn get depthM => real()();
  RealColumn get headingDeg => real()();

  /// This leg's current; both null inherits the mission default.
  RealColumn get currentSpeedMps => real().nullable()();
  RealColumn get currentSetsTowardDeg => real().nullable()();

  /// Open water shore exit from this leg's waypoint; both null for none.
  RealColumn get shoreSwimM => real().nullable()();
  RealColumn get shoreWalkM => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One diver on a plan's DPV mission (v241, issue #2086), with a snapshot
/// of their scooter. `buddy_id`, `diver_id` and `scooter_equipment_id` are
/// soft links with no foreign key: a key with no delete action would block
/// deleting the buddy, diver or item, and a missing scooter falls back to
/// the snapshot columns.
class DivePlanMissionMembers extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(DivePlans, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get displayName => text()();
  TextColumn get buddyId => text().nullable()();
  TextColumn get diverId => text().nullable()();

  /// Bottom surface air consumption, litres per minute.
  RealColumn get sacBottom => real()();
  RealColumn get swimSpeedMps => real()();
  TextColumn get scooterEquipmentId => text().nullable()();
  TextColumn get scooterName => text()();
  RealColumn get scooterSpeedMps => real()();
  IntColumn get scooterBurnSeconds => integer()();
  RealColumn get towSpeedFactor => real()();
  RealColumn get towBurnFactor => real()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
