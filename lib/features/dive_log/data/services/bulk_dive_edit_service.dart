import 'package:drift/drift.dart';
import 'package:submersion/core/constants/enums.dart' as en;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_tank_undo_writer.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as dw;
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as se;

/// Orchestrates a bulk edit across repositories in a single transaction.
///
/// `DiveTank`, `DiveWeight`, `Sighting` referenced unprefixed here are the Drift
/// row classes (from database.dart); the `dw`/`en`/`se` prefixes are the domain
/// entities/enums.
class BulkDiveEditService {
  BulkDiveEditService(this._diveRepo, this._buddyRepo, this._speciesRepo);

  final DiveRepository _diveRepo;
  final BuddyRepository _buddyRepo;
  final SpeciesRepository _speciesRepo;
  final _sync = SyncRepository();
  final _roleLinks = DiveRoleLinkRepository();
  final _tankUndo = BulkTankUndoWriter();

  AppDatabase get _db => DatabaseService.instance.database;

  /// Apply [req] to every dive in [req.diveIds] inside one transaction,
  /// capturing the prior state first. Fires a single local-change notification.
  Future<BulkEditSnapshot> apply(BulkEditRequest req) => ChangeLogScope.bulk(
    DatabaseService.instance.databaseOrNull,
    label: ChangeLogLabels.bulkEdit,
    body: () => _applyInner(req),
  );

  Future<BulkEditSnapshot> _applyInner(BulkEditRequest req) async {
    final ids = req.diveIds;
    if (ids.isEmpty) {
      return const BulkEditSnapshot(priorDiveRows: []);
    }

    // Capture prior state before mutating (reads outside the transaction).
    final priorDiveRows = await (_db.select(
      _db.dives,
    )..where((t) => t.id.isIn(ids))).get();

    Map<String, List<String>>? priorTagIds;
    Map<String, List<String>>? priorDiveTypeIds;
    Map<String, List<String>>? priorCourseIds;
    Map<String, List<GearProvenance>>? priorGear;
    Map<String, List<BuddyWithRole>>? priorBuddies;
    Map<String, List<String>>? priorDiverRoleIds;
    BulkTankUndo? tankUndo;
    List<DiveTank>? priorTankSpecRows;
    Map<String, List<DiveWeight>>? priorWeights;
    Map<String, List<Sighting>>? priorSightings;

    // Nothing is written until this loop ends, so a second op of a kind (the
    // form sends an add and a remove) would read the same rows again.
    for (final op in req.ops) {
      switch (op) {
        case TagsOp():
          if (priorTagIds != null) continue;
          final rows = await (_db.select(
            _db.diveTags,
          )..where((t) => t.diveId.isIn(ids))).get();
          priorTagIds = {for (final id in ids) id: <String>[]};
          for (final r in rows) {
            priorTagIds[r.diveId]!.add(r.tagId);
          }
        case DiveTypesOp():
          priorDiveTypeIds ??= await _priorDiveTypeIds(ids, priorDiveRows);
        // A site adds the dive types its site types stand for, so undo needs
        // them too. Unlinking adds none.
        case SiteOp(:final siteId):
          if (siteId != null) {
            priorDiveTypeIds ??= await _priorDiveTypeIds(ids, priorDiveRows);
          }
        case DiveCoursesOp():
          final current = await _diveRepo.courseIdsForDives(ids);
          priorCourseIds = {
            for (final id in ids) id: current[id] ?? const <String>[],
          };
        case EquipmentOp():
          if (priorGear != null) continue;
          final rows = await (_db.select(
            _db.diveEquipment,
          )..where((t) => t.diveId.isIn(ids))).get();
          priorGear = {for (final id in ids) id: <GearProvenance>[]};
          for (final r in rows) {
            priorGear[r.diveId]!.add(
              GearProvenance(
                equipmentId: r.equipmentId,
                viaEquipmentId: r.viaEquipmentId,
                viaSetId: r.viaSetId,
              ),
            );
          }
        // Undo needs only who was on each dive and their roles, so the lean
        // reader is enough.
        case BuddiesOp():
          priorBuddies ??= await _buddyRepo.getBuddiesForDivesInChunks(ids);
        case DiverRolesOp():
          priorDiverRoleIds = await _roleLinks.diverRoleIdsForDives(ids);
        // Captured inside the transaction, below.
        case TanksOp():
          break;
        case TankSpecsOp():
          // Flat list, not keyed by dive: the restore matches on row id.
          priorTankSpecRows = await (_db.select(
            _db.diveTanks,
          )..where((t) => t.diveId.isIn(ids))).get();
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
      // Inside the transaction, unlike the reads above: a tank a sync merge
      // lands before this point is not the edit's for undo to remove, and one
      // a replace then deletes is one for undo to put back.
      final tankOps = req.ops.whereType<TanksOp>();
      final tanksBefore = tankOps.isEmpty
          ? null
          : await _tankUndo.tankIdsOf(ids);
      // Only a replace deletes tanks, and with them what they recorded.
      if (tankOps.any((op) => op.mode == BulkCollectionMode.replace)) {
        tankUndo = await _tankUndo.captureReplaced(ids);
      }
      // The site goes first: its snap fills in water type, entry/exit and
      // dive types, and every row the diver set in this edit then lands on
      // top of it (#3657).
      for (final op in req.ops.whereType<SiteOp>()) {
        await _diveRepo.bulkSetSite(ids, op.siteId);
      }
      if (req.hasScalarChanges) {
        await _diveRepo.bulkUpdateFields(ids, req.scalars);
      }
      if (req.notesAppend != null && req.notesAppend!.isNotEmpty) {
        await _diveRepo.bulkAppendNotes(ids, req.notesAppend!);
      }
      for (final op in req.ops) {
        await _applyOp(ids, op);
      }
      if (tanksBefore != null) {
        final tanksAfter = await _tankUndo.tankIdsOf(ids);
        tankUndo = (tankUndo ?? const BulkTankUndo()).copyWith(
          createdTankIds: tanksAfter.difference(tanksBefore).toList(),
        );
      }
    });

    SyncEventBus.notifyLocalChange();

    return BulkEditSnapshot(
      priorDiveRows: priorDiveRows,
      priorTagIds: priorTagIds,
      priorDiveTypeIds: priorDiveTypeIds,
      priorCourseIds: priorCourseIds,
      priorGear: priorGear,
      priorBuddies: priorBuddies,
      priorDiverRoleIds: priorDiverRoleIds,
      tankUndo: tankUndo,
      priorTankSpecRows: priorTankSpecRows,
      priorWeights: priorWeights,
      priorSightings: priorSightings,
    );
  }

