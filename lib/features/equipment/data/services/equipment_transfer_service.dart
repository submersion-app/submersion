import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_models.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/services/transfer_unit.dart';

export 'package:submersion/features/equipment/data/services/equipment_transfer_models.dart';

/// Changes equipment ownership between diver profiles (issue #2852). The
/// only writer of `equipment.diver_id` after creation, apart from diver
/// merge and sync apply. Profile deletion hands kept gear over through
/// [transferUnitInTransaction].
class EquipmentTransferService {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  /// Every item's owner and host and every assembly edge. Libraries hold a
  /// few hundred items, so one read beats walking the links query by query.
  Future<TransferUnitGraph> loadGraph() async {
    final items = await _db.select(_db.equipment).get();
    final edges = await _db.select(_db.equipmentComponents).get();
    return TransferUnitGraph(
      ownerOf: {for (final r in items) r.id: r.diverId},
      hostOf: {for (final r in items) r.id: ?r.parentEquipmentId},
      componentEdges: [
        for (final e in edges)
          (parent: e.parentEquipmentId, component: e.componentEquipmentId),
      ],
    );
  }

  /// Transfers every unit [equipmentIds] expands to from [actingDiverId] to
  /// [toDiverId] in one transaction. Items [actingDiverId] does not own are
  /// skipped. A target that does not exist fails the foreign key and rolls
  /// the whole transfer back.
  Future<EquipmentTransferResult> transfer({
    required List<String> equipmentIds,
    required String toDiverId,
    required String actingDiverId,
    bool keepAccess = true,
    bool moveRegistry = true,
  }) async {
    if (toDiverId == actingDiverId) return const EquipmentTransferResult();
    final result = await _db.transaction(() async {
      final graph = await loadGraph();
      final picked = equipmentIds.toSet();
      final units = transferUnits(graph, picked, ownerId: actingDiverId);
      final covered = {for (final u in units) ...u};
      var total = EquipmentTransferResult(
        skippedNotOwned: picked.where((id) => !covered.contains(id)).length,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final unit in units) {
        total += await transferUnitInTransaction(
          unit: unit,
          fromDiverId: actingDiverId,
          toDiverId: toDiverId,
          keepAccess: keepAccess,
          moveRegistry: moveRegistry,
          now: now,
        );
      }
      return total;
    });
    SyncEventBus.notifyLocalChange();
    return result;
  }

  /// Moves [unit] from [fromDiverId] to [toDiverId]. Runs inside the
  /// caller's transaction and notifies nobody.
  Future<EquipmentTransferResult> transferUnitInTransaction({
    required Set<String> unit,
    required String fromDiverId,
    required String toDiverId,
    required bool keepAccess,
    required bool moveRegistry,
    required int now,
  }) async {
    if (unit.isEmpty || fromDiverId == toDiverId) {
      return const EquipmentTransferResult();
    }
    final ids = unit.toList()..sort();
    for (final chunk in seriesIdChunks(ids)) {
      await (_db.update(_db.equipment)..where((t) => t.id.isIn(chunk))).write(
        EquipmentCompanion(diverId: Value(toDiverId), updatedAt: Value(now)),
      );
    }
    for (final id in ids) {
      await _markPending('equipment', id, now);
    }
    await _fixUpShares(
      ids,
      from: fromDiverId,
      to: toDiverId,
      keepAccess: keepAccess,
      now: now,
    );
    final events = [
      for (final id in ids)
        EquipmentOwnershipEventsCompanion.insert(
          id: _uuid.v4(),
          equipmentId: id,
          kind: EquipmentOwnershipEventKind.transferred.name,
          fromDiverId: Value(fromDiverId),
          toDiverId: Value(toDiverId),
          occurredAt: now,
        ),
    ];
    await _db.batch((b) => b.insertAll(_db.equipmentOwnershipEvents, events));
    for (final e in events) {
      await _markPending(
        EquipmentShareRepository.eventsEntity,
        e.id.value,
        now,
      );
    }
    return EquipmentTransferResult(itemsMoved: ids.length);
  }

  /// The new owner's share rows go (it owns the items now). The old owner
  /// gets a new share row when [keepAccess] is true. Shares apply
  /// insert-only on peers, so a row is never repointed in place, and the
  /// fix-up writes no `shared` or `unshared` events: the `transferred`
  /// event explains it.
  Future<void> _fixUpShares(
    List<String> ids, {
    required String from,
    required String to,
    required bool keepAccess,
    required int now,
  }) async {
    final targetShares = <String>[];
    for (final chunk in seriesIdChunks(ids)) {
      targetShares.addAll(
        await (_db.selectOnly(_db.equipmentShares)
              ..addColumns([_db.equipmentShares.id])
              ..where(
                _db.equipmentShares.equipmentId.isIn(chunk) &
                    _db.equipmentShares.diverId.equals(to),
              ))
            .map((r) => r.read(_db.equipmentShares.id)!)
            .get(),
      );
    }
    if (targetShares.isNotEmpty) {
      for (final chunk in seriesIdChunks(targetShares)) {
        await (_db.delete(
          _db.equipmentShares,
        )..where((t) => t.id.isIn(chunk))).go();
      }
      await _syncRepository.logDeletions(
        entityType: EquipmentShareRepository.sharesEntity,
        recordIds: targetShares,
      );
    }
    if (!keepAccess) return;
    final added = [
      for (final id in ids)
        EquipmentSharesCompanion.insert(
          id: _uuid.v4(),
          equipmentId: id,
          diverId: from,
          createdAt: now,
        ),
    ];
    await _db.batch((b) => b.insertAll(_db.equipmentShares, added));
    for (final s in added) {
      await _markPending(
        EquipmentShareRepository.sharesEntity,
        s.id.value,
        now,
      );
    }
  }

  Future<void> _markPending(String entityType, String id, int now) =>
      _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
}
