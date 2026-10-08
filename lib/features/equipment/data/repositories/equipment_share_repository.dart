import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_share.dart';

/// Counts from one share operation, for the UI's partial-result messages.
class EquipmentShareResult {
  final int added;
  final int removed;

  /// Items skipped because the acting diver does not own them.
  final int skippedNotOwned;

  /// (item, profile) pairs refused: the profile owns the item or no longer
  /// exists.
  final int rejected;

  /// Items that gained at least one share, for "Shared N items" messages
  /// ([added] counts (item, profile) pairs).
  final int itemsChanged;

  const EquipmentShareResult({
    this.added = 0,
    this.removed = 0,
    this.skippedNotOwned = 0,
    this.rejected = 0,
    this.itemsChanged = 0,
  });

  EquipmentShareResult operator +(EquipmentShareResult other) =>
      EquipmentShareResult(
        added: added + other.added,
        removed: removed + other.removed,
        skippedNotOwned: skippedNotOwned + other.skippedNotOwned,
        rejected: rejected + other.rejected,
        itemsChanged: itemsChanged + other.itemsChanged,
      );
}

/// Equipment shares and the share/ownership event log (issue #2046).
///
/// Only an item's owner changes its shares. Every added share writes a
/// `shared` event and every removed share an `unshared` event, in the same
/// transaction. Writes never touch the `equipment` row (#1769: a child change
/// does not re-stamp its parent).
class EquipmentShareRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  static const String sharesEntity = 'equipmentShares';
  static const String eventsEntity = 'equipmentOwnershipEvents';

  /// Emits when a share or an event is written or removed.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.equipmentShares,
      _db.equipmentOwnershipEvents,
    ]),
  );

  Future<List<EquipmentShare>> getSharesFor(String equipmentId) async =>
      (await getSharesForItems([equipmentId]))[equipmentId] ?? const [];

  /// Shares keyed by item id; an item without shares is absent.
  Future<Map<String, List<EquipmentShare>>> getSharesForItems(
    Iterable<String> equipmentIds,
  ) async {
    final ids = equipmentIds.toSet().toList();
    final result = <String, List<EquipmentShare>>{};
    for (final chunk in seriesIdChunks(ids)) {
      final rows =
          await (_db.select(_db.equipmentShares)
                ..where((t) => t.equipmentId.isIn(chunk))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();
      for (final r in rows) {
        (result[r.equipmentId] ??= []).add(_toShare(r));
      }
    }
    return result;
  }

  /// [equipmentId]'s events, oldest first. Kinds this build does not know
  /// are skipped.
  Future<List<EquipmentOwnershipEvent>> getEventsFor(String equipmentId) async {
    final rows =
        await (_db.select(_db.equipmentOwnershipEvents)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.occurredAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [
      for (final r in rows)
        if (EquipmentOwnershipEventKind.fromName(r.kind) case final kind?)
          EquipmentOwnershipEvent(
            id: r.id,
            equipmentId: r.equipmentId,
            kind: kind,
            fromDiverId: r.fromDiverId,
            toDiverId: r.toDiverId,
            occurredAt: DateTime.fromMillisecondsSinceEpoch(r.occurredAt),
          ),
    ];
  }

  /// Shares every item in [equipmentIds] that [actingDiverId] owns with each
  /// of [diverIds]. Existing pairs are left alone.
  Future<EquipmentShareResult> shareMany({
    required List<String> equipmentIds,
    required List<String> diverIds,
    required String actingDiverId,
  }) async {
    final result = await _db.transaction(() async {
      final requested = equipmentIds.toSet();
      final owners = await _ownersOf(requested);
      final owned = [
        for (final id in requested)
          if (owners[id] == actingDiverId) id,
      ];
      final result = await _addShares(
        owned,
        diverIds.toSet(),
        owner: actingDiverId,
        now: DateTime.now().millisecondsSinceEpoch,
      );
      return result +
          EquipmentShareResult(
            skippedNotOwned: requested.length - owned.length,
          );
    });
    SyncEventBus.notifyLocalChange();
    return result;
  }

  /// Makes [equipmentId]'s shares exactly [diverIds], for the owner's
  /// profile checklist.
  Future<EquipmentShareResult> setShares({
    required String equipmentId,
    required Set<String> diverIds,
    required String actingDiverId,
  }) async {
    final result = await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final owner = (await _ownersOf([equipmentId]))[equipmentId];
      if (owner != actingDiverId) {
        return const EquipmentShareResult(skippedNotOwned: 1);
      }
      final current = {
        for (final s in await getSharesFor(equipmentId)) s.diverId,
      };
      final removed = await _removeShares(
        equipmentId,
        current.difference(diverIds),
        owner: actingDiverId,
        now: now,
      );
      final added = await _addShares(
        [equipmentId],
        diverIds.difference(current),
        owner: actingDiverId,
        now: now,
      );
      return removed + added;
    });
    SyncEventBus.notifyLocalChange();
    return result;
  }

  Future<EquipmentShareResult> unshare({
    required String equipmentId,
    required String diverId,
    required String actingDiverId,
  }) async {
    final result = await _db.transaction(() async {
      final owner = (await _ownersOf([equipmentId]))[equipmentId];
      if (owner != actingDiverId) {
        return const EquipmentShareResult(skippedNotOwned: 1);
      }
      return _removeShares(
        equipmentId,
        {diverId},
        owner: actingDiverId,
        now: DateTime.now().millisecondsSinceEpoch,
      );
    });
    SyncEventBus.notifyLocalChange();
    return result;
  }

  /// Deletes and tombstones every share and event of [equipmentId], for an
  /// item delete. Cascades write no tombstones, so the item's delete calls
  /// this first and every peer drops them too. Runs inside the caller's
  /// transaction.
  Future<void> deleteForEquipment(String equipmentId) async {
    final shareIds =
        await (_db.selectOnly(_db.equipmentShares)
              ..addColumns([_db.equipmentShares.id])
              ..where(_db.equipmentShares.equipmentId.equals(equipmentId)))
            .map((r) => r.read(_db.equipmentShares.id)!)
            .get();
    final eventIds =
        await (_db.selectOnly(_db.equipmentOwnershipEvents)
              ..addColumns([_db.equipmentOwnershipEvents.id])
              ..where(
                _db.equipmentOwnershipEvents.equipmentId.equals(equipmentId),
              ))
            .map((r) => r.read(_db.equipmentOwnershipEvents.id)!)
            .get();
    await (_db.delete(
      _db.equipmentShares,
    )..where((t) => t.equipmentId.equals(equipmentId))).go();
    await (_db.delete(
      _db.equipmentOwnershipEvents,
    )..where((t) => t.equipmentId.equals(equipmentId))).go();
    await _syncRepository.logDeletions(
      entityType: sharesEntity,
      recordIds: shareIds,
    );
    await _syncRepository.logDeletions(
      entityType: eventsEntity,
      recordIds: eventIds,
    );
  }

  /// Shares every item [ownerId] owns with each of [diverIds], for Settings >
  /// Shared data.
  Future<EquipmentShareResult> shareAllForDiver({
    required String ownerId,
    required List<String> diverIds,
  }) async {
    final owned =
        await (_db.selectOnly(_db.equipment)
              ..addColumns([_db.equipment.id])
              ..where(_db.equipment.diverId.equals(ownerId)))
            .map((r) => r.read(_db.equipment.id)!)
            .get();
    if (owned.isEmpty) return const EquipmentShareResult();
    return shareMany(
      equipmentIds: owned,
      diverIds: diverIds,
      actingDiverId: ownerId,
    );
  }

  /// Shares each of [ownedIds] (all owned by [owner]) with each of
  /// [diverIds], writing the new shares and their `shared` events in one
  /// batch. A pair that already exists is skipped; a pair naming the owner or
  /// an unknown profile is rejected. Runs inside the caller's transaction.
  Future<EquipmentShareResult> _addShares(
    List<String> ownedIds,
    Set<String> diverIds, {
    required String owner,
    required int now,
  }) async {
    if (ownedIds.isEmpty || diverIds.isEmpty) {
      return const EquipmentShareResult();
    }
    final known = await _existingDivers(diverIds);
    final targets = {
      for (final d in diverIds)
        if (d != owner && known.contains(d)) d,
    };
    final rejected = ownedIds.length * (diverIds.length - targets.length);
    final existing = await _existingPairs(ownedIds);
    final shares = <EquipmentSharesCompanion>[];
    final events = <EquipmentOwnershipEventsCompanion>[];
    var itemsChanged = 0;
    for (final equipmentId in ownedIds) {
      final before = shares.length;
      for (final diverId in targets) {
        if (existing[equipmentId]?.contains(diverId) ?? false) continue;
        shares.add(
          EquipmentSharesCompanion.insert(
            id: _uuid.v4(),
            equipmentId: equipmentId,
            diverId: diverId,
            createdAt: now,
          ),
        );
        events.add(
          _event(
            equipmentId,
            EquipmentOwnershipEventKind.shared,
            from: owner,
            to: diverId,
            now: now,
          ),
        );
      }
      if (shares.length > before) itemsChanged++;
    }
    if (shares.isNotEmpty) {
      await _db.batch((b) {
        b.insertAll(_db.equipmentShares, shares);
        b.insertAll(_db.equipmentOwnershipEvents, events);
      });
      for (final r in shares) {
        await _markPending(sharesEntity, r.id.value, now);
      }
      for (final r in events) {
        await _markPending(eventsEntity, r.id.value, now);
      }
    }
    return EquipmentShareResult(
      added: shares.length,
      rejected: rejected,
      itemsChanged: itemsChanged,
    );
  }

  /// Removes [equipmentId]'s shares with [diverIds], tombstoning each row and
  /// logging one `unshared` event per profile that had a share. Runs inside
  /// the caller's transaction.
  Future<EquipmentShareResult> _removeShares(
    String equipmentId,
    Set<String> diverIds, {
    required String owner,
    required int now,
  }) async {
    if (diverIds.isEmpty) return const EquipmentShareResult();
    Expression<bool> where($EquipmentSharesTable t) =>
        t.equipmentId.equals(equipmentId) & t.diverId.isIn(diverIds);
    final rows = await (_db.select(_db.equipmentShares)..where(where)).get();
    if (rows.isEmpty) return const EquipmentShareResult();
    await (_db.delete(_db.equipmentShares)..where(where)).go();
    await _syncRepository.logDeletions(
      entityType: sharesEntity,
      recordIds: [for (final r in rows) r.id],
    );
    final unshared = {for (final r in rows) r.diverId};
    final events = [
      for (final diverId in unshared)
        _event(
          equipmentId,
          EquipmentOwnershipEventKind.unshared,
          from: owner,
          to: diverId,
          now: now,
        ),
    ];
    await _db.batch((b) => b.insertAll(_db.equipmentOwnershipEvents, events));
    for (final r in events) {
      await _markPending(eventsEntity, r.id.value, now);
    }
    return EquipmentShareResult(removed: unshared.length);
  }

  EquipmentOwnershipEventsCompanion _event(
    String equipmentId,
    EquipmentOwnershipEventKind kind, {
    required String? from,
    required String? to,
    required int now,
  }) => EquipmentOwnershipEventsCompanion.insert(
    id: _uuid.v4(),
    equipmentId: equipmentId,
    kind: kind.name,
    fromDiverId: Value(from),
    toDiverId: Value(to),
    occurredAt: now,
  );

  Future<void> _markPending(String entityType, String id, int now) =>
      _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );

  /// The profiles each of [equipmentIds] is already shared with.
  Future<Map<String, Set<String>>> _existingPairs(
    List<String> equipmentIds,
  ) async {
    final pairs = <String, Set<String>>{};
    for (final chunk in seriesIdChunks(equipmentIds)) {
      final rows = await (_db.select(
        _db.equipmentShares,
      )..where((t) => t.equipmentId.isIn(chunk))).get();
      for (final r in rows) {
        (pairs[r.equipmentId] ??= {}).add(r.diverId);
      }
    }
    return pairs;
  }

  Future<Map<String, String?>> _ownersOf(Iterable<String> equipmentIds) async {
    final ids = equipmentIds.toSet().toList();
    final owners = <String, String?>{};
    for (final chunk in seriesIdChunks(ids)) {
      final rows = await (_db.select(
        _db.equipment,
      )..where((t) => t.id.isIn(chunk))).get();
      for (final r in rows) {
        owners[r.id] = r.diverId;
      }
    }
    return owners;
  }

  Future<Set<String>> _existingDivers(Iterable<String> diverIds) async {
    final ids = diverIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await (_db.select(
      _db.divers,
    )..where((t) => t.id.isIn(ids))).get();
    return {for (final r in rows) r.id};
  }

  EquipmentShare _toShare(EquipmentShareRow r) => EquipmentShare(
    id: r.id,
    equipmentId: r.equipmentId,
    diverId: r.diverId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
  );
}
