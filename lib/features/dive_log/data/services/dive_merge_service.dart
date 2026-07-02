import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';

/// Applies and undoes sequential dive combines (#449).
/// Mirrors the BulkDiveEditService shape: snapshot -> one transaction ->
/// one SyncEventBus notify.
class DiveMergeService {
  DiveMergeService(this._diveRepo);

  // Unused by captureSnapshot; wired in for the apply/undo methods added in
  // Tasks 7-8.
  // ignore: unused_field
  final DiveRepository _diveRepo;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Reads (does not mutate) every row belonging to [diveIds] so a merge
  /// can later be applied and, if needed, undone.
  Future<DiveMergeSnapshot> captureSnapshot(
    List<String> diveIds,
    String mergedDiveId,
  ) async {
    final mediaRows = await (_db.select(
      _db.media,
    )..where((t) => t.diveId.isIn(diveIds))).get();

    return DiveMergeSnapshot(
      mergedDiveId: mergedDiveId,
      diveRows: await (_db.select(
        _db.dives,
      )..where((t) => t.id.isIn(diveIds))).get(),
      profileRows: await (_db.select(
        _db.diveProfiles,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      tankRows: await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      weightRows: await (_db.select(
        _db.diveWeights,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      customFieldRows: await (_db.select(
        _db.diveCustomFields,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      equipmentRows: await (_db.select(
        _db.diveEquipment,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      diveTypeRows: await (_db.select(
        _db.diveDiveTypes,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      tagRows: await (_db.select(
        _db.diveTags,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      buddyRows: await (_db.select(
        _db.diveBuddies,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      sightingRows: await (_db.select(
        _db.sightings,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      eventRows: await (_db.select(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      gasSwitchRows: await (_db.select(
        _db.gasSwitches,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      tankPressureRows: await (_db.select(
        _db.tankPressureProfiles,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      dataSourceRows: await (_db.select(
        _db.diveDataSources,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      tideRows: await (_db.select(
        _db.tideRecords,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      mediaDiveIds: {for (final m in mediaRows) m.id: m.diveId!},
    );
  }
}
