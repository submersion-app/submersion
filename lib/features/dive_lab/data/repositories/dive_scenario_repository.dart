import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention_codec.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';

/// Saved Dive Lab scenarios: inputs only, synced like dive plans (pending
/// markers after each write, deletion_log tombstones on delete).
class DiveScenarioRepository {
  db.AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveScenarioRepository);

  /// Fires on any change to the scenarios table (local writes and sync).
  Stream<void> watchScenarioChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.diveScenarios));

  /// Inserts or updates [scenario]; an empty id mints one. The stored
  /// `createdAt` of an existing row is preserved; `updatedAt` is now.
  Future<DiveScenario> saveScenario(DiveScenario scenario) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = scenario.id.isEmpty ? _uuid.v4() : scenario.id;
      final existing = await (_db.select(
        _db.diveScenarios,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final createdAt = existing?.createdAt ?? now;
      await _db
          .into(_db.diveScenarios)
          .insertOnConflictUpdate(
            db.DiveScenariosCompanion(
              id: Value(id),
              diveId: Value(scenario.diveId),
              name: Value(scenario.name),
              notes: Value(scenario.notes ?? ''),
              branchSeconds: Value(scenario.branchSeconds),
              mode: Value(scenario.mode.name),
              interventionsJson: Value(
                encodeInterventions(scenario.interventions),
              ),
              createdAt: Value(createdAt),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveScenarios',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return scenario.copyWith(
        id: id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save scenario ${scenario.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<DiveScenario?> getScenario(String id) async {
    final row = await (_db.select(
      _db.diveScenarios,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  /// Newest first.
  Future<List<DiveScenario>> getScenariosForDive(String diveId) async {
    final rows =
        await (_db.select(_db.diveScenarios)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
    return rows.map(_map).toList();
  }

  Future<void> deleteScenario(String id) async {
    try {
      await (_db.delete(_db.diveScenarios)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'diveScenarios',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete scenario $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// A fresh-id copy of [id] with the same name; null when [id] is unknown.
  Future<DiveScenario?> duplicateScenario(String id) async {
    final source = await getScenario(id);
    if (source == null) return null;
    return saveScenario(source.copyWith(id: _uuid.v4()));
  }

  DiveScenario _map(db.DiveScenario row) {
    List<ScenarioIntervention> interventions;
    try {
      interventions = decodeInterventions(row.interventionsJson);
    } on FormatException catch (e) {
      // A newer writer's intervention kind: keep the scenario openable with
      // what this build understands rather than hiding it.
      _log.warning('Scenario ${row.id}: ${e.message}; interventions dropped');
      interventions = const [];
    }
    return DiveScenario(
      id: row.id,
      diveId: row.diveId,
      name: row.name,
      notes: row.notes.isEmpty ? null : row.notes,
      branchSeconds: row.branchSeconds,
      mode: ScenarioMode.values.asNameMap()[row.mode] ?? ScenarioMode.replay,
      interventions: interventions,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
