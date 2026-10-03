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
import 'package:submersion/features/equipment/domain/services/transmitter_transfer_clash.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

export 'package:submersion/features/equipment/data/services/equipment_transfer_models.dart';

/// Changes equipment ownership between diver profiles (issue #2852). The
/// only writer of `equipment.diver_id` after creation, apart from diver
/// merge and sync apply. Profile deletion hands kept gear over through
/// [transferUnitInTransaction].
class EquipmentTransferService {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  /// Transmitters moved by [transferUnitInTransaction] since the last
  /// [takeMovedTransmitters], whose dives are rescanned after the commit.
  final List<String> _movedTransmitters = [];

  /// What [transfer] would do, for the dialog: the expanded unit, the
  /// picked items [actingDiverId] does not own, and the linked dive
  /// computers and transmitters, with clashes against [toDiverId]'s
  /// transmitters when a target is given.
  Future<EquipmentTransferPreview> preview({
    required List<String> equipmentIds,
    required String actingDiverId,
    String? toDiverId,
  }) async {
    final graph = await loadGraph();
    final picked = equipmentIds.toSet();
    final units = transferUnits(graph, picked, ownerId: actingDiverId);
    final unitIds = {for (final u in units) ...u}.toList()..sort();
    final computers = await _linkedComputers(unitIds, actingDiverId);
    final transmitters = await _linkedTransmitters(unitIds, actingDiverId);
    final targetKeys = toDiverId == null
        ? const <TransmitterKey>[]
        : await _transmitterKeysOf(toDiverId);
    return EquipmentTransferPreview(
      unitIds: unitIds,
      skippedNotOwned: picked.where((id) => !unitIds.contains(id)).length,
      computers: [
        for (final c in computers) TransferRegistryRow(id: c.id, label: c.name),
      ],
      transmitters: [
        for (final t in transmitters)
          TransferRegistryRow(
            id: t.id,
            label: t.label,
            clashes: transmitterClashes(_keyOf(t), targetKeys),
          ),
      ],
    );
  }

  /// The units of [diverId]'s gear another profile needs, each with its
  /// heir: the profile holding the unit's earliest share, else the owner of
  /// the most recent other-profile dive that uses any item of the unit
  /// through its gear list or a tank's cylinder or regulator. A unit with
  /// neither is not kept. Read-only, so safe inside a transaction.
  Future<List<KeptUnit>> keptUnitsForDiver(String diverId) async {
    final graph = await loadGraph();
    final owned = [
      for (final e in graph.ownerOf.entries)
        if (e.value == diverId) e.key,
    ]..sort();
    final kept = <KeptUnit>[];
    for (final unit in transferUnits(graph, owned, ownerId: diverId)) {
      final heir = await _heirFor(unit.toList(), diverId);
      if (heir != null) kept.add(KeptUnit(unit: unit, heirId: heir));
    }
    return kept;
  }

  /// How many items [keptUnitsForDiver] would keep, for the delete
  /// confirmation.
  Future<int> keptEquipmentCount(String diverId) async {
    var count = 0;
    for (final k in await keptUnitsForDiver(diverId)) {
      count += k.unit.length;
    }
    return count;
  }

  Future<String?> _heirFor(List<String> unit, String deleted) async {
    final marks = List.filled(unit.length, '?').join(', ');
    final ids = [for (final id in unit) Variable.withString(id)];
    final share = await _db
        .customSelect(
          'SELECT diver_id FROM equipment_shares '
          'WHERE equipment_id IN ($marks) AND diver_id != ? '
          'ORDER BY created_at ASC, id ASC LIMIT 1',
          variables: [...ids, Variable.withString(deleted)],
        )
        .getSingleOrNull();
    if (share != null) return share.read<String>('diver_id');
    final dive = await _db
        .customSelect(
          'SELECT d.diver_id FROM dives d '
          'WHERE d.diver_id IS NOT NULL AND d.diver_id != ? AND d.id IN ('
          'SELECT dive_id FROM dive_equipment WHERE equipment_id IN ($marks) '
          'UNION SELECT dive_id FROM dive_tanks '
          'WHERE equipment_id IN ($marks) '
          'OR regulator_equipment_id IN ($marks)) '
          'ORDER BY COALESCE(d.entry_time, d.dive_date_time) DESC, d.id ASC '
          'LIMIT 1',
          variables: [Variable.withString(deleted), ...ids, ...ids, ...ids],
        )
        .getSingleOrNull();
    return dive?.read<String>('diver_id');
  }

