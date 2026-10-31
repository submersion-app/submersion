import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// A record that points at a dive, as it stood when read.
class DiveLinkedRow {
  const DiveLinkedRow({
    required this.entityType,
    required this.id,
    required this.diveId,
  });

  final String entityType;
  final String id;
  final String diveId;
}

/// Keeps the records that merely point at a dive with the dive a consolidate
/// or merge leaves standing (issue #3918).
///
/// Each of these outlives a deleted dive on purpose (`dive_id` is ON DELETE
/// SET NULL), which is right for an intentional delete but silently unlinks
/// them when the dive was folded into another. Routes have the same link but
/// also a primary role and an owner, so they go through
/// `NavTrackRepository.moveLinks`; media and documents have their own moves.
class DiveFoldLinks {
  final _sync = SyncRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  Map<String, TableInfo> get _tables => {
    'diveCenterGearNotes': _db.diveCenterGearNotes,
    'equipmentObservations': _db.equipmentObservations,
    'incidents': _db.incidents,
    'preDiveSessions': _db.preDiveSessions,
  };

  /// Every record linked to [diveIds].
  Future<List<DiveLinkedRow>> read(List<String> diveIds) async {
    final rows = <DiveLinkedRow>[];
    final ids = diveIds.toSet().toList();
    for (final MapEntry(key: entityType, value: table) in _tables.entries) {
      for (final chunk in seriesIdChunks(ids)) {
        final found = await _db
            .customSelect(
              'SELECT id, dive_id FROM ${table.actualTableName} WHERE dive_id '
              'IN (${List.filled(chunk.length, '?').join(', ')})',
              variables: [for (final id in chunk) Variable.withString(id)],
              readsFrom: {table},
            )
            .get();
        rows.addAll(
          found.map(
            (row) => DiveLinkedRow(
              entityType: entityType,
              id: row.read<String>('id'),
              diveId: row.read<String>('dive_id'),
            ),
          ),
        );
      }
    }
    return rows;
  }

  /// Moves every record linked to [fromDiveIds] onto [toDiveId]. Call this
  /// before those dives are deleted.
  Future<void> move({
    required List<String> fromDiveIds,
    required String toDiveId,
    required int now,
  }) async {
    final rows = await read(fromDiveIds);
    await restore([
      for (final row in rows)
        DiveLinkedRow(entityType: row.entityType, id: row.id, diveId: toDiveId),
    ], now: now);
  }

  /// Writes each of [rows] back to the dive it names, which must exist. A
  /// record deleted since it was read stays deleted.
  Future<void> restore(List<DiveLinkedRow> rows, {required int now}) async {
    for (final row in rows) {
      final table = _tables[row.entityType]!;
      final changed = await _db.customUpdate(
        'UPDATE ${table.actualTableName} SET dive_id = ?, updated_at = ? '
        'WHERE id = ?',
        variables: [
          Variable.withString(row.diveId),
          Variable.withInt(now),
          Variable.withString(row.id),
        ],
        updates: {table},
      );
      if (changed == 0) continue;
      await _sync.markRecordPending(
        entityType: row.entityType,
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
  }
}
