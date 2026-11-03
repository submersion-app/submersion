import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Where a change came from. A write with no scope is [manual].
enum ChangeLogSource {
  manual,
  import,
  download,
  rule,
  sync,
  automatic,
  revert,
  system,
}

/// How long a scope or suppression holds without being renewed. The main
/// database is opened from two isolates and a job can be killed part way, so
/// a stale value must lapse by itself instead of mislabelling or silencing
/// later saves.
const Duration kChangeLogLease = Duration(minutes: 5);

/// The lease for one transaction that can outlast [kChangeLogLease], such as
/// applying a whole library. A renewal cannot run until the transaction
/// ends, so a shorter lease would lapse part way through it.
const Duration kChangeLogLongLease = Duration(hours: 1);

const Duration _renewEvery = Duration(minutes: 1);

final _log = LoggerService.forClass(ChangeLogScope);

/// Labels stored on operations the app names itself, which the log page
/// translates when it shows them. Any other label is shown as written, such
/// as a dive computer's name.
abstract final class ChangeLogLabels {
  static const bulkEdit = 'bulk_edit';
  static const bulkDelete = 'bulk_delete';
  static const deletedRecord = 'deleted_record';
  static const merge = 'merge';
  static const undoMerge = 'undo_merge';
  static const undoRule = 'undo_rule';
  static const reparse = 'reparse';
  static const splitDive = 'split_dive';
  static const gearTransfer = 'gear_transfer';
  static const mediaRepair = 'media_repair';
  static const gearFileConversion = 'gear_file_conversion';
  static const galleryBackfill = 'gallery_backfill';
  static const mediaCleanup = 'media_cleanup';
  static const accountMigration = 'account_migration';
  static const qualityRepair = 'quality_repair';
  static const libraryAdopted = 'library_adopted';
  static const libraryReplaced = 'library_replaced';
  static const libraryRestored = 'library_restored';
  static const tableEditor = 'table_editor';
}

/// Tells the change log triggers what is happening (issue #3922).
///
/// Logging must never block work, so a null database or a failure here costs
/// only the log entry: the body still runs. Call these outside any
/// transaction the body opens, so a failed body cannot discard the operation
/// row or the context reset.
abstract final class ChangeLogScope {
  /// In a scope's zone, so a bulk action can tell it is part of one.
  static final _scopeKey = Object();

  /// The operation of the scope running in this zone.
  static String? get currentOperationId => Zone.current[_scopeKey] as String?;

  /// Runs [body] with its changes filed under one new operation.
  static Future<T> run<T>(
    AppDatabase? db, {
    required ChangeLogSource source,
    String? label,
    String? deviceId,
    String? revertOfId,
    Duration lease = kChangeLogLease,
    required Future<T> Function() body,
  }) async {
    if (db == null) return body();
    final operationId = const Uuid().v4();
    final previous = await _open(
      db,
      operationId: operationId,
      source: source,
      label: label,
      deviceId: deviceId,
      revertOfId: revertOfId,
      lease: lease,
    );
    final renewal = previous == null
        ? null
        : Timer.periodic(
            _renewEvery,
            (_) => _renewScope(db, operationId, lease),
          );
    try {
      return await runZoned(body, zoneValues: {_scopeKey: operationId});
    } finally {
      renewal?.cancel();
      if (previous != null) await _close(db, operationId, previous.id, lease);
    }
  }

  /// A diver's bulk action: one operation of its own, or part of the scope
  /// already running, so that undoing an import through `bulkDeleteDives`
  /// files under the undo.
  static Future<T> bulk<T>(
    AppDatabase? db, {
    required String label,
    required Future<T> Function() body,
  }) {
    if (Zone.current[_scopeKey] != null) return body();
    return run(db, source: ChangeLogSource.manual, label: label, body: body);
  }

  /// A background job: one [ChangeLogSource.automatic] operation, or part of
  /// the scope already running. Without this a job's writes would look like
  /// the diver's. Keep [body] to the writes: anything the diver saves while
  /// it runs gets its label.
  static Future<T> automatic<T>(
    AppDatabase? db, {
    required String label,
    required Future<T> Function() body,
  }) {
    if (Zone.current[_scopeKey] != null) return body();
    return run(db, source: ChangeLogSource.automatic, label: label, body: body);
  }

