import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';

/// Applies every equipment set that lists a dive's computer as a member
/// (issue #1020).
///
/// A diver who keeps a computer permanently paired with the rest of a rig
/// (e.g. a CCR controller with drysuit, tec fins, bailout) models that by
/// adding the computer's gear twin to an `EquipmentSet` alongside the other
/// items. Once the computer that logged this dive is known, this service
/// looks up every set containing that computer's gear-twin equipment id and
/// adds that set's full roster.
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
  Future<bool> linkComputerSetsForDive({required String diveId}) async {
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final computerEquipmentIds = await _gearLinker
          .gearTwinEquipmentIdsForDive(diveId);
      if (computerEquipmentIds.isEmpty) return false;

      final memberRows = await (_db.select(
        _db.equipmentSetItems,
      )..where((t) => t.equipmentId.isIn(computerEquipmentIds))).get();
      final setIds = memberRows.map((r) => r.setId).toSet();
      if (setIds.isEmpty) return false;

      var appliedAny = false;
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
      if (appliedAny) SyncEventBus.notifyLocalChange();
      return appliedAny;
    } catch (_) {
      // Best-effort: never let this fail the dive operation.
      return false;
    }
  }
}
