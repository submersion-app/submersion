import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// Runs [body], the writes of one editing sitting on the record [recordId]
/// of [table] (issue #4527), in one change log operation and one database
/// transaction: the sitting is one History entry that reverts as a unit,
/// and a failure leaves nothing half saved.
///
/// The operation's source is "manual" and its label names the record and
/// the cards the sitting changed ([RecordEditLabel]). The scope goes outside
/// the transaction it covers, as [ChangeLogScope] requires; an operation
/// that ends with no events is removed when the log settles.
///
/// Sync is told of the sitting once, after the commit, and not at all when
/// it rolls back ([SyncEventBus.holdNotices]): the writes inside it hold
/// their notices. With [wrote], a committed sitting whose result it says
/// wrote something tells sync itself, so one whose writes were told to
/// stay quiet (a repository's `notify: false`) is still heard of.
Future<R> runRecordSitting<R>({
  required String table,
  required String recordId,
  required Iterable<String> changedCardIds,
  required Future<R> Function() body,
  bool Function(R result)? wrote,
}) => ChangeLogScope.run(
  DatabaseService.instance.databaseOrNull,
  source: ChangeLogSource.manual,
  label: RecordEditLabel.encode(
    table: table,
    id: recordId,
    cardIds: changedCardIds,
  ),
  // Sync hears of the sitting once it has committed, not of each write
  // inside it: a write a later one rolls back was never saved.
  body: () => SyncEventBus.holdNotices(() async {
    final result = await DatabaseService.instance.database.transaction(body);
    // Held with any notice the writes sent: one goes out for both.
    if (wrote?.call(result) ?? false) SyncEventBus.notifyLocalChange();
    return result;
  }),
);

/// Labels the running sitting with [recordId] of [table], in place of the
/// record it opened with. Call it inside [runRecordSitting]'s body when the
/// write lands on another row than the one the sitting was opened for: a
/// transmitter key saved over the unclaimed downloaded key that held its
/// serial is written under that key's id (issue #4527, phase 4). The label
/// is part of the sitting's transaction, so a sitting that fails keeps
/// none of it. Does nothing outside a sitting.
Future<void> relabelRecordSitting({
  required String table,
  required String recordId,
  Iterable<String> changedCardIds = const [],
}) async {
  final operationId = ChangeLogScope.currentOperationId;
  final db = DatabaseService.instance.databaseOrNull;
  if (operationId == null || db == null) return;
  await db.customUpdate(
    'UPDATE change_log_operations SET label = ? WHERE id = ?',
    variables: [
      Variable<String>(
        RecordEditLabel.encode(
          table: table,
          id: recordId,
          cardIds: changedCardIds,
        ),
      ),
      Variable<String>(operationId),
    ],
    updates: {db.changeLogOperations},
  );
}

/// Creates the record [recordId] of [table], a new record's sitting (issue
/// #4527, phase 3, plan 11), inside [runRecordSitting].
///
/// The id is the one the sitting was opened with, which its held writes
/// already point at. [insert] writes the record's row, then [alsoWrite]
/// the sitting's held writes, in one transaction and one change log
/// operation naming [changedCardIds]: if either throws nothing is left.
/// Returns the record as [readBack] reads it at the end, or [created] when
/// it reads nothing. Throws [StateError], before anything is written, when
/// [recordId] is empty or [isStored] says a stored record already has it.
Future<T> createRecordSitting<T>({
  required String table,
  required String recordId,
  required Iterable<String> changedCardIds,
  required Future<bool> Function() isStored,
  required Future<void> Function() insert,
  Future<void> Function()? alsoWrite,
  required Future<T?> Function() readBack,
  required T created,
}) {
  if (recordId.isEmpty) {
    return Future.error(
      StateError('A new $table record needs its id before it is created'),
    );
  }
  return runRecordSitting(
    table: table,
    recordId: recordId,
    changedCardIds: changedCardIds,
    // A create always writes its row.
    wrote: (_) => true,
    body: () async {
      if (await isStored()) {
        throw StateError('$table record $recordId already exists');
      }
      await insert();
      await alsoWrite?.call();
      return await readBack() ?? created;
    },
  );
}

/// Writes one editing sitting on the record [recordId] of [table], inside
/// [runRecordSitting].
///
/// [read] reads the record as stored now and [apply] puts the sitting's
/// changes on it, so a value changed underneath meanwhile on a card the
/// diver never touched is not written back over. [write] stores the result.
/// Returns the record before and after, or null when [apply] changed
/// nothing. Throws [StateError] when the record no longer exists.
///
/// [writeFirst] makes the sitting's writes that need rows the record's own
/// write may delete, and runs before it; [alsoWrite] makes its writes to
/// other rows, and runs after it. Both are in the same transaction and
/// History entry, so if either throws nothing is left. When [apply] changed
/// nothing they run only if [alsoWriteIsAChange]: the sitting's only change
/// is a write of its own, and the record comes back as it was before and
/// after.
Future<({T before, T after})?> writeRecordSitting<T>({
  required String table,
  required String recordId,
  required Iterable<String> changedCardIds,
  required Future<T?> Function() read,
  required T Function(T stored) apply,
  required Future<void> Function(T stored, T merged) write,
  Future<void> Function()? writeFirst,
  Future<void> Function()? alsoWrite,
  bool alsoWriteIsAChange = false,
}) => runRecordSitting(
  table: table,
  recordId: recordId,
  changedCardIds: changedCardIds,
  // Null when nothing changed, which wrote nothing.
  wrote: (result) => result != null,
  body: () async {
    final stored = await read();
    if (stored == null) {
      throw StateError('$table $recordId no longer exists');
    }
    final merged = apply(stored);
    if (merged == stored) {
      if (!alsoWriteIsAChange || (alsoWrite == null && writeFirst == null)) {
        return null;
      }
      await writeFirst?.call();
      await alsoWrite?.call();
      return (before: stored, after: stored);
    }
    await writeFirst?.call();
    await write(stored, merged);
    await alsoWrite?.call();
    return (before: stored, after: merged);
  },
);
