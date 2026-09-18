import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';

/// Applies every equipment set that lists a dive's computer as a member and
/// has opted in to `autoApplyOnComputerImport` (issue #1020).
///
/// A diver who keeps a computer permanently paired with the rest of a rig
/// (e.g. a CCR controller with drysuit, tec fins, bailout) models that by
/// adding the computer's gear twin to an `EquipmentSet` alongside the other
/// items, then turning the set's "apply when this computer is imported"
/// switch on -- off by default, so existing sets are unaffected until a
/// diver opts in. Once the computer that logged this dive is known, this
/// service looks up every opted-in set containing that computer's gear-twin
/// equipment id and adds that set's full roster.
///
/// Runs at every seam `DiveComputerGearLinker` runs at, after it. Unlike
/// `DiveEquipmentDefaulter` this is NOT gated on the dive being empty and NOT
/// mutually exclusive with a geofenced/default set: a diver can have both a
/// location-based set and a computer-based set match the same dive, in which
/// case both are applied (the issue itself accepts this as a case the diver
/// may need to correct manually). Several sets can list the same computer;
/// all of them are applied. `bulkAddEquipment` is idempotent per equipment
/// id and only fills a still-null `viaSetId`, so an overlapping or repeated
/// application never duplicates a row or steals another set's provenance.
///
/// Best-effort: any failure is swallowed so this can never abort a download
/// or import that has already persisted the dive.
class EquipmentSetForComputerLinker {
  EquipmentSetForComputerLinker({
    DiveComputerGearLinker? gearLinker,
    EquipmentSetRepository? equipmentSetRepository,
    DiveRepository? diveRepository,
  }) : _gearLinker = gearLinker ?? DiveComputerGearLinker(),
       _sets = equipmentSetRepository ?? EquipmentSetRepository(),
       _dives = diveRepository ?? DiveRepository();

  final DiveComputerGearLinker _gearLinker;
  final EquipmentSetRepository _sets;
  final DiveRepository _dives;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Returns true when at least one set was applied.
  ///
  /// Scoped to the dive's own diver, same as `DiveEquipmentDefaulter`: a
  /// dive computer can be shared across diver profiles in one local
  /// database (e.g. buddies syncing one install), and without this a set
  /// another diver built around that same computer would silently attach
  /// its unrelated gear to this diver's dive. A dive with no diver (owner-
  /// less) is skipped entirely rather than crossing diver scopes.
  Future<bool> linkComputerSetsForDive({required String diveId}) async {
    if (DatabaseService.instance.databaseOrNull == null) return false;
    // Declared outside the try so a failure partway through the loop below
    // still reports (and notifies sync about) whichever sets already wrote
    // successfully, instead of masking a real DB change as "nothing happened".
    var appliedAny = false;
    try {
      final computerEquipmentIds = await _gearLinker
          .gearTwinEquipmentIdsForDive(diveId);
      if (computerEquipmentIds.isEmpty) return false;

      final dive = await (_db.select(
        _db.dives,
      )..where((t) => t.id.equals(diveId))).getSingleOrNull();
      final diverId = dive?.diverId;
      if (diverId == null) return false;

      // One joined query for "opted-in sets, owned by this diver, that
      // contain one of these computers" rather than a set-membership
      // lookup followed by a separate opt-in filter.
      final placeholders = computerEquipmentIds.map((_) => '?').join(',');
      final rows = await _db
          .customSelect(
            'SELECT DISTINCT s.id FROM equipment_sets s '
            'JOIN equipment_set_items i ON i.set_id = s.id '
            'WHERE i.equipment_id IN ($placeholders) '
            'AND s.auto_apply_on_computer_import = 1 '
            'AND s.diver_id = ?',
            variables: [
              for (final id in computerEquipmentIds) Variable<String>(id),
              Variable<String>(diverId),
            ],
            readsFrom: {_db.equipmentSets, _db.equipmentSetItems},
          )
          .get();
      final setIds = rows.map((row) => row.read<String>('id')).toSet();
      if (setIds.isEmpty) return false;

      for (final setId in setIds) {
        final setEquipmentIds = await _sets.getEquipmentIdsInSet(setId);
        if (setEquipmentIds.isEmpty) continue;
        await _dives.bulkAddEquipment(
          [diveId],
          setEquipmentIds,
          viaSetId: setId,
        );
        appliedAny = true;
      }
      return appliedAny;
    } catch (_) {
      // Best-effort: never let this fail the dive operation. appliedAny may
      // already be true if an earlier set in the loop wrote successfully
      // before a later one threw; report that partial success rather than
      // masking it as false.
      return appliedAny;
    } finally {
      // Runs once regardless of which path returned, so a partial success
      // followed by a thrown exception still notifies sync about the sets
      // that did get written.
      if (appliedAny) SyncEventBus.notifyLocalChange();
    }
  }
}
