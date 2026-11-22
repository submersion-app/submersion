import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// Attaches the gear twins of the dive computers that logged a dive (v175).
///
/// Used by the non-interactive creation seams (dive-computer download, file
/// import), alongside `DiveEquipmentDefaulter`, `ChecklistDiveLinker` and
/// `DiveAltitudeEnricher`.
///
/// Link-only: it never creates an equipment row. Creation happens once, at
/// computer registration, so a twin the user deleted (which clears
/// `dive_computers.equipment_id`) simply produces no link and stays deleted.
class DiveComputerGearLinker {
  /// With [database], every read and write of [linkComputerGearToDives]
  /// stays on that library even if another is opened meanwhile; pass a
  /// [syncRepository] on the same database with it.
  DiveComputerGearLinker({
    DiveRepository? diveRepository,
    SyncRepository? syncRepository,
    AppDatabase? database,
  }) : _dives = diveRepository ?? DiveRepository(),
       _sync = syncRepository ?? SyncRepository(database: database),
       _database = database;

  final DiveRepository _dives;
  final SyncRepository _sync;
  final AppDatabase? _database;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// Returns true when at least one twin was attached.
  ///
  /// MUST run after `DiveEquipmentDefaulter` at every seam: the defaulter bails
  /// when the dive already has any `dive_equipment` row, so linking first would
  /// silently suppress the diver's default and geofenced equipment sets.
  ///
  /// Unlike the defaulter this is NOT gated on the dive being empty: the
  /// computer belongs on the dive whether or not a set already applied.
  ///
  /// Best-effort: any failure is swallowed so equipment linking can never abort
  /// a download or import that has already persisted the dive.
  Future<bool> linkComputerGearForDive({required String diveId}) async {
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final equipmentIds = await gearTwinEquipmentIdsForDive(diveId);
      if (equipmentIds.isEmpty) return false;

      await _dives.bulkAddEquipment([diveId], equipmentIds);
      SyncEventBus.notifyLocalChange();
      return true;
    } catch (_) {
      // Best-effort: never let gear linking fail the dive operation.
      return false;
    }
  }

  /// Puts computer [computerId]'s Equipment item on each of [diveIds] that
  /// does not carry it yet, and returns how many dives gained it (issue
  /// #4846). For the seams that give a computer dives it did not download
  /// itself: a relink once the computer is set up again, a merge, the
  /// one-time heal.
  ///
  /// A dive the diver took the item off keeps it off while its
  /// `diveEquipment` tombstone is held. [removedKeys], when given, is that
  /// set of tombstoned `dive|item` keys read once by the caller, for a pass
  /// long enough that a tombstone GC could run part way through it; the
  /// live tombstones are checked as well, for a removal made since.
  ///
  /// Only the item's own row is written, never its components: a part fitted
  /// to the computer today was not on a dive it recorded years ago, and
  /// expanding it there would inflate that part's dive count and service
  /// tracking. Each row is inserted and marked pending, as
  /// [DiveRepository.bulkAddEquipment] does, so it syncs like one the diver
  /// added. No transaction and no sync notify of its own: callers run it
  /// inside theirs and notify once. Unlike [linkComputerGearForDive] it
  /// rethrows, so a caller decides whether a failure is fatal.
  Future<int> linkComputerGearToDives({
    required String computerId,
    required Iterable<String> diveIds,
    Set<String>? removedKeys,
  }) async {
    final candidates = diveIds.toSet().toList();
    if (candidates.isEmpty) return 0;
    final computer = await (_db.select(
      _db.diveComputers,
    )..where((t) => t.id.equals(computerId))).getSingleOrNull();
    final itemId = computer?.equipmentId;
    if (itemId == null || itemId.isEmpty) return 0;
    // A link a sync left dangling, or one to an item of another type (which
    // the device gear heal treats as no entry either), until that heal
    // repairs it: a dangling id would fail the foreign key and the caller
    // with it, and another item would be put on every dive in its place.
    final item = await (_db.select(
      _db.equipment,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null || item.type != 'computer') return 0;

    final missing = <String>[];
    for (final chunk in seriesIdChunks(candidates)) {
      final linked =
          await (_db.selectOnly(_db.diveEquipment)
                ..addColumns([_db.diveEquipment.diveId])
                ..where(
                  _db.diveEquipment.equipmentId.equals(itemId) &
                      _db.diveEquipment.diveId.isIn(chunk),
                ))
              .map((r) => r.read(_db.diveEquipment.diveId)!)
              .get();
      final linkedSet = linked.toSet();
      final unlinked = [
        for (final id in chunk)
          if (!linkedSet.contains(id)) id,
      ];
      if (unlinked.isEmpty) continue;
      // The live tombstones too: a removal made after the caller's
      // snapshot was read is not in it.
      final live = await _sync.deletedIds('diveEquipment', [
        for (final id in unlinked) '$id|$itemId',
      ]);
      final removed = removedKeys == null ? live : {...removedKeys, ...live};
      missing.addAll([
        for (final id in unlinked)
          if (!removed.contains('$id|$itemId')) id,
      ]);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in missing) {
      await _db
          .into(_db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: itemId),
            mode: InsertMode.insertOrIgnore,
          );
      await _sync.markRecordPending(
        entityType: 'diveEquipment',
        recordId: '$diveId|$itemId',
        localUpdatedAt: now,
      );
    }
    return missing.length;
  }

  /// Gear-twin equipment ids of every computer that logged [diveId], for
  /// `EquipmentSetForComputerLinker` (issue #1020) to resolve set membership
  /// from without duplicating the computer/twin lookup.
  Future<List<String>> gearTwinEquipmentIdsForDive(String diveId) async {
    final computerIds = await _computerIdsForDive(diveId);
    if (computerIds.isEmpty) return [];

    final rows = await (_db.select(
      _db.diveComputers,
    )..where((t) => t.id.isIn(computerIds))).get();
    return rows
        .map((r) => r.equipmentId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Every computer that logged [diveId].
  ///
  /// Deliberately NOT `DiveComputerRepository.getComputerIdsForDive`, which
  /// reads `dive_profile_series` and so sees only dives that carry samples.
  /// A file-imported dive registered by #1288 can have `computer_id` stamped
  /// and a data-source row while having no samples at all, and its computer
  /// belongs on it just the same.
  ///
  /// `dives.computer_id` alone is not enough either: it holds only the primary,
  /// so a dive logged on two computers would list one. This is the same union
  /// the v175 backfill applies, so the migration and the runtime path agree.
  Future<List<String>> _computerIdsForDive(String diveId) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT computer_id FROM ('
          '  SELECT computer_id FROM dive_data_sources '
          '   WHERE dive_id = ? AND computer_id IS NOT NULL'
          '  UNION'
          '  SELECT computer_id FROM dives '
          '   WHERE id = ? AND computer_id IS NOT NULL'
          ')',
          variables: [Variable<String>(diveId), Variable<String>(diveId)],
        )
        .get();
    return rows
        .map((row) => row.read<String?>('computer_id'))
        .whereType<String>()
        .toList();
  }
}
