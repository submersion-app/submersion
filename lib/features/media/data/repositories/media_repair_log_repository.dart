import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// What a repair did to a row.
enum RepairLogAction {
  /// Pointer rewritten to a found file or gallery asset.
  relink,

  /// Row converted to cloud-backed (the store became its source of truth).
  cloudBacked,

  /// Same as [relink], but applied automatically by the watcher.
  autoRelink,
}

/// Where the repair's candidate came from.
enum RepairLogSource { folder, photoLibrary, store, watcher, manual }

/// One audit row.
class RepairLogEntry {
  const RepairLogEntry({
    required this.id,
    required this.mediaId,
    required this.batchId,
    required this.occurredAt,
    required this.action,
    this.oldValue,
    this.newValue,
    required this.source,
  });

  final String id;
  final String mediaId;
  final String batchId;
  final DateTime occurredAt;
  final RepairLogAction action;
  final String? oldValue;
  final String? newValue;
  final RepairLogSource source;
}

/// Per-device repair history (Media section Phase 5).
///
/// Never synced: each row describes a path change that only makes sense on
/// the device that made it. Capped at [_maxRows] so a watcher running for
/// years cannot grow the database without bound.
class MediaRepairLogRepository {
  MediaRepairLogRepository({AppDatabase? database}) : _database = database;

  final AppDatabase? _database;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  static const int _maxRows = 500;

  /// Emits whenever the repair log changes.
  ///
  /// The log is append-only from the caller's side but not from the reader's:
  /// the watcher's automatic pass records entries with no user action, and the
  /// prune in [record] drops the oldest rows. A history view open across
  /// either would otherwise keep rendering the snapshot it built with.
  Stream<void> watchRepairLogChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.mediaRepairLog));

  /// Appends [entries] and prunes the history back to the newest
  /// [_maxRows].
  Future<void> record(List<RepairLogEntry> entries) async {
    if (entries.isEmpty) return;
    await _db.transaction(() async {
      for (final entry in entries) {
        await _db
            .into(_db.mediaRepairLog)
            .insertOnConflictUpdate(
              MediaRepairLogCompanion(
                id: Value(entry.id),
                mediaId: Value(entry.mediaId),
                batchId: Value(entry.batchId),
                occurredAt: Value(entry.occurredAt.millisecondsSinceEpoch),
                action: Value(entry.action.name),
                oldValue: Value(entry.oldValue),
                newValue: Value(entry.newValue),
                source: Value(entry.source.name),
              ),
            );
      }
      await _db.customStatement(
        'DELETE FROM media_repair_log WHERE id NOT IN ('
        'SELECT id FROM media_repair_log '
        'ORDER BY occurred_at DESC LIMIT $_maxRows)',
      );
    });
  }

  /// Newest first.
  Future<List<RepairLogEntry>> recent({int limit = 100}) async {
    final rows =
        await (_db.select(_db.mediaRepairLog)
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
              ..limit(limit))
            .get();
    return [
      for (final row in rows)
        RepairLogEntry(
          id: row.id,
          mediaId: row.mediaId,
          batchId: row.batchId,
          occurredAt: DateTime.fromMillisecondsSinceEpoch(row.occurredAt),
          action: RepairLogAction.values.firstWhere(
            (a) => a.name == row.action,
            orElse: () => RepairLogAction.relink,
          ),
          oldValue: row.oldValue,
          newValue: row.newValue,
          source: RepairLogSource.values.firstWhere(
            (s) => s.name == row.source,
            orElse: () => RepairLogSource.manual,
          ),
        ),
    ];
  }
}
