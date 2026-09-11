import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

/// Owns `equipment_observations`, a synced aggregate root with its own HLC:
/// every write marks the row pending, every delete logs a tombstone, like
/// `IncidentRepository`.
class EquipmentObservationRepository {
  static const String entityType = 'equipmentObservations';

  final AppDatabase? _dbOverride;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();

  EquipmentObservationRepository({
    AppDatabase? db,
    SyncRepository? syncRepository,
  }) : _dbOverride = db,
       _syncRepository = syncRepository ?? SyncRepository();

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  Stream<void> watchChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.equipmentObservations))
      .map((_) {});

  Future<List<EquipmentObservation>> getForEquipment(String equipmentId) =>
      _query((t) => t.equipmentId.equals(equipmentId));

  Future<List<EquipmentObservation>> getForDive(String diveId) =>
      _query((t) => t.diveId.equals(diveId));

  Future<List<EquipmentObservation>> getForEquipmentOnDive(
    String equipmentId,
    String diveId,
  ) => _query(
    (t) => t.equipmentId.equals(equipmentId) & t.diveId.equals(diveId),
  );

  Future<List<EquipmentObservation>> getAll({String? diverId}) =>
      _query(diverId == null ? null : (t) => t.diverId.equals(diverId));

  Future<EquipmentObservation?> getById(String id) async {
    final row = await (_db.select(
      _db.equipmentObservations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<EquipmentObservation> create({
    required String equipmentId,
    String? diveId,
    String? diverId,
    required DateTime observedAt,
    required ObservationStatus status,
    List<ObservationTag> issueTags = const [],
    List<String> unrecognizedTags = const [],
    String note = '',
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final observation = EquipmentObservation(
      id: _uuid.v4(),
      diverId: diverId,
      equipmentId: equipmentId,
      diveId: diveId,
      observedAt: observedAt,
      status: status,
      issueTags: issueTags,
      unrecognizedTags: unrecognizedTags,
      note: note,
      createdAt: stamp,
      updatedAt: stamp,
    );
    await _db.transaction(() async {
      await _db
          .into(_db.equipmentObservations)
          .insert(_toCompanion(observation));
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: observation.id,
        localUpdatedAt: stamp.millisecondsSinceEpoch,
      );
    });
    SyncEventBus.notifyLocalChange();
    return observation;
  }

  Future<void> update(EquipmentObservation observation, {DateTime? now}) async {
    final stamp = now ?? DateTime.now();
    final updated = observation.copyWith(updatedAt: stamp);
    await _db.transaction(() async {
      await _db
          .into(_db.equipmentObservations)
          .insertOnConflictUpdate(_toCompanion(updated));
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: updated.id,
        localUpdatedAt: stamp.millisecondsSinceEpoch,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.equipmentObservations,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: entityType, recordId: id);
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<List<EquipmentObservation>> _query(
    Expression<bool> Function($EquipmentObservationsTable t)? where,
  ) async {
    final query = _db.select(_db.equipmentObservations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.observedAt),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    if (where != null) query.where(where);
    final rows = await query.get();
    return [for (final row in rows) _toDomain(row)];
  }

  EquipmentObservationsCompanion _toCompanion(EquipmentObservation o) =>
      EquipmentObservationsCompanion.insert(
        id: o.id,
        diverId: Value(o.diverId),
        equipmentId: o.equipmentId,
        diveId: Value(o.diveId),
        observedAt: o.observedAt.millisecondsSinceEpoch,
        status: o.status.dbValue,
        // An OK check carries no tags, so a newer peer's names go with the
        // rest when an issue is turned into one.
        issueTags: Value(
          encodeObservationTags(
            o.issueTags,
            unrecognized: o.isIssue ? o.unrecognizedTags : const [],
          ),
        ),
        note: Value(o.note),
        createdAt: o.createdAt.millisecondsSinceEpoch,
        updatedAt: o.updatedAt.millisecondsSinceEpoch,
      );

  EquipmentObservation _toDomain(
    EquipmentObservationRow row,
  ) => EquipmentObservation(
    id: row.id,
    diverId: row.diverId,
    equipmentId: row.equipmentId,
    diveId: row.diveId,
    observedAt: DateTime.fromMillisecondsSinceEpoch(
      row.observedAt,
      isUtc: true,
    ),
    status: ObservationStatus.fromDbValue(row.status),
    issueTags: decodeObservationTags(row.issueTags),
    unrecognizedTags: decodeUnrecognizedObservationTags(row.issueTags),
    note: row.note,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
  );
}
