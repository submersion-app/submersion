import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

/// Fill history of physical cylinders (spec section 10.2), keyed by passport
/// id. Registered for sync like the transmitter registry: every write marks
/// the row pending, every delete logs a tombstone.
class CylinderFillRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  static const String entity = 'cylinderFills';

  Stream<void> watchFillsChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.cylinderFills));

  Future<CylinderFill> create(CylinderFill fill) async {
    final withId = fill.id.isEmpty ? fill.copyWith(id: _uuid.v4()) : fill;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.cylinderFills)
        .insert(_companion(withId, now: now, createdAt: now));
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: withId.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return withId.copyWith(
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> update(CylinderFill fill) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.cylinderFills,
    )..where((t) => t.id.equals(fill.id))).write(_companion(fill, now: now));
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: fill.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.cylinderFills)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: entity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  Future<CylinderFill?> getById(String id) async {
    final row = await (_db.select(
      _db.cylinderFills,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Newest first.
  Future<List<CylinderFill>> getForPassport(String passportId) async {
    final rows =
        await (_db.select(_db.cylinderFills)
              ..where((t) => t.passportId.equals(passportId))
              ..orderBy([(t) => OrderingTerm.desc(t.filledAt)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  Future<CylinderFill?> newestForPassport(String passportId) async {
    final row =
        await (_db.select(_db.cylinderFills)
              ..where((t) => t.passportId.equals(passportId))
              ..orderBy([(t) => OrderingTerm.desc(t.filledAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Newest first, through the gear link only.
  Future<List<CylinderFill>> getForEquipment(String equipmentId) async {
    final rows =
        await (_db.select(_db.cylinderFills)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([(t) => OrderingTerm.desc(t.filledAt)]))
            .get();
    return rows.map(_fromRow).toList();
  }

  /// Points every fill of [passportId] at [equipmentId] and stages each for
  /// sync. Returns how many rows changed.
  Future<int> relinkToEquipment({
    required String passportId,
    required String equipmentId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await (_db.select(
      _db.cylinderFills,
    )..where((t) => t.passportId.equals(passportId))).get();
    final stale = rows.where((r) => r.equipmentId != equipmentId).toList();
    if (stale.isEmpty) return 0;
    await _db.transaction(() async {
      await (_db.update(
        _db.cylinderFills,
      )..where((t) => t.id.isIn(stale.map((r) => r.id).toList()))).write(
        CylinderFillsCompanion(
          equipmentId: Value(equipmentId),
          updatedAt: Value(now),
        ),
      );
    });
    for (final row in stale) {
      await _syncRepository.markRecordPending(
        entityType: entity,
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
    return stale.length;
  }

  /// Clears the gear link on the fills of a cylinder being deleted and
  /// stages each row, so peers receive the cleared link rather than relying
  /// on SQLite's set-null. Mirrors TransmitterRepository.
  Future<void> unlinkFromDeletedEquipment(String equipmentId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await (_db.select(
      _db.cylinderFills,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    if (rows.isEmpty) return;
    await (_db.update(
      _db.cylinderFills,
    )..where((t) => t.equipmentId.equals(equipmentId))).write(
      CylinderFillsCompanion(
        equipmentId: const Value(null),
        updatedAt: Value(now),
      ),
    );
    for (final row in rows) {
      await _syncRepository.markRecordPending(
        entityType: entity,
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
  }

  CylinderFill _fromRow(CylinderFillRow r) => CylinderFill(
    id: r.id,
    diverId: r.diverId,
    passportId: r.passportId,
    equipmentId: r.equipmentId,
    filledAt: DateTime.fromMillisecondsSinceEpoch(r.filledAt),
    o2Percent: r.o2Percent,
    hePercent: r.hePercent,
    pressureBar: r.pressureBar,
    temperatureC: r.temperatureC,
    analyzer: r.analyzer,
    stationName: r.stationName,
    stationKey: r.stationKey,
    signedRecord: r.signedRecord,
    source: FillSource.fromName(r.source),
    notes: r.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );

  CylinderFillsCompanion _companion(
    CylinderFill f, {
    required int now,
    int? createdAt,
  }) => CylinderFillsCompanion(
    id: Value(f.id),
    diverId: Value(f.diverId),
    passportId: Value(f.passportId),
    equipmentId: Value(f.equipmentId),
    filledAt: Value(f.filledAt.millisecondsSinceEpoch),
    o2Percent: Value(f.o2Percent),
    hePercent: Value(f.hePercent),
    pressureBar: Value(f.pressureBar),
    temperatureC: Value(f.temperatureC),
    analyzer: Value(f.analyzer),
    stationName: Value(f.stationName),
    stationKey: Value(f.stationKey),
    signedRecord: Value(f.signedRecord),
    source: Value(f.source.name),
    notes: Value(f.notes),
    createdAt: createdAt != null ? Value(createdAt) : const Value.absent(),
    updatedAt: Value(now),
  );
}
