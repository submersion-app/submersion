import 'package:drift/drift.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/tank_extra_regulators.dart';

/// Captures and reverses the tank half of a bulk edit (#3929).
///
/// Works on the captured Drift rows rather than through the domain entity, so
/// a restored tank keeps its id and every column, and whatever refers to that
/// id (dive profile events hold it with no foreign key) resolves again.
class BulkTankUndoWriter {
  final _sync = SyncRepository();
  final _tankSeries = TankPressureSeriesRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  /// What a replace of the tanks of [diveIds] is about to delete, the cascade
  /// included.
  Future<BulkTankUndo> captureReplaced(List<String> diveIds) async {
    final tanks = <DiveTank>[];
    final gasSwitches = <GasSwitche>[];
    for (final chunk in seriesIdChunks(diveIds)) {
      tanks.addAll(
        await (_db.select(
          _db.diveTanks,
        )..where((t) => t.diveId.isIn(chunk))).get(),
      );
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

  /// The ids of the tanks of [diveIds]. Read either side of an edit, the
  /// difference is what it created, however many tank ops it ran.
  Future<Set<String>> tankIdsOf(List<String> diveIds) => _LiveLinks._ids(
    _db,
    _db.diveTanks,
    _db.diveTanks.id,
    diveIds,
    matching: _db.diveTanks.diveId,
  );

  /// Reverses a tank edit. The caller owns the transaction and has already
  /// restored the dive rows, which bumps each dive and gives a restored slot
  /// link its trip to be checked against.
  Future<void> undo(BulkTankUndo undo) async {
    await _removeCreated(undo.createdTankIds);
    final now = DateTime.now().millisecondsSinceEpoch;
    final links = await _LiveLinks.read(_db, undo);
    final slotsByDive = <String, Set<String>>{};
    // Tanks first: the series and switches are foreign keys into them.
    for (final row in undo.replacedTanks) {
      // Normalised like every other write: a deleted first regulator must
      // not leave extras with no first.
      final regulators = normalizeTankRegulators(
        links.gear(row.regulatorEquipmentId),
        decodeExtraRegulatorIds(row.extraRegulatorIds).where(links.hasGear),
      );
      final slot = row.tripCylinderId;
      final slots = slot == null
          ? const <String>{}
          : slotsByDive[row.diveId] ??= await _slotsOf(row.diveId);
      await _db
          .into(_db.diveTanks)
          .insertOnConflictUpdate(
            row
                .copyWith(
                  equipmentId: Value(links.gear(row.equipmentId)),
                  regulatorEquipmentId: Value(regulators.first),
                  extraRegulatorIds: Value(
                    encodeExtraRegulatorIds(regulators.extras),
                  ),
                  computerId: Value(links.computer(row.computerId)),
                  sourceId: Value(links.source(row.diveId, row.sourceId)),
                  tripCylinderId: Value(validTripCylinderLink(slot, slots)),
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
          sourceId: Value(links.source(row.diveId, row.sourceId)),
        ),
        now: now,
        // The caller notifies once, after its transaction.
        notify: false,
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
    await _sync.logDeletions(entityType: 'diveTanks', recordIds: tankIds);
  }

  /// The slots [diveId]'s trip offers, which the restored dive row now names.
  Future<Set<String>> _slotsOf(String diveId) async {
    final dive = await (_db.select(
      _db.dives,
    )..where((d) => d.id.equals(diveId))).getSingleOrNull();
    return tripCylinderIdsForTrip(_db, dive?.tripId);
  }
}

/// Which of the rows an undo's captured links name still exist: one may have
/// been deleted since the capture, here or by a synced tombstone, and written
/// unchecked it would fail the whole undo on the foreign key.
class _LiveLinks {
  const _LiveLinks(this._gear, this._computers, this._sources);

  final Set<String> _gear;
  final Set<String> _computers;
  final Set<(String, String)> _sources;

  bool hasGear(String id) => _gear.contains(id);
  String? gear(String? id) => _gear.contains(id) ? id : null;
  String? computer(String? id) => _computers.contains(id) ? id : null;
  String? source(String diveId, String? id) =>
      _sources.contains((diveId, id)) ? id : null;

  static Future<_LiveLinks> read(AppDatabase db, BulkTankUndo undo) async {
    final tanks = undo.replacedTanks;
    final series = undo.replacedPressureSeries;
    return _LiveLinks(
      await _ids(db, db.equipment, db.equipment.id, [
        for (final t in tanks) ...[
          t.equipmentId,
          t.regulatorEquipmentId,
          ...decodeExtraRegulatorIds(t.extraRegulatorIds),
        ],
      ]),
      await _ids(db, db.diveComputers, db.diveComputers.id, [
        for (final t in tanks) t.computerId,
        for (final s in series) s.computerId,
        for (final g in undo.replacedGasSwitches) g.computerId,
      ]),
      await _sourcesOf(db, [for (final t in tanks) t.diveId]),
    );
  }

  /// The (dive, source) pairs [diveIds] still have, so a source moved to
  /// another dive stays there even when that dive is in the same edit.
  static Future<Set<(String, String)>> _sourcesOf(
    AppDatabase db,
    List<String> diveIds,
  ) async {
    final sources = db.diveDataSources;
    final found = <(String, String)>{};
    for (final chunk in seriesIdChunks(diveIds.toSet().toList())) {
      final query = db.selectOnly(sources)
        ..addColumns([sources.diveId, sources.id])
        ..where(sources.diveId.isIn(chunk));
      found.addAll(
        (await query.get()).map(
          (r) => (r.read(sources.diveId)!, r.read(sources.id)!),
        ),
      );
    }
    return found;
  }

  /// The [idColumn] of [table]'s rows whose [matching] column, by default
  /// [idColumn] itself, is one of [values].
  static Future<Set<String>> _ids(
    AppDatabase db,
    ResultSetImplementation<HasResultSet, dynamic> table,
    GeneratedColumn<String> idColumn,
    List<String?> values, {
    GeneratedColumn<String>? matching,
  }) async {
    final found = <String>{};
    for (final chunk in seriesIdChunks(values.nonNulls.toSet().toList())) {
      final query = db.selectOnly(table)
        ..addColumns([idColumn])
        ..where((matching ?? idColumn).isIn(chunk));
      found.addAll((await query.get()).map((r) => r.read(idColumn)!));
    }
    return found;
  }
}
