/// Logbook rules and their run history (#3513).
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';

/// A diver's logbook rule (v301): when [conditionJson] (the versioned query
/// AST from `queryNodeToJson`) matches a dive or site, apply [actionsJson]
/// (the versioned list from `ruleActionsToJson`). [subject] is `dives` or
/// `sites`; [triggers] is comma-joined `RuleTrigger` names. Synced with its
/// own hlc, per diver, tombstoned with the diver.
@DataClassName('RuleRow')
class Rules extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get subject => text()();
  TextColumn get name => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get triggers =>
      text().withDefault(const Constant('afterImport'))();
  TextColumn get conditionJson => text()();
  TextColumn get actionsJson => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One run of the rules that changed something (v301): its history entry.
/// [trigger] is a `RuleRunTrigger` name; [undoneAt] is set once undone.
@DataClassName('RuleRunRow')
class RuleRuns extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get trigger => text()();
  TextColumn get sourceLabel => text().nullable()();
  TextColumn get deviceLabel => text().nullable()();
  IntColumn get ranAt => integer()();
  IntColumn get changedCount => integer()();
  IntColumn get undoneAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One field a run changed on one dive or site (v301). [beforeJson] and
/// [afterJson] are the JSON values undo compares and restores. [ruleId] has
/// no foreign key: the history outlives a deleted rule, and [ruleName]
/// keeps its name from the time of the run.
@DataClassName('RuleRunChangeRow')
class RuleRunChanges extends Table {
  TextColumn get id => text()();
  TextColumn get runId =>
      text().references(RuleRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get subject => text()();
  TextColumn get targetId => text()();
  TextColumn get ruleId => text().nullable()();
  TextColumn get ruleName => text()();
  TextColumn get field => text()();
  TextColumn get beforeJson => text()();
  TextColumn get afterJson => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
