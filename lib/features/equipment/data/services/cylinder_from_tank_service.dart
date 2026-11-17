import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide TankPresets;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/cylinder_spec_attributes.dart';
import 'package:submersion/features/equipment/domain/services/tank_cylinder_matching.dart';

/// What the diver confirmed for one row of the review sheet: the proposal
/// and the name and spec they settled on (issue #4494).
class CylinderDraft {
  const CylinderDraft({
    required this.proposal,
    required this.name,
    required this.volumeL,
    required this.workingPressureBar,
    required this.material,
  });

  final CylinderProposal proposal;
  final String name;
  final double volumeL;
  final double? workingPressureBar;
  final TankMaterial? material;

  /// Whether the diver changed the spec the tanks were logged with, so the
  /// tanks take the corrected one too.
  bool get specChanged =>
      volumeL != proposal.volumeL ||
      workingPressureBar != proposal.workingPressureBar ||
      material != proposal.material;
}

/// Creates cylinder items from dive tanks and links tanks to cylinders
/// (issue #4494). A link is `dive_tanks.equipment_id`, which the dive edit
/// save leaves alone, so every write here is its own, recorded for sync like
/// the transmitter registry's fills.
class CylinderFromTankService {
  CylinderFromTankService({
    EquipmentRepository? equipment,
    DiveRepository? dives,
  }) : _equipment = equipment ?? EquipmentRepository(),
       _dives = dives ?? DiveRepository();

  final EquipmentRepository _equipment;
  final DiveRepository _dives;
  final SyncRepository _sync = SyncRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  /// Creates each draft's cylinders, links each to its tanks and adds it to
  /// those dives' gear, in one transaction. A row making several cylinders
  /// numbers them ("AL80 1", "AL80 2"). A tank linked elsewhere since the
  /// proposal was built keeps that link, and a cylinder whose tanks were all
  /// linked meanwhile is not made, so a stale sheet adds no unlinked
  /// duplicate. Returns the items created.
  Future<List<EquipmentItem>> create(
    List<CylinderDraft> drafts, {
    required String? diverId,
  }) async {
    if (drafts.isEmpty) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final created = await _equipment.transaction(() async {
      final items = <EquipmentItem>[];
      for (final draft in drafts) {
        final proposal = draft.proposal;
        // Only the cylinders with a tank still unlinked are made, and only
        // they are numbered, so a skipped one leaves no gap.
        final kept = <(List<TankRef>, Set<String>)>[];
        for (final refs in proposal.tanksByCylinder) {
          final free = await _unlinkedTankIds([
            for (final ref in refs) ref.tank.id,
          ]);
          if (free.isNotEmpty) kept.add((refs, free));
        }
        for (final (i, (refs, free)) in kept.indexed) {
          final item = await _equipment.createEquipment(
            EquipmentItem(
              id: '',
              diverId: diverId,
              name: kept.length == 1 ? draft.name : '${draft.name} ${i + 1}',
              type: EquipmentType.tank,
              attributes: cylinderSpecAttributes(
                volumeL: draft.volumeL,
                workingPressureBar: draft.workingPressureBar,
                material: draft.material,
                suitInflation: proposal.suitInflation,
                twinSet: proposal.twinSet,
              ),
            ),
            notify: false,
          );
          items.add(item);
          final linkedDives = <String>{};
          for (final ref in refs) {
            if (!free.contains(ref.tank.id)) continue;
            final linked = await _writeLink(
              ref.tank.id,
              item.id,
              now,
              spec: draft.specChanged ? draft : null,
            );
            if (linked) linkedDives.add(ref.diveId);
          }
          await _dives.bulkAddEquipment(linkedDives.toList(), [item.id]);
        }
      }
      return items;
    });
    if (created.isNotEmpty) SyncEventBus.notifyLocalChange();
    return created;
  }

  /// Links the tank [tankId] of dive [diveId] to the diver's own cylinder
  /// [equipmentId] and adds it to the dive's gear. The tank keeps the spec
  /// it was logged with. Like [create], a tank linked elsewhere while the
  /// picker was open keeps that link; returns whether this one was written.
  Future<bool> linkTank({
    required String diveId,
    required String tankId,
    required String equipmentId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final linked = await _db.transaction(() async {
      final written = await _writeLink(tankId, equipmentId, now);
      if (written) await _dives.bulkAddEquipment([diveId], [equipmentId]);
      return written;
    });
    if (linked) SyncEventBus.notifyLocalChange();
    return linked;
  }

  /// Clears the tank's link to [equipmentId], the cylinder the diver saw it
  /// linked to. The cylinder stays in the dive's gear, where the diver
  /// removes it if it was not used. A tank relinked since (by sync or
  /// another view) keeps the newer link; returns whether this one was
  /// cleared.
  Future<bool> unlinkTank({
    required String tankId,
    required String equipmentId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleared = await _db.transaction(() async {
      // child-clock: marked pending just below once the write lands; the
      // count it returns keeps the mark off a tank this call left alone.
      final written =
          await (_db.update(_db.diveTanks)..where(
                (t) => t.id.equals(tankId) & t.equipmentId.equals(equipmentId),
              ))
              .write(const DiveTanksCompanion(equipmentId: Value(null)));
      if (written == 0) return false;
      await _sync.markRecordPending(
        entityType: 'diveTanks',
        recordId: tankId,
        localUpdatedAt: now,
      );
      return true;
    });
    if (cleared) SyncEventBus.notifyLocalChange();
    return cleared;
  }

  /// Which of [tankIds] still have no cylinder link.
  Future<Set<String>> _unlinkedTankIds(List<String> tankIds) async {
    final rows = await (_db.select(
      _db.diveTanks,
    )..where((t) => t.id.isIn(tankIds) & t.equipmentId.isNull())).get();
    return {for (final row in rows) row.id};
  }

  /// Writes the link (and [spec], when the diver corrected it) onto the
  /// tank, only where the tank has no link yet. Returns whether it was
  /// written.
  Future<bool> _writeLink(
    String tankId,
    String equipmentId,
    int now, {
    CylinderDraft? spec,
  }) async {
    final query = _db.update(_db.diveTanks)
      ..where((t) => t.id.equals(tankId) & t.equipmentId.isNull());
    final written = await query.write(
      DiveTanksCompanion(
        equipmentId: Value(equipmentId),
        volume: spec == null ? const Value.absent() : Value(spec.volumeL),
        workingPressure: spec == null
            ? const Value.absent()
            : Value(spec.workingPressureBar),
        tankMaterial: spec == null
            ? const Value.absent()
            : Value(spec.material?.name),
        presetName: spec == null
            ? const Value.absent()
            : Value(_presetNameFor(spec)),
      ),
    );
    if (written == 0) return false;
    await _sync.markRecordPending(
      entityType: 'diveTanks',
      recordId: tankId,
      localUpdatedAt: now,
    );
    return true;
  }

  /// The built-in preset a corrected spec is, so the tank's preset label
  /// stops naming the default it was guessed from.
  String? _presetNameFor(CylinderDraft spec) {
    final pressure = spec.workingPressureBar;
    if (pressure == null) return null;
    return TankPresets.matchAnyBySpecs(
      spec.volumeL,
      pressure,
      material: spec.material,
    )?.name;
  }
}
