import 'package:submersion/core/database/database.dart' hide Dive, DiveSite;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_selector.dart';

/// Applies a diver's default / geofenced equipment set to a dive that has no
/// equipment yet. Used by the non-interactive creation seams (dive-computer
/// download, file import). Never overwrites gear already present.
class DiveEquipmentDefaulter {
  DiveEquipmentDefaulter({
    EquipmentSetRepository? equipmentSetRepository,
    DiveRepository? diveRepository,
    EquipmentRepository? equipmentRepository,
  }) : _sets = equipmentSetRepository ?? EquipmentSetRepository(),
       _dives = diveRepository ?? DiveRepository(),
       _equipment = equipmentRepository ?? EquipmentRepository();

  final EquipmentSetRepository _sets;
  final DiveRepository _dives;
  final EquipmentRepository _equipment;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Returns true when a set was applied. Best-effort: any failure (missing
  /// database mid-migration, a transient query/write error, or a mocked layer
  /// in tests) is swallowed so equipment defaulting can never abort a dive
  /// import/download that has already persisted the dive.
  Future<bool> applyDefaultEquipmentIfEmpty({
    required String diveId,
    required String? diverId,
    required List<GeoPoint> divePoints,
  }) async {
    // An owner-less dive must not inherit another diver's default: the
    // repository treats a null diverId as "no filter" and would return every
    // diver's sets. Skip defaulting entirely rather than cross diver scopes.
    if (diverId == null) return false;
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final existing = await (_db.select(
        _db.diveEquipment,
      )..where((t) => t.diveId.equals(diveId))).get();
      if (existing.isNotEmpty) return false;

      final candidateSets = await _sets.getAllSets(diverId: diverId);
      if (candidateSets.isEmpty) return false;
      final geofences = await _sets.getAllGeofences(diverId: diverId);

      final best = EquipmentSetSelector.bestSetFor(
        divePoints: divePoints,
        sets: candidateSets,
        geofences: geofences,
      );
      if (best == null || best.equipmentIds.isEmpty) return false;
      // A member no longer shared with this diver stays in the set but is
      // not applied (issue #2046).
      final memberIds = await _equipment.usableSetMemberIds(
        best.equipmentIds,
        diverId,
      );
      if (memberIds.isEmpty) return false;

      // Tag every row with the set that won so the dive remembers it and
      // the pages can group by it (issue #1487).
      await _dives.bulkAddEquipment([diveId], memberIds, viaSetId: best.id);
      SyncEventBus.notifyLocalChange();
      return true;
    } catch (_) {
      // Best-effort: never let equipment defaulting fail the dive operation.
      return false;
    }
  }

  /// Convenience for imported domain dives: assembles the dive's known points
  /// (linked site + entry/exit fixes) and applies on empty.
  Future<bool> applyForImportedDive(Dive dive) {
    return applyDefaultEquipmentIfEmpty(
      diveId: dive.id,
      diverId: dive.diverId,
      divePoints: _pointsOf(dive),
    );
  }

  /// Chooses again for a dive given a position it did not have when it was
  /// written (a GPS track matched after the import, issue #3704), so it ends
  /// up with the set it would have had: an empty dive takes the best set,
  /// and with [replaceDefault] the default set gives way to a geofenced one
  /// the position falls in. Gear added any other way is never touched.
  ///
  /// [replaceDefault] is for dives whose only gear is what this defaulter
  /// put on when they were written; a file's own gear may carry the default
  /// set's tag because the diver chose it. Best-effort, as on creation.
  Future<bool> applyForNewPosition({
    required String diveId,
    required String? diverId,
    required List<GeoPoint> divePoints,
    required bool replaceDefault,
  }) async {
    if (diverId == null) return false;
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      final existing = await (_db.select(
        _db.diveEquipment,
      )..where((t) => t.diveId.equals(diveId))).get();
      if (existing.isEmpty) {
        return await applyDefaultEquipmentIfEmpty(
          diveId: diveId,
          diverId: diverId,
          divePoints: divePoints,
        );
      }
      if (!replaceDefault) return false;

      final candidateSets = await _sets.getAllSets(diverId: diverId);
      final defaultSet = candidateSets.where((s) => s.isDefault).firstOrNull;
      if (defaultSet == null ||
          !existing.any((r) => r.viaSetId == defaultSet.id)) {
        return false;
      }
      final fenced = EquipmentSetSelector.matchingGeofenceSet(
        divePoints: divePoints,
        sets: candidateSets,
        geofences: await _sets.getAllGeofences(diverId: diverId),
      );
      if (fenced == null || fenced.id == defaultSet.id) return false;
      final memberIds = await _equipment.usableSetMemberIds(
        fenced.equipmentIds,
        diverId,
      );
      if (memberIds.isEmpty) return false;

      await _dives.replaceSetEquipment(
        diveId,
        fromSetId: defaultSet.id,
        toSetId: fenced.id,
        equipmentIds: memberIds,
      );
      SyncEventBus.notifyLocalChange();
      return true;
    } catch (_) {
      // Best-effort: never let equipment defaulting fail the dive operation.
      return false;
    }
  }

  /// [applyForNewPosition] for each of [diveIds], read back with the
  /// position just stamped on them.
  Future<void> applyForPositionedDives(
    List<String> diveIds, {
    required bool replaceDefault,
  }) async {
    if (diveIds.isEmpty) return;
    if (DatabaseService.instance.databaseOrNull == null) return;
    try {
      for (final dive in await _dives.getDivesByIds(diveIds)) {
        await applyForNewPosition(
          diveId: dive.id,
          diverId: dive.diverId,
          divePoints: _pointsOf(dive),
          replaceDefault: replaceDefault,
        );
      }
    } catch (_) {
      // Best-effort: the dives are imported and positioned either way.
    }
  }

  /// The dive's known points: linked site, then entry and exit fixes.
  static List<GeoPoint> _pointsOf(Dive dive) => [
    if (dive.site?.location != null) dive.site!.location!,
    if (dive.entryLocation != null) dive.entryLocation!,
    if (dive.exitLocation != null) dive.exitLocation!,
  ];
}
