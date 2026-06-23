import 'package:drift/drift.dart';
import 'package:submersion/core/constants/enums.dart' as en;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as de;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as dw;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as se;

/// Orchestrates a bulk edit across repositories in a single transaction.
///
/// `DiveTank`, `DiveWeight`, `Sighting` referenced unprefixed here are the Drift
/// row classes (from database.dart); the `de`/`dw`/`en`/`se` prefixes are the
/// domain entities/enums.
class BulkDiveEditService {
  BulkDiveEditService(this._diveRepo, this._buddyRepo, this._speciesRepo);

  final DiveRepository _diveRepo;
  final BuddyRepository _buddyRepo;
  final SpeciesRepository _speciesRepo;
  final _sync = SyncRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  /// Apply [req] to every dive in [req.diveIds] inside one transaction,
  /// capturing the prior state first. Fires a single local-change notification.
  Future<BulkEditSnapshot> apply(BulkEditRequest req) async {
    final ids = req.diveIds;
    if (ids.isEmpty) {
      return const BulkEditSnapshot(priorDiveRows: []);
    }

    // Capture prior state before mutating (reads outside the transaction).
    final priorDiveRows = await (_db.select(
      _db.dives,
    )..where((t) => t.id.isIn(ids))).get();

    Map<String, List<String>>? priorTagIds;
    Map<String, List<String>>? priorEquipmentIds;
    Map<String, List<BuddyWithRole>>? priorBuddies;
    Map<String, List<DiveTank>>? priorTanks;
    Map<String, List<DiveWeight>>? priorWeights;
    Map<String, List<Sighting>>? priorSightings;

    for (final op in req.ops) {
      switch (op) {
        case TagsOp():
          final rows = await (_db.select(
            _db.diveTags,
          )..where((t) => t.diveId.isIn(ids))).get();
          priorTagIds = {for (final id in ids) id: <String>[]};
          for (final r in rows) {
            priorTagIds[r.diveId]!.add(r.tagId);
          }
        case EquipmentOp():
          final rows = await (_db.select(
            _db.diveEquipment,
          )..where((t) => t.diveId.isIn(ids))).get();
          priorEquipmentIds = {for (final id in ids) id: <String>[]};
          for (final r in rows) {
            priorEquipmentIds[r.diveId]!.add(r.equipmentId);
          }
        case BuddiesOp():
          priorBuddies = {
            for (final id in ids) id: await _buddyRepo.getBuddiesForDive(id),
          };
        case TanksOp():
          final rows = await (_db.select(
            _db.diveTanks,
          )..where((t) => t.diveId.isIn(ids))).get();
          priorTanks = {for (final id in ids) id: <DiveTank>[]};
          for (final r in rows) {
            priorTanks[r.diveId]!.add(r);
          }
        case WeightsOp():
          final rows = await (_db.select(
            _db.diveWeights,
          )..where((t) => t.diveId.isIn(ids))).get();
          priorWeights = {for (final id in ids) id: <DiveWeight>[]};
          for (final r in rows) {
            priorWeights[r.diveId]!.add(r);
          }
        case SightingsOp():
          final rows = await (_db.select(
            _db.sightings,
          )..where((t) => t.diveId.isIn(ids))).get();
          priorSightings = {for (final id in ids) id: <Sighting>[]};
          for (final r in rows) {
            priorSightings[r.diveId]!.add(r);
          }
      }
    }

    await _db.transaction(() async {
      if (req.hasScalarChanges) {
        await _diveRepo.bulkUpdateFields(ids, req.scalars);
      }
      if (req.notesAppend != null && req.notesAppend!.isNotEmpty) {
        await _diveRepo.bulkAppendNotes(ids, req.notesAppend!);
      }
      for (final op in req.ops) {
        await _applyOp(ids, op);
      }
    });

    SyncEventBus.notifyLocalChange();

    return BulkEditSnapshot(
      priorDiveRows: priorDiveRows,
      priorTagIds: priorTagIds,
      priorEquipmentIds: priorEquipmentIds,
      priorBuddies: priorBuddies,
      priorTanks: priorTanks,
      priorWeights: priorWeights,
      priorSightings: priorSightings,
    );
  }

