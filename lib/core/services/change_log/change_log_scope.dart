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

const Duration _renewEvery = Duration(minutes: 1);

final _log = LoggerService.forClass(ChangeLogScope);

/// Tells the change log triggers what is happening (issue #3922).
///
/// Logging must never block work, so a failure here is logged and the body
/// still runs. Call these outside any transaction the body opens, so a
/// failed body cannot discard the operation row or the context reset.
abstract final class ChangeLogScope {
  /// Runs [body] with its changes filed under one new operation.
  static Future<T> run<T>(
    AppDatabase db, {
    required ChangeLogSource source,
    String? label,
    String? deviceId,
    String? revertOfId,
    required Future<T> Function() body,
  }) async {
    final operationId = const Uuid().v4();
    final previous = await _open(
      db,
      operationId: operationId,
      source: source,
      label: label,
      deviceId: deviceId,
      revertOfId: revertOfId,
    );
    final renewal = previous == null
        ? null
        : Timer.periodic(_renewEvery, (_) => _renewScope(db, operationId));
    try {
      return await body();
    } finally {
      renewal?.cancel();
      if (previous != null) await _close(db, operationId, previous.id);
    }
  }

  /// Runs [body] with the triggers silenced, then records one summary
  /// operation. For a full library write on a device with none of its own,
  /// which would otherwise log the whole library.
  static Future<T> suppressed<T>(
    AppDatabase db, {
    required String label,
    required ChangeLogSource source,
    int? summaryCount,
    required Future<T> Function() body,
  }) async {
    final held = await _suppress(db);
    final renewal = held
        ? Timer.periodic(_renewEvery, (_) => _suppress(db))
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
    await _writeSummary(
      db,
      label: label,
      source: source,
      summaryCount: summaryCount,
    );
    return result;
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static int _expiry() => _now() + kChangeLogLease.inMilliseconds;

  /// Files the operation and points the context at it. Returns the operation
  /// it replaced, or null when the context could not be written.
  static Future<({String? id})?> _open(
    AppDatabase db, {
    required String operationId,
    required ChangeLogSource source,
    required String? label,
    required String? deviceId,
    required String? revertOfId,
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
      final context = await db
          .customSelect(
            'SELECT operation_id FROM change_log_context WHERE id = 1',
          )
          .getSingle();
      await db.customStatement(
        'UPDATE change_log_context SET operation_id = ?, scope_expires_at = ? '
        'WHERE id = 1',
        [operationId, _expiry()],
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

  static Future<void> _renewScope(AppDatabase db, String operationId) async {
    try {
      await db.customStatement(
        'UPDATE change_log_context SET scope_expires_at = ? '
        'WHERE id = 1 AND operation_id = ?',
        [_expiry(), operationId],
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
        [previousId, _expiry(), operationId],
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
  static Future<bool> _suppress(AppDatabase db) async {
    try {
      await db.customStatement(
        'UPDATE change_log_context SET suppressed_until = ? WHERE id = 1',
        [_expiry()],
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

  /// A summary has no events of its own, so it takes the highest event id to
  /// sort where it happened.
  static Future<void> _writeSummary(
    AppDatabase db, {
    required String label,
    required ChangeLogSource source,
    required int? summaryCount,
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
              lastEventId: Value(newest.data['id'] as int?),
              summaryCount: Value(summaryCount),
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
