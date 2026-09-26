import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
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

  /// Ids bound per `IN (...)` list, under SQLite's 999-variable floor.
  static const int _idChunk = 900;

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
    for (var i = 0; i < ids.length; i += _idChunk) {
      final chunk = ids.sublist(i, (i + _idChunk).clamp(0, ids.length));
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
      final now = DateTime.now().millisecondsSinceEpoch;
      final owners = await _ownersOf(equipmentIds);
      final known = await _existingDivers(diverIds);
      var total = const EquipmentShareResult();
      for (final id in equipmentIds.toSet()) {
        final owner = owners[id];
        if (owner != actingDiverId) {
          total += const EquipmentShareResult(skippedNotOwned: 1);
          continue;
        }
        var itemTotal = const EquipmentShareResult();
        for (final diverId in diverIds.toSet()) {
          itemTotal += await _add(id, owner!, diverId, known, now);
        }
        total += itemTotal;
        if (itemTotal.added > 0) {
          total += const EquipmentShareResult(itemsChanged: 1);
        }
      }
      return total;
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
      final known = await _existingDivers(diverIds);
      var total = const EquipmentShareResult();
      for (final diverId in current.difference(diverIds)) {
        total += await _remove(equipmentId, owner!, diverId, now);
      }
      for (final diverId in diverIds.difference(current)) {
        total += await _add(equipmentId, owner!, diverId, known, now);
      }
      return total;
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
      return _remove(
        equipmentId,
        owner!,
        diverId,
        DateTime.now().millisecondsSinceEpoch,
      );
    });
    SyncEventBus.notifyLocalChange();
    return result;
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

  Future<EquipmentShareResult> _add(
    String equipmentId,
    String owner,
    String diverId,
    Set<String> knownDivers,
    int now,
  ) async {
    if (diverId == owner || !knownDivers.contains(diverId)) {
      return const EquipmentShareResult(rejected: 1);
    }
    final shareId = _uuid.v4();
    final inserted = await _db
        .into(_db.equipmentShares)
        .insertReturningOrNull(
          EquipmentSharesCompanion.insert(
            id: shareId,
            equipmentId: equipmentId,
            diverId: diverId,
            createdAt: now,
          ),
          onConflict: DoNothing<$EquipmentSharesTable, EquipmentShareRow>(
            target: const [],
          ),
        );
    if (inserted == null) return const EquipmentShareResult();
    final eventId = await _logEvent(
      equipmentId,
      EquipmentOwnershipEventKind.shared,
      from: owner,
      to: diverId,
      now: now,
    );
    await _markPending(sharesEntity, shareId, now);
    await _markPending(eventsEntity, eventId, now);
    return const EquipmentShareResult(added: 1);
  }

  Future<EquipmentShareResult> _remove(
    String equipmentId,
    String owner,
    String diverId,
    int now,
  ) async {
    final rows =
        await (_db.select(_db.equipmentShares)..where(
              (t) =>
                  t.equipmentId.equals(equipmentId) & t.diverId.equals(diverId),
            ))
            .get();
    if (rows.isEmpty) return const EquipmentShareResult();
    await (_db.delete(_db.equipmentShares)..where(
          (t) => t.equipmentId.equals(equipmentId) & t.diverId.equals(diverId),
        ))
        .go();
    for (final r in rows) {
      await _syncRepository.logDeletion(
        entityType: sharesEntity,
        recordId: r.id,
      );
    }
    final eventId = await _logEvent(
      equipmentId,
      EquipmentOwnershipEventKind.unshared,
      from: owner,
      to: diverId,
      now: now,
    );
    await _markPending(eventsEntity, eventId, now);
    return const EquipmentShareResult(removed: 1);
  }

  Future<String> _logEvent(
    String equipmentId,
    EquipmentOwnershipEventKind kind, {
    required String? from,
    required String? to,
    required int now,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.equipmentOwnershipEvents)
        .insert(
          EquipmentOwnershipEventsCompanion.insert(
            id: id,
            equipmentId: equipmentId,
            kind: kind.name,
            fromDiverId: Value(from),
            toDiverId: Value(to),
            occurredAt: now,
          ),
        );
    return id;
  }

  Future<void> _markPending(String entityType, String id, int now) =>
      _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );

  Future<Map<String, String?>> _ownersOf(Iterable<String> equipmentIds) async {
    final ids = equipmentIds.toSet().toList();
    final owners = <String, String?>{};
    for (var i = 0; i < ids.length; i += _idChunk) {
      final chunk = ids.sublist(i, (i + _idChunk).clamp(0, ids.length));
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