  /// Reverse a prior [apply]: restore each dive's prior scalar columns and the
  /// prior membership of every touched collection. One transaction, one notify.
  Future<void> undo(BulkEditSnapshot snapshot) async {
    if (snapshot.priorDiveRows.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ids = snapshot.priorDiveRows.map((r) => r.id).toList();

    await _db.transaction(() async {
      // Restore scalar columns from the full prior row (nullToAbsent: false so
      // prior NULLs are restored), with a fresh updatedAt so the undo wins LWW.
      for (final row in snapshot.priorDiveRows) {
        await (_db.update(_db.dives)..where((t) => t.id.equals(row.id))).write(
          row.toCompanion(false).copyWith(updatedAt: Value(now)),
        );
        await _sync.markRecordPending(
          entityType: 'dives',
          recordId: row.id,
          localUpdatedAt: now,
        );
      }

      final tags = snapshot.priorTagIds;
      if (tags != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceTags([id], tags[id] ?? const []);
        }
      }
      final equip = snapshot.priorEquipmentIds;
      if (equip != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceEquipment([id], equip[id] ?? const []);
        }
      }
      final buddies = snapshot.priorBuddies;
      if (buddies != null) {
        for (final id in ids) {
          await _buddyRepo.bulkReplaceBuddies([id], buddies[id] ?? const []);
        }
      }
      final tanks = snapshot.priorTanks;
      if (tanks != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceTanks([
            id,
          ], _tanksFromRows(tanks[id] ?? const []));
        }
      }
      final weights = snapshot.priorWeights;
      if (weights != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceWeights([
            id,
          ], _weightsFromRows(weights[id] ?? const []));
        }
      }
      final sightings = snapshot.priorSightings;
      if (sightings != null) {
        for (final id in ids) {
          await _speciesRepo.bulkReplaceSightings([
            id,
          ], _sightingsFromRows(sightings[id] ?? const []));
        }
      }
    });

    SyncEventBus.notifyLocalChange();
  }

  Future<void> _applyOp(List<String> ids, BulkCollectionOp op) async {
    switch (op) {
      case TagsOp(:final mode, :final tagIds):
        switch (mode) {
          case BulkCollectionMode.add:
            await _diveRepo.bulkAddTags(ids, tagIds);
          case BulkCollectionMode.remove:
            await _diveRepo.bulkRemoveTags(ids, tagIds);
          case BulkCollectionMode.replace:
            await _diveRepo.bulkReplaceTags(ids, tagIds);
        }
      case EquipmentOp(:final mode, :final equipmentIds):
        switch (mode) {
          case BulkCollectionMode.add:
            await _diveRepo.bulkAddEquipment(ids, equipmentIds);
          case BulkCollectionMode.remove:
            await _diveRepo.bulkRemoveEquipment(ids, equipmentIds);
          case BulkCollectionMode.replace:
            await _diveRepo.bulkReplaceEquipment(ids, equipmentIds);
        }
      case BuddiesOp(:final mode, :final buddies):
        switch (mode) {
          case BulkCollectionMode.add:
            await _buddyRepo.bulkAddBuddies(ids, buddies);
          case BulkCollectionMode.remove:
            await _buddyRepo.bulkRemoveBuddies(
              ids,
              buddies.map((b) => b.buddy.id).toList(),
            );
          case BulkCollectionMode.replace:
            await _buddyRepo.bulkReplaceBuddies(ids, buddies);
        }
      // Owned collections support only add/replace; reject remove explicitly
      // so a misconstructed op fails fast instead of silently doing an add.
      case TanksOp(:final mode, :final tanks, :final onlyIfEmpty):
        switch (mode) {
          case BulkCollectionMode.replace:
            await _diveRepo.bulkReplaceTanks(ids, tanks);
          case BulkCollectionMode.add:
            await _diveRepo.bulkAddTanks(ids, tanks, onlyIfEmpty: onlyIfEmpty);
          case BulkCollectionMode.remove:
            throw UnsupportedError(
              'Tanks support only add/replace, not remove',
            );
        }
      case WeightsOp(:final mode, :final weights):
        switch (mode) {
          case BulkCollectionMode.replace:
            await _diveRepo.bulkReplaceWeights(ids, weights);
          case BulkCollectionMode.add:
            await _diveRepo.bulkAddWeights(ids, weights);
          case BulkCollectionMode.remove:
            throw UnsupportedError(
              'Weights support only add/replace, not remove',
            );
        }
      case SightingsOp(:final mode, :final sightings):
        switch (mode) {
          case BulkCollectionMode.replace:
            await _speciesRepo.bulkReplaceSightings(ids, sightings);
          case BulkCollectionMode.add:
            await _speciesRepo.bulkAddSightings(ids, sightings);
          case BulkCollectionMode.remove:
            throw UnsupportedError(
              'Sightings support only add/replace, not remove',
            );
        }
    }
  }

  // Map Drift rows back to the domain objects the bulk-replace methods consume.
  List<de.DiveTank> _tanksFromRows(List<DiveTank> rows) => [
    for (final r in rows)
      de.DiveTank(
        id: '',
        name: r.tankName,
        volume: r.volume,
        workingPressure: r.workingPressure,
        startPressure: r.startPressure,
        endPressure: r.endPressure,
        gasMix: de.GasMix(o2: r.o2Percent, he: r.hePercent),
        role: en.TankRole.values.firstWhere(
          (e) => e.name == r.tankRole,
          orElse: () => en.TankRole.backGas,
        ),
        material: r.tankMaterial == null
            ? null
            : en.TankMaterial.values.firstWhere(
                (e) => e.name == r.tankMaterial,
                orElse: () => en.TankMaterial.aluminum,
              ),
        presetName: r.presetName,
      ),
  ];

  List<dw.DiveWeight> _weightsFromRows(List<DiveWeight> rows) => [
    for (final r in rows)
      dw.DiveWeight(
        id: '',
        diveId: '',
        weightType: en.WeightType.values.firstWhere(
          (e) => e.name == r.weightType,
          orElse: () => en.WeightType.values.first,
        ),
        amountKg: r.amountKg,
        notes: r.notes,
      ),
  ];

  List<se.Sighting> _sightingsFromRows(List<Sighting> rows) => [
    for (final r in rows)
      se.Sighting(
        id: '',
        diveId: '',
        speciesId: r.speciesId,
        speciesName: '',
        count: r.count,
        notes: r.notes,
      ),
  ];
}