  /// Transmitters moved since the last call, for a caller that ran
  /// [transferUnitInTransaction] itself and rescans after its commit.
  List<String> takeMovedTransmitters() {
    final ids = List<String>.of(_movedTransmitters);
    _movedTransmitters.clear();
    return ids;
  }

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
    _movedTransmitters.clear();
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
    final moved = takeMovedTransmitters();
    if (moved.isNotEmpty) {
      await TransmitterRepository().rescanDivesForTransmitters(moved);
    }
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
    final registry = moveRegistry
        ? await _moveRegistry(ids, from: fromDiverId, to: toDiverId, now: now)
        : const EquipmentTransferResult();
    return EquipmentTransferResult(itemsMoved: ids.length) + registry;
  }

  /// Moves the unit's dive computers and transmitters, leaving a
  /// transmitter that clashes with one the target already has.
  Future<EquipmentTransferResult> _moveRegistry(
    List<String> unitIds, {
    required String from,
    required String to,
    required int now,
  }) async {
    final computers = await _linkedComputers(unitIds, from);
    for (final c in computers) {
      await (_db.update(
        _db.diveComputers,
      )..where((t) => t.id.equals(c.id))).write(
        DiveComputersCompanion(diverId: Value(to), updatedAt: Value(now)),
      );
      await _markPending('diveComputers', c.id, now);
    }
    final targetKeys = await _transmitterKeysOf(to);
    var moved = 0;
    var kept = 0;
    for (final t in await _linkedTransmitters(unitIds, from)) {
      final key = _keyOf(t);
      if (transmitterClashes(key, targetKeys)) {
        kept++;
        continue;
      }
      await (_db.update(
        _db.transmitters,
      )..where((r) => r.id.equals(t.id))).write(
        TransmittersCompanion(diverId: Value(to), updatedAt: Value(now)),
      );
      await _markPending('transmitters', t.id, now);
      targetKeys.add(key);
      _movedTransmitters.add(t.id);
      moved++;
    }
    return EquipmentTransferResult(
      computersMoved: computers.length,
      transmittersMoved: moved,
      transmittersKept: kept,
    );
  }

  Future<List<DiveComputer>> _linkedComputers(
    List<String> unitIds,
    String owner,
  ) async => [
    for (final chunk in seriesIdChunks(unitIds))
      ...await (_db.select(_db.diveComputers)
            ..where((t) => t.equipmentId.isIn(chunk) & t.diverId.equals(owner)))
          .get(),
  ];

  Future<List<TransmitterRow>> _linkedTransmitters(
    List<String> unitIds,
    String owner,
  ) async {
    final byId = <String, TransmitterRow>{};
    for (final chunk in seriesIdChunks(unitIds)) {
      final rows =
          await (_db.select(_db.transmitters)..where(
                (t) =>
                    t.diverId.equals(owner) &
                    (t.equipmentId.isIn(chunk) |
                        t.transmitterEquipmentId.isIn(chunk)),
              ))
              .get();
      for (final r in rows) {
        byId[r.id] = r;
      }
    }
    final rows = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return rows;
  }

  /// A growable list: [_moveRegistry] adds each moved transmitter so two
  /// moving transmitters are checked against each other too.
  Future<List<TransmitterKey>> _transmitterKeysOf(String diverId) async => [
    for (final r in await (_db.select(
      _db.transmitters,
    )..where((t) => t.diverId.equals(diverId))).get())
      _keyOf(r),
  ];

  TransmitterKey _keyOf(TransmitterRow r) => (
    id: r.id,
    serial: r.transmitterSerial,
    diveComputerId: r.diveComputerId,
    channelIndex: r.channelIndex,
  );

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
