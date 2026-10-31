import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_preferences.dart';

/// Removes entries past their retention, a few at a time, so a year of log
/// never holds the database for long.
class ChangeLogMaintenance {
  ChangeLogMaintenance({
    required ChangeLogPreferences preferences,
    required SharedPreferences prefs,
    DateTime Function()? now,
  }) : _preferences = preferences,
       _prefs = prefs,
       _now = now ?? DateTime.now;

  static const lastPrunedKey = 'change_log_last_pruned_at';
  static const _interval = Duration(days: 1);

  final ChangeLogPreferences _preferences;
  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final _log = LoggerService.forClass(ChangeLogMaintenance);

  AppDatabase get _db => DatabaseService.instance.database;

  /// Prunes when the last prune was a day or more ago. Never throws, because
  /// nothing waits on it.
  Future<int> pruneIfDue() async {
    final now = _now();
    final last = _prefs.getInt(lastPrunedKey);
    if (last != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)) < _interval) {
      return 0;
    }
    try {
      final removed = await prune();
      await _prefs.setInt(lastPrunedKey, now.millisecondsSinceEpoch);
      return removed;
    } catch (error, stackTrace) {
      _log.warning(
        'Could not prune the change log',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  /// Removes operations older than the retention, with their events and
  /// fields, [batch] at a time. An operation with events still to settle is
  /// left for a later pass. Returns how many went.
  Future<int> prune({int batch = 200}) async {
    final months = _preferences.retentionMonths;
    if (months == 0) return 0;
    final now = _now();
    final cutoff = DateTime(
      now.year,
      now.month - months,
      now.day,
    ).millisecondsSinceEpoch;

    var removed = 0;
    while (true) {
      final count = await _pruneBatch(cutoff, batch);
      removed += count;
      if (count < batch) return removed;
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<int> _pruneBatch(int cutoff, int batch) => _db.transaction(() async {
    const expired =
        'SELECT o.id FROM change_log_operations o WHERE o.ended_at < ? '
        'AND NOT EXISTS (SELECT 1 FROM change_log_events e '
        'WHERE e.operation_id = o.id AND e.settled = 0) LIMIT ?';
    final rows = await _db
        .customSelect(
          expired,
          variables: [Variable<int>(cutoff), Variable<int>(batch)],
        )
        .get();
    if (rows.isEmpty) return 0;
    final ids = [for (final row in rows) row.read<String>('id')];
    final marks = List.filled(ids.length, '?').join(', ');
    await _db.customStatement(
      'DELETE FROM change_log_fields WHERE event_id IN '
      '(SELECT id FROM change_log_events WHERE operation_id IN ($marks))',
      ids,
    );
    await _db.customStatement(
      'DELETE FROM change_log_events WHERE operation_id IN ($marks)',
      ids,
    );
    await _db.customUpdate(
      'DELETE FROM change_log_operations WHERE id IN ($marks)',
      variables: [for (final id in ids) Variable<String>(id)],
      updates: {_db.changeLogOperations},
      updateKind: UpdateKind.delete,
    );
    return ids.length;
  });
}
