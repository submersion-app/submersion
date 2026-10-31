/// The per-device change log (issue #3922).
///
/// Written by generated triggers, read by `lib/features/change_log/`. None
/// of these tables has an `hlc` column or is registered with sync: each
/// device keeps its own log, and it travels only in that device's backups.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

/// The one row (`id` 1) that tells the triggers what is happening now.
///
/// [scopeExpiresAt] and [suppressedUntil] are leases: the main database is
/// opened from two isolates and a job can be killed part way, so a stale
/// value lapses by itself instead of mislabelling or silencing later saves.
/// [triggerHash] is the hash of the installed trigger SQL.
@DataClassName('ChangeLogContextRow')
class ChangeLogContext extends Table {
  IntColumn get id => integer()();
  TextColumn get operationId => text().nullable()();
  IntColumn get scopeExpiresAt => integer().nullable()();
  IntColumn get suppressedUntil => integer().nullable()();
  TextColumn get triggerHash => text().nullable()();

  @override
  String get tableName => 'change_log_context';

  @override
  Set<Column> get primaryKey => {id};
}

/// One thing the diver sees in the feed.
///
/// [lastEventId] orders the feed, because event ids only rise while the
/// device clock can move backwards. A summary operation, which has no
/// events of its own, takes the highest event id at the time.
@DataClassName('ChangeLogOperationRow')
class ChangeLogOperations extends Table {
  TextColumn get id => text()();
  TextColumn get source => text()();
  TextColumn get label => text().nullable()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get diverId => text().nullable()();
  TextColumn get rootTable => text().nullable()();
  TextColumn get rootId => text().nullable()();
  TextColumn get rootLabel => text().nullable()();
  IntColumn get rootOrdinal => integer().nullable()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer()();
  IntColumn get lastEventId => integer().nullable()();
  IntColumn get eventCount => integer().withDefault(const Constant(0))();
  IntColumn get summaryCount => integer().nullable()();
  BoolColumn get closed => boolean().withDefault(const Constant(false))();
  TextColumn get revertOfId => text().nullable()();
  TextColumn get revertedById => text().nullable()();

  @override
  String get tableName => 'change_log_operations';

  @override
  Set<Column> get primaryKey => {id};
}

/// One changed record, as a trigger saw it. [action] is `I`, `U` or `D`.
///
/// Autoincrement rather than a plain rowid: pruning deletes old rows, and
/// the feed relies on an id never being handed out twice.
@DataClassName('ChangeLogEventRow')
class ChangeLogEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operationId => text().nullable()();
  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get action => text()();
  IntColumn get changedAt => integer()();
  IntColumn get schemaVersion => integer()();
  BoolColumn get settled => boolean().withDefault(const Constant(false))();
  TextColumn get rootTable => text().nullable()();
  TextColumn get rootId => text().nullable()();

  @override
  String get tableName => 'change_log_events';
}

/// One changed column of a [ChangeLogEvents] row.
///
/// [oldValue] and [newValue] are declared BLOB because that declared type
/// has no affinity, so SQLite stores every value unchanged. A drift `any`
/// column declares ANY, which has numeric affinity outside STRICT tables and
/// would turn the text `028` into the number 28. Read them through
/// `customSelect` and `row.data`, never the generated row class.
@DataClassName('ChangeLogFieldRow')
class ChangeLogFields extends Table {
  IntColumn get eventId => integer()();
  TextColumn get columnName => text()();
  BlobColumn get oldValue => blob().nullable()();
  BlobColumn get newValue => blob().nullable()();

  @override
  String get tableName => 'change_log_fields';

  @override
  Set<Column> get primaryKey => {eventId, columnName};

  @override
  bool get withoutRowId => true;
}
