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

  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.incidents));

  Future<List<Incident>> getIncidents({String? diverId}) async {
    final query = _db.select(_db.incidents)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    if (diverId != null) {
      query.where((t) => t.diverId.equals(diverId) | t.diverId.isNull());
    }
    final rows = await query.get();
    return [for (final row in rows) _toDomain(row)];
  }

  Future<List<Incident>> getIncidentsForDive(String diveId) async {
    final rows =
        await (_db.select(_db.incidents)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
            .get();
    return [for (final row in rows) _toDomain(row)];
  }

  Future<Incident?> getIncidentById(String id) async {
    final row = await (_db.select(
      _db.incidents,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
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
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final incident = Incident(
      id: id,
      diverId: diverId,
      diveId: diveId,
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

  Incident _toDomain(db.Incident row) {
    return Incident(
      id: row.id,
      diverId: row.diverId,
      diveId: row.diveId,
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
