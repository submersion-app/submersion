import 'package:drift/drift.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_snapshot.dart';

/// Captures and reverses the tank half of a bulk edit (#3929).
///
/// Works on the captured Drift rows rather than through the domain entity, so
/// a restored tank keeps its id and every column, and whatever refers to that
/// id (dive profile events hold it with no foreign key) resolves again.
class BulkTankUndoWriter {
  final _sync = SyncRepository();
  final _tankSeries = TankPressureSeriesRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  /// What a replace of [tanks], the current tanks of [diveIds], is about to
  /// cascade away.
  Future<BulkTankUndo> captureReplaced(
    List<String> diveIds,
    List<DiveTank> tanks,
  ) async {
    final gasSwitches = <GasSwitche>[];
    for (final chunk in seriesIdChunks(diveIds)) {
      gasSwitches.addAll(
        await (_db.select(
          _db.gasSwitches,
        )..where((t) => t.diveId.isIn(chunk))).get(),
      );
    }
    return BulkTankUndo(
      replacedTanks: tanks,
      replacedPressureSeries: await _tankSeries.getRowsForDives(diveIds),
      replacedGasSwitches: gasSwitches,
    );
  }

  /// Reverses a tank edit. The caller owns the transaction and has already
  /// restored the dive rows, which bumps each dive and gives a restored slot
  /// link its trip to be checked against.
  Future<void> undo(BulkTankUndo undo) async {
    await _removeCreated(undo.createdTankIds);
    final now = DateTime.now().millisecondsSinceEpoch;
    final links = await _LiveLinks.read(_db, undo);
    // Tanks first: the series and switches are foreign keys into them.
    for (final row in undo.replacedTanks) {
      await _db
          .into(_db.diveTanks)
          .insertOnConflictUpdate(
            row
                .copyWith(
                  equipmentId: Value(links.gear(row.equipmentId)),
                  regulatorEquipmentId: Value(
                    links.gear(row.regulatorEquipmentId),
                  ),
                  computerId: Value(links.computer(row.computerId)),
                  sourceId: Value(links.source(row.sourceId)),
                  tripCylinderId: Value(await _liveSlot(row)),
                )
                .toCompanion(false),
          );
      // Left in place, the tombstone would ride the next changeset beside the
      // upsert and delete the tank again on every peer.
      await _sync.removeDeletion(entityType: 'diveTanks', recordId: row.id);
      await _sync.markRecordPending(
        entityType: 'diveTanks',
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
    for (final row in undo.replacedPressureSeries) {
      await _tankSeries.restoreSeriesRow(
        row.copyWith(
          computerId: Value(links.computer(row.computerId)),
          sourceId: Value(links.source(row.sourceId)),
        ),
        now: now,
      );
    }
    for (final row in undo.replacedGasSwitches) {
      await _db
          .into(_db.gasSwitches)
          .insertOnConflictUpdate(
            row
                .copyWith(computerId: Value(links.computer(row.computerId)))
                .toCompanion(false),
          );
      await _sync.markRecordPending(
        entityType: 'gasSwitches',
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
  }

  Future<void> _removeCreated(List<String> tankIds) async {
    for (final chunk in seriesIdChunks(tankIds)) {
      await (_db.delete(_db.diveTanks)..where((t) => t.id.isIn(chunk))).go();
    }
    for (final id in tankIds) {
      await _sync.logDeletion(entityType: 'diveTanks', recordId: id);
    }
  }

  /// [row]'s trip cylinder slot, if the dive's restored trip still offers it.
  Future<String?> _liveSlot(DiveTank row) async {
    final slot = row.tripCylinderId;
    if (slot == null) return null;
    final dive = await (_db.select(
      _db.dives,
    )..where((d) => d.id.equals(row.diveId))).getSingleOrNull();
    final slots = await tripCylinderIdsForTrip(_db, dive?.tripId);
    return validTripCylinderLink(slot, slots);
  }
}

/// Which of the rows an undo's captured links name still exist: one may have
/// been deleted since the capture, here or by a synced tombstone, and written
/// unchecked it would fail the whole undo on the foreign key.
class _LiveLinks {
  const _LiveLinks(this._gear, this._computers, this._sources);

  final Set<String> _gear;
  final Set<String> _computers;
  final Set<String> _sources;

  String? gear(String? id) => _gear.contains(id) ? id : null;
  String? computer(String? id) => _computers.contains(id) ? id : null;
  String? source(String? id) => _sources.contains(id) ? id : null;

  static Future<_LiveLinks> read(AppDatabase db, BulkTankUndo undo) async {
    final tanks = undo.replacedTanks;
    final series = undo.replacedPressureSeries;
    return _LiveLinks(
      await _existing(db, db.equipment, db.equipment.id, [
        for (final t in tanks) ...[t.equipmentId, t.regulatorEquipmentId],
      ]),
      await _existing(db, db.diveComputers, db.diveComputers.id, [
        for (final t in tanks) t.computerId,
        for (final s in series) s.computerId,
        for (final g in undo.replacedGasSwitches) g.computerId,
      ]),
      await _existing(db, db.diveDataSources, db.diveDataSources.id, [
        for (final t in tanks) t.sourceId,
        for (final s in series) s.sourceId,
      ]),
    );
  }

  static Future<Set<String>> _existing(
    AppDatabase db,
    ResultSetImplementation<HasResultSet, dynamic> table,
    GeneratedColumn<String> idColumn,
    List<String?> ids,
  ) async {
    final found = <String>{};
    for (final chunk in seriesIdChunks(ids.nonNulls.toSet().toList())) {
      final query = db.selectOnly(table)
        ..addColumns([idColumn])
        ..where(idColumn.isIn(chunk));
      found.addAll((await query.get()).map((r) => r.read(idColumn)!));
    }
    return found;
  }
}
