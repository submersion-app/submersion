import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

/// Saved Connections maps, per diver, synced: every write marks the row
/// pending, every delete logs a tombstone.
class ConnectionMapRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  static const String entity = 'connectionMaps';

  Stream<void> watchConnectionMapsChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.connectionMaps))
      .debounce(DiveRepository.changeTickDebounce);

  Future<List<SavedConnectionMap>> getAll(String diverId) async {
    final rows =
        await (_db.select(_db.connectionMaps)
              ..where((t) => t.diverId.equals(diverId))
              ..orderBy([
                (t) => OrderingTerm(expression: t.sortOrder),
                (t) => OrderingTerm(expression: t.name),
              ]))
            .get();
    return [for (final r in rows) ?_fromRow(r)];
  }

  Future<SavedConnectionMap> create({
    required String diverId,
    required String name,
    required MapSpec spec,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _db
        .into(_db.connectionMaps)
        .insert(
          ConnectionMapsCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value(name),
            spec: Value(jsonEncode(spec.toJson())),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _markPending(id, now);
    final at = DateTime.fromMillisecondsSinceEpoch(now);
    return SavedConnectionMap(
      id: id,
      diverId: diverId,
      name: name,
      spec: spec,
      createdAt: at,
      updatedAt: at,
    );
  }

  Future<void> rename(String id, String name) =>
      _write(id, ConnectionMapsCompanion(name: Value(name)));

  Future<void> updateSpec(String id, MapSpec spec) => _write(
    id,
    ConnectionMapsCompanion(spec: Value(jsonEncode(spec.toJson()))),
  );

  Future<void> delete(String id) async {
    await (_db.delete(_db.connectionMaps)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: entity, recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  /// Puts a just-deleted map back with its id (the undo snackbar).
  Future<void> restore(SavedConnectionMap map) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.connectionMaps)
        .insertOnConflictUpdate(
          ConnectionMapsCompanion(
            id: Value(map.id),
            diverId: Value(map.diverId),
            name: Value(map.name),
            spec: Value(jsonEncode(map.spec.toJson())),
            sortOrder: Value(map.sortOrder),
            createdAt: Value(map.createdAt.millisecondsSinceEpoch),
            updatedAt: Value(now),
          ),
        );
    await _markPending(map.id, now);
  }

  Future<void> _write(String id, ConnectionMapsCompanion changes) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.connectionMaps)..where((t) => t.id.equals(id))).write(
      changes.copyWith(updatedAt: Value(now)),
    );
    await _markPending(id, now);
  }

  Future<void> _markPending(String id, int now) async {
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  SavedConnectionMap? _fromRow(ConnectionMapRow r) =>
      SavedConnectionMap.tryParse(
        id: r.id,
        diverId: r.diverId,
        name: r.name,
        specJson: r.spec,
        sortOrder: r.sortOrder,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
      );
}
