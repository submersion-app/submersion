import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/data/equipment_location_sql.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';

/// Each item's location log (v268). Writes never touch the `equipment` row
/// (#1769: a child change does not re-stamp its parent); each move carries
/// its own clock.
class EquipmentLocationMoveRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  static const String entity = 'equipmentLocationMoves';

  /// Emits when a move is written or removed, here or by a sync. Readers
  /// that show a place's name also watch the places, so a rename or delete
  /// refreshes them once, not twice.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.equipmentLocationMoves));

  /// [equipmentId]'s moves, newest first.
  Future<List<EquipmentLocationMove>> getMovesFor(String equipmentId) async {
    final rows =
        await (_db.select(_db.equipmentLocationMoves)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.movedAt),
                (t) => OrderingTerm.desc(t.createdAt),
                (t) => OrderingTerm.desc(t.id),
              ]))
            .get();
    return rows.map(_toDomain).toList();
  }

  /// Every item with at least one move, to its current location id (null
  /// when cleared or the place is gone). An item with no moves is absent.
  Future<Map<String, String?>> getCurrentLocationIds() async {
    final rows = await _db
        .customSelect(
          'SELECT e.id AS equipment_id, ${currentLocationIdSql('e.id')} '
          'AS location_id FROM equipment e WHERE EXISTS '
          '(SELECT 1 FROM equipment_location_moves x '
          'WHERE x.equipment_id = e.id)',
          readsFrom: {_db.equipment, _db.equipmentLocationMoves},
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('equipment_id'): r.read<String?>('location_id'),
    };
  }

  /// One move per distinct item in [equipmentIds], all to [locationId]
  /// (null clears the location) at [movedAt]. Returns the moves written.
  Future<List<EquipmentLocationMove>> recordMoves({
    required Iterable<String> equipmentIds,
    required String? locationId,
    required DateTime movedAt,
    String note = '',
  }) async {
    final ids = equipmentIds.toSet().toList();
    if (ids.isEmpty) return const [];
    final trimmedNote = note.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = [
      for (final equipmentId in ids)
        EquipmentLocationMovesCompanion.insert(
          id: _uuid.v4(),
          equipmentId: equipmentId,
          locationId: Value(locationId),
          movedAt: movedAt.millisecondsSinceEpoch,
          note: Value(trimmedNote),
          createdAt: now,
        ),
    ];
    await _db.transaction(() async {
      await _db.batch((b) => b.insertAll(_db.equipmentLocationMoves, rows));
      for (final r in rows) {
        await _markPending(r.id.value, now);
      }
    });
    SyncEventBus.notifyLocalChange();
    return [
      for (final r in rows)
        EquipmentLocationMove(
          id: r.id.value,
          equipmentId: r.equipmentId.value,
          locationId: locationId,
          movedAt: movedAt,
          note: trimmedNote,
          createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        ),
    ];
  }

  /// Rewrites one move's place, date and note, restamping its clock.
  Future<void> updateMove(EquipmentLocationMove move) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // One transaction, so an edit is never kept without its sync mark.
    await _db.transaction(() async {
      await (_db.update(
        _db.equipmentLocationMoves,
      )..where((t) => t.id.equals(move.id))).write(
        EquipmentLocationMovesCompanion(
          locationId: Value(move.locationId),
          movedAt: Value(move.movedAt.millisecondsSinceEpoch),
          note: Value(move.note.trim()),
        ),
      );
      // A literal entity type: child_write_restamps_test reads it to know
      // this mark restamps the row just updated.
      await _syncRepository.markRecordPending(
        entityType: 'equipmentLocationMoves',
        recordId: move.id,
        localUpdatedAt: now,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes one move and tombstones it; the current location recomputes.
  Future<void> deleteMove(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.equipmentLocationMoves,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: entity, recordId: id);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes and tombstones [equipmentId]'s moves, for an item delete.
  /// Cascades write no tombstones, so a peer would otherwise keep them.
  /// Runs inside the caller's transaction.
  Future<void> deleteForEquipment(String equipmentId) async {
    final ids =
        await (_db.selectOnly(_db.equipmentLocationMoves)
              ..addColumns([_db.equipmentLocationMoves.id])
              ..where(
                _db.equipmentLocationMoves.equipmentId.equals(equipmentId),
              ))
            .map((r) => r.read(_db.equipmentLocationMoves.id)!)
            .get();
    if (ids.isEmpty) return;
    await (_db.delete(
      _db.equipmentLocationMoves,
    )..where((t) => t.equipmentId.equals(equipmentId))).go();
    await _syncRepository.logDeletions(entityType: entity, recordIds: ids);
  }

  /// Every part of [equipmentIds], transitively: assembly components and
  /// installed children, to each part's status. Retired, sold and wanted
  /// parts are left out (they are not with the item), though the walk goes
  /// on through them to any live part inside; so is anything in
  /// [equipmentIds] itself.
  Future<Map<String, EquipmentStatus>> partsOf(
    Iterable<String> equipmentIds,
  ) async {
    final seen = equipmentIds.toSet();
    final parts = <String, EquipmentStatus>{};
    var frontier = seen.toList();
    while (frontier.isNotEmpty) {
      final next = <String>[];
      for (final chunk in _chunks(frontier)) {
        final ph = List.filled(chunk.length, '?').join(', ');
        final rows = await _db
            .customSelect(
              'SELECT e.id AS id, e.status AS status FROM equipment e WHERE '
              'e.id IN (SELECT component_equipment_id FROM '
              'equipment_components WHERE parent_equipment_id IN ($ph)) '
              'OR e.parent_equipment_id IN ($ph)',
              variables: [
                for (final id in [...chunk, ...chunk]) Variable<String>(id),
              ],
            )
            .get();
        for (final r in rows) {
          final id = r.read<String>('id');
          if (!seen.add(id)) continue;
          next.add(id);
          final status = _statusOf(r.read<String>('status'));
          if (status == EquipmentStatus.retired ||
              status == EquipmentStatus.sold ||
              status == EquipmentStatus.wanted) {
            continue;
          }
          parts[id] = status;
        }
      }
      frontier = next;
    }
    return parts;
  }

  /// Bound twice per query, so half SQLite's 999-variable limit.
  static Iterable<List<String>> _chunks(List<String> ids) sync* {
    const size = 400;
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
  }

  static EquipmentStatus _statusOf(String name) {
    for (final s in EquipmentStatus.values) {
      if (s.name == name) return s;
    }
    return EquipmentStatus.active;
  }

  Future<void> _markPending(String id, int now) => _syncRepository
      .markRecordPending(entityType: entity, recordId: id, localUpdatedAt: now);

  EquipmentLocationMove _toDomain(EquipmentLocationMoveRow r) =>
      EquipmentLocationMove(
        id: r.id,
        equipmentId: r.equipmentId,
        locationId: r.locationId,
        movedAt: DateTime.fromMillisecondsSinceEpoch(r.movedAt),
        note: r.note,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
      );
}
