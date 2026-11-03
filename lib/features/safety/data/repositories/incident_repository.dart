import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';

/// Persistence for near-miss incident reports (HLC parent, synced,
/// deliberately untouched by every outbound exporter).
class IncidentRepository {
  db.AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  /// Fires on a report's own change and on a check-in's, since whether a
  /// report's check-in link stands follows the check-in (see [_read]).
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([_db.incidents, _db.equipmentObservations]),
  );

  Future<List<Incident>> getIncidents({String? diverId}) async {
    final query = _db.select(_db.incidents)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId) | t.diverId.isNull());
    }
    return _read(await query.get());
  }

  Future<List<Incident>> getIncidentsForDive(String diveId) async {
    final rows =
        await (_db.select(_db.incidents)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
            .get();
    return _read(rows);
  }

  Future<Incident?> getIncidentById(String id) async {
    final row = await (_db.select(
      _db.incidents,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : (await _read([row])).single;
  }

  Future<Incident> createIncident({
    required DateTime occurredAt,
    required IncidentCategory category,
    required IncidentSeverity severity,
    required String narrative,
    String? contributingFactors,
    String? lessonsLearned,
    String? diveId,
    String? diverId,
    String? equipmentId,
    String? observationId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final incident = Incident(
      id: id,
      diverId: diverId,
      diveId: diveId,
      equipmentId: equipmentId,
      observationId: observationId,
      occurredAt: occurredAt,
      category: category,
      severity: severity,
      narrative: narrative,
      contributingFactors: contributingFactors,
      lessonsLearned: lessonsLearned,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.incidents).insert(_toCompanion(incident));
    await _syncRepository.markRecordPending(
      entityType: 'incidents',
      recordId: id,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
    SyncEventBus.notifyLocalChange();
    return incident;
  }

  Future<void> updateIncident(Incident incident) async {
    final now = DateTime.now();
    final updated = incident.copyWith(updatedAt: now);
    await _db.into(_db.incidents).insertOnConflictUpdate(_toCompanion(updated));
    await _syncRepository.markRecordPending(
      entityType: 'incidents',
      recordId: incident.id,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Every incident that names [equipmentId], newest first (condition
  /// phase 3a; the condition engine's incidentLinked rule reads this).
  Future<List<Incident>> getIncidentsForEquipment(String equipmentId) async {
    final rows =
        await (_db.select(_db.incidents)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
            .get();
    return _read(rows);
  }

  /// Clears the gear link on every incident naming [equipmentId] and stages
  /// each. Call it before the item is deleted: ON DELETE SET NULL would clear
  /// the link too, but moves no clock and stages nothing, so a peer would keep
  /// the incident linked to gear that no longer exists. The incident stays.
  /// Its check-in link goes in the same write, since the item's check-ins go
  /// with the item.
  Future<void> unlinkFromDeletedEquipment(
    String equipmentId, {
    DateTime? now,
  }) async {
    final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    await _db.transaction(() async {
      final rows = await (_db.select(
        _db.incidents,
      )..where((t) => t.equipmentId.equals(equipmentId))).get();
      if (rows.isEmpty) return;
      await (_db.update(
        _db.incidents,
      )..where((t) => t.equipmentId.equals(equipmentId))).write(
        db.IncidentsCompanion(
          equipmentId: const Value(null),
          observationId: const Value(null),
          updatedAt: Value(stamp),
        ),
      );
      for (final row in rows) {
        await _syncRepository.markRecordPending(
          entityType: 'incidents',
          recordId: row.id,
          localUpdatedAt: stamp,
        );
      }
    });
  }

  Future<void> deleteIncident(String id) async {
    await (_db.delete(_db.incidents)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: 'incidents', recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  db.IncidentsCompanion _toCompanion(Incident incident) {
    return db.IncidentsCompanion.insert(
      id: incident.id,
      diverId: Value(incident.diverId),
      diveId: Value(incident.diveId),
      equipmentId: Value(incident.equipmentId),
      observationId: Value(incident.observationId),
      occurredAt: incident.occurredAt.millisecondsSinceEpoch,
      category: incident.category.dbValue,
      severity: incident.severity.dbValue,
      narrative: incident.narrative,
      contributingFactors: Value(incident.contributingFactors),
      lessonsLearned: Value(incident.lessonsLearned),
      createdAt: incident.createdAt.millisecondsSinceEpoch,
      updatedAt: incident.updatedAt.millisecondsSinceEpoch,
    );
  }

  /// [rows] as reports. A report names a check-in only while it is an issue on
  /// the report's item. A device saving such a change clears the link itself,
  /// but a peer below v338 cannot, and two devices can link and resolve at
  /// once. The rule is read here and never written back: a check-in can go OK
  /// and return to an issue between one device's syncs, and a device that had
  /// erased the link would keep it erased while its peers kept it. Read from
  /// the synced rows, every device reaches the same answer (#3062).
  Future<List<Incident>> _read(List<db.Incident> rows) async {
    final standing = rows.any((row) => row.observationId != null)
        ? await _reportsWithStandingLink()
        : const <String>{};
    return [
      for (final row in rows)
        _toDomain(row, linkStands: standing.contains(row.id)),
    ];
  }

  Future<Set<String>> _reportsWithStandingLink() async {
    final rows = await _db.customSelect('''
      SELECT incidents.id AS id FROM incidents
      JOIN equipment_observations
        ON equipment_observations.id = incidents.observation_id
      WHERE equipment_observations.status = 'issue'
        AND equipment_observations.equipment_id = incidents.equipment_id
    ''').get();
    return {for (final row in rows) row.read<String>('id')};
  }

  Incident _toDomain(db.Incident row, {required bool linkStands}) {
    return Incident(
      id: row.id,
      diverId: row.diverId,
      diveId: row.diveId,
      equipmentId: row.equipmentId,
      observationId: linkStands ? row.observationId : null,
      // occurredAt is a timezone-stable wall-clock date (stored as UTC), so it
      // shows the same calendar day on every synced device. Mirror the dive
      // log, which reads its wall-clock timestamps with isUtc: true.
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        row.occurredAt,
        isUtc: true,
      ),
      category: IncidentCategory.fromDbValue(row.category),
      severity: IncidentSeverity.fromDbValue(row.severity),
      narrative: row.narrative,
      contributingFactors: row.contributingFactors,
      lessonsLearned: row.lessonsLearned,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