  /// Runs [body] with the triggers silenced, then records one summary
  /// operation. For a full library write on a device with none of its own,
  /// which would otherwise log the whole library.
  static Future<T> suppressed<T>(
    AppDatabase? db, {
    required String label,
    required ChangeLogSource source,
    int? Function(T result)? summaryCount,
    Duration lease = kChangeLogLease,
    required Future<T> Function() body,
  }) async {
    if (db == null) return body();
    final held = await _suppress(db, lease);
    final renewal = held
        ? Timer.periodic(_renewEvery, (_) => _suppress(db, lease))
        : null;
    final T result;
    try {
      result = await body();
    } catch (_) {
      renewal?.cancel();
      if (held) await _endSuppression(db);
      rethrow;
    }
    renewal?.cancel();
    if (held) await _endSuppression(db);
    await summary(
      db,
      label: label,
      source: source,
      count: summaryCount?.call(result),
    );
    return result;
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static int _expiry(Duration lease) => _now() + lease.inMilliseconds;

  /// Files the operation and points the context at it. Returns the operation
  /// it replaced, or null when the context could not be written.
  static Future<({String? id})?> _open(
    AppDatabase db, {
    required String operationId,
    required ChangeLogSource source,
    required String? label,
    required String? deviceId,
    required String? revertOfId,
    required Duration lease,
  }) async {
    try {
      final now = _now();
      await db
          .into(db.changeLogOperations)
          .insert(
            ChangeLogOperationsCompanion.insert(
              id: operationId,
              source: source.name,
              label: Value(label),
              deviceId: Value(deviceId),
              revertOfId: Value(revertOfId),
              startedAt: now,
              endedAt: now,
            ),
          );
      // A lapsed lease is a job that died, so it is not handed back later.
      final context = await db
          .customSelect(
            'SELECT CASE WHEN scope_expires_at > ? THEN operation_id END '
            'AS operation_id FROM change_log_context WHERE id = 1',
            variables: [Variable<int>(now)],
          )
          .getSingle();
      await db.customStatement(
        'UPDATE change_log_context SET operation_id = ?, scope_expires_at = ? '
        'WHERE id = 1',
        [operationId, _expiry(lease)],
      );
      return (id: context.data['operation_id'] as String?);
    } catch (error, stackTrace) {
      _log.warning(
        'Could not open a change log scope',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Future<void> _renewScope(
    AppDatabase db,
    String operationId,
    Duration lease,
  ) async {
    try {
      await db.customStatement(
        'UPDATE change_log_context SET scope_expires_at = ? '
        'WHERE id = 1 AND operation_id = ?',
        [_expiry(lease), operationId],
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Could not renew a change log scope',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Closes the operation and hands the context back, unless another scope
  /// has taken it. An outer scope that ended meanwhile is not restored, or
  /// later saves would join a finished operation until the lease ran out.
  static Future<void> _close(
    AppDatabase db,
    String operationId,
    String? previousId,
    Duration lease,
  ) async {
    try {
      await (db.update(
        db.changeLogOperations,
      )..where((o) => o.id.equals(operationId))).write(
        ChangeLogOperationsCompanion(
          closed: const Value(true),
          endedAt: Value(_now()),
        ),
      );
      await db.customStatement(
        'UPDATE change_log_context SET '
        'operation_id = (SELECT id FROM change_log_operations '
        'WHERE id = ?1 AND closed = 0), '
        'scope_expires_at = CASE WHEN EXISTS (SELECT 1 FROM '
        'change_log_operations WHERE id = ?1 AND closed = 0) THEN ?2 END '
        'WHERE id = 1 AND operation_id = ?3',
        [previousId, _expiry(lease), operationId],
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Could not close a change log scope',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Whether the suppression was written.
  static Future<bool> _suppress(AppDatabase db, Duration lease) async {
    try {
      await db.customStatement(
        'UPDATE change_log_context SET suppressed_until = ? WHERE id = 1',
        [_expiry(lease)],
      );
      return true;
    } catch (error, stackTrace) {
      _log.warning(
        'Could not suppress the change log',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static Future<void> _endSuppression(AppDatabase db) async {
    try {
      await db.customStatement(
        'UPDATE change_log_context SET suppressed_until = NULL WHERE id = 1',
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Could not end a suppression',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Records one entry for writes the log did not see. A summary has no
  /// events of its own, so it takes the highest event id to sort where it
  /// happened, and always has a count, which is what marks it.
  static Future<void> summary(
    AppDatabase db, {
    required String label,
    required ChangeLogSource source,
    int? count,
  }) async {
    try {
      final newest = await db
          .customSelect('SELECT MAX(id) AS id FROM change_log_events')
          .getSingle();
      final now = _now();
      await db
          .into(db.changeLogOperations)
          .insert(
            ChangeLogOperationsCompanion.insert(
              id: const Uuid().v4(),
              source: source.name,
              label: Value(label),
              startedAt: now,
              endedAt: now,
              lastEventId: Value(newest.data['id'] as int? ?? 0),
              summaryCount: Value(count ?? 0),
              closed: const Value(true),
            ),
          );
    } catch (error, stackTrace) {
      _log.warning(
        'Could not write a change log summary',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
