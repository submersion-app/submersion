import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';

/// Plain-data capture of every row touched by a dive merge (#449), taken
/// before mutation so a merge can later be undone.
///
/// `Dive`, `DiveTank`, `DiveWeight`, `Sighting`, `DiveCustomField` here are
/// the Drift row classes (from database.dart), not the domain entities of
/// the same name.
class DiveMergeSnapshot {
  const DiveMergeSnapshot({
    required this.mergedDiveId,
    required this.diveRows,
    required this.tankRows,
    required this.weightRows,
    required this.customFieldRows,
    required this.equipmentRows,
    required this.diveTypeRows,
    required this.tagRows,
    required this.buddyRows,
    required this.sightingRows,
    required this.eventRows,
    required this.gasSwitchRows,
    required this.dataSourceRows,
    required this.tideRows,
    required this.mediaDiveIds,
    this.profileSeriesRows = const [],
    this.tankSeriesRows = const [],
  });

  /// The id assigned to the new merged dive.
  final String mergedDiveId;

  final List<Dive> diveRows;
  final List<DiveTank> tankRows;
  final List<DiveWeight> weightRows;
  final List<DiveCustomField> customFieldRows;
  final List<DiveEquipmentData> equipmentRows;
  final List<DiveDiveType> diveTypeRows;
  final List<DiveTag> tagRows;
  final List<DiveBuddy> buddyRows;
  final List<Sighting> sightingRows;
  final List<DiveProfileEvent> eventRows;
  final List<GasSwitche> gasSwitchRows;
  final List<DiveDataSourcesData> dataSourceRows;
  final List<TideRecord> tideRows;

  /// Media id -> original dive id, so an undo can point media back at its
  /// source dive.
  final Map<String, String> mediaDiveIds;

  /// Raw packed profile / tank pressure series rows of [diveIds], undecoded,
  /// for an undo to restore verbatim. The only sample capture there is: v183
  /// dropped the row-per-sample tables this class used to snapshot too.
  final List<DiveProfileSeriesRow> profileSeriesRows;
  final List<TankPressureSeriesRow> tankSeriesRows;

  /// Reads (does not mutate) every row belonging to [diveIds] so a merge
  /// can later be applied and, if needed, undone.
  static Future<DiveMergeSnapshot> capture(
    AppDatabase db,
    List<String> diveIds,
    String mergedDiveId,
  ) async {
    final mediaRows = await (db.select(
      db.media,
    )..where((t) => t.diveId.isIn(diveIds))).get();

    return DiveMergeSnapshot(
      mergedDiveId: mergedDiveId,
      diveRows: await (db.select(
        db.dives,
      )..where((t) => t.id.isIn(diveIds))).get(),
      tankRows: await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      weightRows: await (db.select(
        db.diveWeights,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      customFieldRows: await (db.select(
        db.diveCustomFields,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      equipmentRows: await (db.select(
        db.diveEquipment,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      diveTypeRows: await (db.select(
        db.diveDiveTypes,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      tagRows: await (db.select(
        db.diveTags,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      buddyRows: await (db.select(
        db.diveBuddies,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      sightingRows: await (db.select(
        db.sightings,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      eventRows: await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      gasSwitchRows: await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      dataSourceRows: await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      tideRows: await (db.select(
        db.tideRecords,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      mediaDiveIds: {for (final m in mediaRows) m.id: m.diveId!},
      profileSeriesRows: await ProfileSeriesRepository(
        database: db,
        syncRepository: SyncRepository(database: db),
      ).getRowsForDives(diveIds),
      tankSeriesRows: await TankPressureSeriesRepository(
        database: db,
        syncRepository: SyncRepository(database: db),
      ).getRowsForDives(diveIds),
    );
  }
}
