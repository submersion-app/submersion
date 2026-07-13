import 'package:submersion/core/database/database.dart' hide Dive, DiveSite;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_selector.dart';

/// Applies a diver's default / geofenced equipment set to a dive that has no
/// equipment yet. Used by the non-interactive creation seams (dive-computer
/// download, file import). Never overwrites gear already present.
class DiveEquipmentDefaulter {
  DiveEquipmentDefaulter({
    EquipmentSetRepository? equipmentSetRepository,
    DiveRepository? diveRepository,
  }) : _sets = equipmentSetRepository ?? EquipmentSetRepository(),
       _dives = diveRepository ?? DiveRepository();

  final EquipmentSetRepository _sets;
  final DiveRepository _dives;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Returns true when a set was applied. Best-effort: if the database is not
  /// available (mid-migration, or in tests that mock the layer above), skip
  /// rather than break the dive import/download.
  Future<bool> applyDefaultEquipmentIfEmpty({
    required String diveId,
    required String? diverId,
    required List<GeoPoint> divePoints,
  }) async {
    if (DatabaseService.instance.databaseOrNull == null) return false;
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

    await _dives.bulkAddEquipment([diveId], best.equipmentIds);
    SyncEventBus.notifyLocalChange();
    return true;
  }

  /// Convenience for imported domain dives: assembles the dive's known points
  /// (linked site + entry/exit fixes) and applies on empty.
  Future<bool> applyForImportedDive(Dive dive) {
    final points = <GeoPoint>[
      if (dive.site?.location != null) dive.site!.location!,
      if (dive.entryLocation != null) dive.entryLocation!,
      if (dive.exitLocation != null) dive.exitLocation!,
    ];
    return applyDefaultEquipmentIfEmpty(
      diveId: dive.id,
      diverId: dive.diverId,
      divePoints: points,
    );
  }
}