  /// Reverse a prior [apply]: restore each dive's prior scalar columns and the
  /// prior membership of every touched collection. One transaction, one notify.
  Future<void> undo(BulkEditSnapshot snapshot) => ChangeLogScope.bulk(
    DatabaseService.instance.databaseOrNull,
    label: ChangeLogLabels.bulkEdit,
    body: () => _undoInner(snapshot),
  );

  Future<void> _undoInner(BulkEditSnapshot snapshot) async {
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

      final diverRoles = snapshot.priorDiverRoleIds;
      if (diverRoles != null) {
        for (final id in ids) {
          await _roleLinks.writeDiverRoles(id, diverRoles[id] ?? const []);
        }
      }
      final tags = snapshot.priorTagIds;
      if (tags != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceTags([id], tags[id] ?? const []);
        }
      }
      final diveTypes = snapshot.priorDiveTypeIds;
      if (diveTypes != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceDiveTypes([id], diveTypes[id] ?? const []);
        }
      }
      // After the dive rows, whose representative course_id the replace then
      // rewrites from the restored set (#2515).
      final courses = snapshot.priorCourseIds;
      if (courses != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceCourses([id], courses[id] ?? const []);
        }
      }
      final gear = snapshot.priorGear;
      if (gear != null) {
        for (final id in ids) {
          await _diveRepo.replaceGearRows(id, gear[id] ?? const []);
        }
      }
      final buddies = snapshot.priorBuddies;
      if (buddies != null) {
        for (final id in ids) {
          await _buddyRepo.bulkReplaceBuddies([id], buddies[id] ?? const []);
        }
      }
      final tankUndo = snapshot.tankUndo;
      if (tankUndo != null) {
        await _tankUndo.undo(tankUndo);
      }
      final tankSpecRows = snapshot.priorTankSpecRows;
      if (tankSpecRows != null) {
        await _diveRepo.bulkRestoreTankRows(tankSpecRows);
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
          case BulkCollectionMode.update:
            throw UnsupportedError('Tags have no in-place update');
        }
      case DiveTypesOp(:final mode, :final diveTypeIds):
        switch (mode) {
          case BulkCollectionMode.add:
            await _diveRepo.bulkAddDiveTypes(ids, diveTypeIds);
          case BulkCollectionMode.remove:
            await _diveRepo.bulkRemoveDiveTypes(ids, diveTypeIds);
          case BulkCollectionMode.replace:
            await _diveRepo.bulkReplaceDiveTypes(ids, diveTypeIds);
          case BulkCollectionMode.update:
            throw UnsupportedError('Dive types have no in-place update');
        }
      case DiveCoursesOp(:final mode, :final courseIds):
        switch (mode) {
          case BulkCollectionMode.add:
            await _diveRepo.bulkAddCourses(ids, courseIds);
          case BulkCollectionMode.remove:
            await _diveRepo.bulkRemoveCourses(ids, courseIds);
          case BulkCollectionMode.replace:
            await _diveRepo.bulkReplaceCourses(ids, courseIds);
          case BulkCollectionMode.update:
            throw UnsupportedError('Courses have no in-place update');
        }
      case EquipmentOp(:final mode, :final equipmentIds):
        switch (mode) {
          case BulkCollectionMode.add:
            await _diveRepo.bulkAddEquipment(ids, equipmentIds);
          case BulkCollectionMode.remove:
            await _diveRepo.bulkRemoveEquipment(ids, equipmentIds);
          case BulkCollectionMode.replace:
            await _diveRepo.bulkReplaceEquipment(ids, equipmentIds);
          case BulkCollectionMode.update:
            throw UnsupportedError('Equipment has no in-place update');
        }
      case BuddiesOp(:final mode, :final buddies, :final overwriteRole):
        switch (mode) {
          case BulkCollectionMode.add:
            await _buddyRepo.bulkAddBuddies(
              ids,
              buddies,
              overwriteRole: overwriteRole,
            );
          case BulkCollectionMode.remove:
            await _buddyRepo.bulkRemoveBuddies(
              ids,
              buddies.map((b) => b.buddy.id).toList(),
            );
          case BulkCollectionMode.replace:
            await _buddyRepo.bulkReplaceBuddies(ids, buddies);
          case BulkCollectionMode.update:
            // Role-only: rewrite the links each dive already has and insert
            // nothing, so changing the role of a buddy who is on some of the
            // selection cannot add them to the rest (#1220). A role change
            // that SHOULD travel with membership still rides
            // add + overwriteRole (#893).
            await _buddyRepo.bulkUpdateBuddyRoles(ids, buddies);
        }
      // Applied ahead of the scalars and every other op, in [apply].
      case SiteOp():
        break;
      case DiverRolesOp(:final roleIds):
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final id in ids) {
          await _roleLinks.writeDiverRoles(id, roleIds, now: now);
        }
      // Owned collections never support remove; reject it explicitly so a
      // misconstructed op fails fast instead of silently doing an add. Tanks
      // additionally support an in-place update, carried by TankSpecsOp.
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
          case BulkCollectionMode.update:
            // In-place spec edits arrive as TankSpecsOp, which carries the
            // field mask a plain tank list cannot express.
            throw UnsupportedError('Use TankSpecsOp to update tanks in place');
        }
      case TankSpecsOp(:final specs, :final fields):
        await _diveRepo.bulkUpdateTankSpecs(ids, specs, fields);
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
          case BulkCollectionMode.update:
            throw UnsupportedError('Weights have no in-place update');
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
          case BulkCollectionMode.update:
            throw UnsupportedError('Sightings have no in-place update');
        }
    }
  }

  /// Each dive's dive types before the edit, for undo. Ordered by createdAt so
  /// undo restores the original representative (the first type), matching
  /// _diveTypesForDives.
  Future<Map<String, List<String>>> _priorDiveTypeIds(
    List<String> ids,
    List<Dive> priorDiveRows,
  ) async {
    final rows =
        await (_db.select(_db.diveDiveTypes)
              ..where((t) => t.diveId.isIn(ids))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
            .get();
    final prior = {for (final id in ids) id: <String>[]};
    for (final r in rows) {
      prior[r.diveId]!.add(r.diveTypeId);
    }
    // Legacy dives with no junction rows: seed from the representative
    // column so undo restores their type instead of recreational.
    for (final row in priorDiveRows) {
      if (prior[row.id]!.isEmpty) {
        prior[row.id]!.add(row.diveType);
      }
    }
    return prior;
  }

  // Map Drift rows back to the domain objects the bulk-replace methods consume.
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
        label: r.label,
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
