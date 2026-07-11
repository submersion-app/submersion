import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Maps a Drift row to the domain entity. Shared with BuddyRepository so
/// per-dive role resolution uses the exact same mapping.
DiveRole mapDiveRoleRow(DiveRoleRow row) {
  return DiveRole(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    isBuiltIn: row.isBuiltIn,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}

class DiveRoleRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveRoleRepository);

  /// Emits whenever the `dive_roles` table changes so list providers can
  /// refresh after a sync or any other write.
  Stream<void> watchDiveRolesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.diveRoles));

  /// Built-in roles plus the given diver's custom roles, built-ins first,
  /// each group ordered by sortOrder then name. Without a diverId only
  /// built-ins are returned (custom roles are always diver-scoped).
  Future<List<DiveRole>> getAllDiveRoles({String? diverId}) async {
    try {
      final query = _db.select(_db.diveRoles)
        ..orderBy([
          (t) => OrderingTerm.desc(t.isBuiltIn),
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.name),
        ]);
      if (diverId != null) {
        query.where(
          (t) =>
              t.isBuiltIn.equals(true) |
              (t.isBuiltIn.equals(false) & t.diverId.equals(diverId)),
        );
      } else {
        query.where((t) => t.isBuiltIn.equals(true));
      }
      final rows = await query.get();
      return rows.map(mapDiveRoleRow).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all dive roles',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a single dive role by id.
  Future<DiveRole?> getDiveRoleById(String id) async {
    try {
      final row = await (_db.select(
        _db.diveRoles,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row != null ? mapDiveRoleRow(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive role by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a custom dive role for [diverId]. Ids are UUIDs (never
  /// name-derived) so renames cannot break dive_buddies/dives references.
  Future<DiveRole> createDiveRole({
    required String name,
    required String diverId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxSortOrder = await _getMaxSortOrder();

      await _db
          .into(_db.diveRoles)
          .insert(
            DiveRolesCompanion(
              id: Value(id),
              diverId: Value(diverId),
              name: Value(name.trim()),
              isBuiltIn: const Value(false),
              sortOrder: Value(maxSortOrder + 1),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'diveRoles',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created dive role $id ($name) for diver: $diverId');
      final created = await getDiveRoleById(id);
      return created!;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create dive role',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Rename a custom dive role (built-ins cannot be renamed).
  Future<void> renameDiveRole(String id, String newName) async {
    try {
      final existing = await getDiveRoleById(id);
      if (existing == null) {
        throw Exception('Dive role not found: $id');
      }
      if (existing.isBuiltIn) {
        throw Exception('Cannot update built-in dive roles');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.diveRoles)..where((t) => t.id.equals(id))).write(
        DiveRolesCompanion(name: Value(newName.trim()), updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveRoles',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Renamed dive role $id to $newName');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to rename dive role: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a custom dive role (built-ins cannot be deleted).
  Future<void> deleteDiveRole(String id) async {
    try {
      final existing = await getDiveRoleById(id);
      if (existing == null) return;
      if (existing.isBuiltIn) {
        throw Exception('Cannot delete built-in dive roles');
      }

      await (_db.delete(_db.diveRoles)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'diveRoles', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted dive role: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete dive role: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// True when any dive_buddies row or dives.diver_role references [id].
  Future<bool> isDiveRoleInUse(String id) async {
    try {
      final result = await _db
          .customSelect(
            'SELECT '
            '(SELECT COUNT(*) FROM dive_buddies WHERE role = ?1) + '
            '(SELECT COUNT(*) FROM dives WHERE diver_role = ?1) AS uses',
            variables: [Variable.withString(id)],
          )
          .getSingle();
      return (result.data['uses'] as int) > 0;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to check if dive role is in use: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<int> _getMaxSortOrder() async {
    final result = await _db.customSelect('''
      SELECT MAX(sort_order) as max_order FROM dive_roles
    ''').getSingleOrNull();
    return (result?.data['max_order'] as int?) ?? 0;
  }
}
