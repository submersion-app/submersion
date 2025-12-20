import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/dive_type_entity.dart' as domain;

class DiveTypeRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveTypeRepository);

  // ============================================================================
  // CRUD Operations
  // ============================================================================

  /// Get all dive types, ordered by sort order then name
  /// Returns built-in types (diverId = null) plus custom types for the specified diver
  Future<List<domain.DiveTypeEntity>> getAllDiveTypes({String? diverId}) async {
    try {
      final query = _db.select(_db.diveTypes)
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.name),
        ]);

      // Show built-in types (diverId is null) plus current diver's custom types
      if (diverId != null) {
        query.where((t) => t.diverId.isNull() | t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToDiveType).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all dive types', e, stackTrace);
      rethrow;
    }
  }

  /// Get only built-in dive types
  Future<List<domain.DiveTypeEntity>> getBuiltInDiveTypes() async {
    try {
      final query = _db.select(_db.diveTypes)
        ..where((t) => t.isBuiltIn.equals(true))
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.name),
        ]);
      final rows = await query.get();
      return rows.map(_mapRowToDiveType).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get built-in dive types', e, stackTrace);
      rethrow;
    }
  }

  /// Get only custom (user-defined) dive types for the specified diver
  Future<List<domain.DiveTypeEntity>> getCustomDiveTypes({String? diverId}) async {
    try {
      final query = _db.select(_db.diveTypes)
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.name),
        ]);

      // Filter by non-built-in types for the specified diver
      if (diverId != null) {
        query.where((t) => t.isBuiltIn.equals(false) & t.diverId.equals(diverId));
      } else {
        query.where((t) => t.isBuiltIn.equals(false));
      }

      final rows = await query.get();
      return rows.map(_mapRowToDiveType).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get custom dive types', e, stackTrace);
      rethrow;
    }
  }

  /// Get a single dive type by ID
  Future<domain.DiveTypeEntity?> getDiveTypeById(String id) async {
    try {
      final query = _db.select(_db.diveTypes)..where((t) => t.id.equals(id));
      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToDiveType(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get dive type by id: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get a dive type by name (case-insensitive)
  Future<domain.DiveTypeEntity?> getDiveTypeByName(String name) async {
    try {
      final query = _db.select(_db.diveTypes)
        ..where((t) => t.name.lower().equals(name.toLowerCase()));
      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToDiveType(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get dive type by name: $name', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new custom dive type
  Future<domain.DiveTypeEntity> createDiveType(domain.DiveTypeEntity diveType) async {
    try {
      _log.info('Creating dive type: ${diveType.name}');

      // Generate slug from name if id is empty
      final id = diveType.id.isEmpty
          ? domain.DiveTypeEntity.generateSlug(diveType.name)
          : diveType.id;

      // Ensure the slug is unique
      final existing = await getDiveTypeById(id);
      final uniqueId = existing != null ? '${id}_${_uuid.v4().substring(0, 8)}' : id;

      final now = DateTime.now().millisecondsSinceEpoch;

      // Get the next sort order
      final maxSortOrder = await _getMaxSortOrder();

      await _db.into(_db.diveTypes).insert(DiveTypesCompanion(
        id: Value(uniqueId),
        diverId: Value(diveType.diverId),
        name: Value(diveType.name),
        isBuiltIn: const Value(false), // Custom types are never built-in
        sortOrder: Value(diveType.sortOrder > 0 ? diveType.sortOrder : maxSortOrder + 1),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),);

      _log.info('Created dive type with id: $uniqueId');
      return diveType.copyWith(
        id: uniqueId,
        sortOrder: diveType.sortOrder > 0 ? diveType.sortOrder : maxSortOrder + 1,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to create dive type', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing dive type (only custom types can be updated)
  Future<void> updateDiveType(domain.DiveTypeEntity diveType) async {
    try {
      // Check if it's a built-in type
      final existing = await getDiveTypeById(diveType.id);
      if (existing != null && existing.isBuiltIn) {
        throw Exception('Cannot update built-in dive types');
      }

      _log.info('Updating dive type: ${diveType.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.diveTypes)..where((t) => t.id.equals(diveType.id))).write(
        DiveTypesCompanion(
          name: Value(diveType.name),
          sortOrder: Value(diveType.sortOrder),
          updatedAt: Value(now),
        ),
      );
      _log.info('Updated dive type: ${diveType.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update dive type: ${diveType.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a custom dive type (built-in types cannot be deleted)
  Future<void> deleteDiveType(String id) async {
    try {
      // Check if it's a built-in type
      final existing = await getDiveTypeById(id);
      if (existing != null && existing.isBuiltIn) {
        throw Exception('Cannot delete built-in dive types');
      }

      _log.info('Deleting dive type: $id');
      await (_db.delete(_db.diveTypes)..where((t) => t.id.equals(id))).go();
      _log.info('Deleted dive type: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete dive type: $id', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Statistics
  // ============================================================================

  /// Get dive type usage statistics for the specified diver
  /// Shows built-in types (diverId is null) plus custom types for the diver
  Future<List<DiveTypeStatistic>> getDiveTypeStatistics({String? diverId}) async {
    try {
      final String whereClause;
      final List<Variable> variables;

      if (diverId != null) {
        whereClause = 'WHERE dt.diver_id IS NULL OR dt.diver_id = ?';
        variables = [Variable.withString(diverId)];
      } else {
        whereClause = '';
        variables = [];
      }

      final result = await _db.customSelect('''
        SELECT dt.*, COUNT(d.id) as dive_count
        FROM dive_types dt
        LEFT JOIN dives d ON dt.id = d.dive_type
        $whereClause
        GROUP BY dt.id
        ORDER BY dt.sort_order, dt.name
      ''', variables: variables).get();

      return result.map((row) => DiveTypeStatistic(
        diveType: domain.DiveTypeEntity(
          id: row.data['id'] as String,
          diverId: row.data['diver_id'] as String?,
          name: row.data['name'] as String,
          isBuiltIn: (row.data['is_built_in'] as int) == 1,
          sortOrder: row.data['sort_order'] as int,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
        ),
        diveCount: row.data['dive_count'] as int,
      ),).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get dive type statistics', e, stackTrace);
      rethrow;
    }
  }

  /// Check if a dive type is in use
  Future<bool> isDiveTypeInUse(String id) async {
    try {
      final result = await _db.customSelect('''
        SELECT COUNT(*) as count FROM dives WHERE dive_type = ?
      ''', variables: [Variable.withString(id)],).getSingle();
      return (result.data['count'] as int) > 0;
    } catch (e, stackTrace) {
      _log.error('Failed to check if dive type is in use: $id', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  Future<int> _getMaxSortOrder() async {
    final result = await _db.customSelect('''
      SELECT MAX(sort_order) as max_order FROM dive_types
    ''').getSingleOrNull();
    return (result?.data['max_order'] as int?) ?? 0;
  }

  domain.DiveTypeEntity _mapRowToDiveType(DiveType row) {
    return domain.DiveTypeEntity(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      isBuiltIn: row.isBuiltIn,
      sortOrder: row.sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}

/// Dive type usage statistics
class DiveTypeStatistic {
  final domain.DiveTypeEntity diveType;
  final int diveCount;

  DiveTypeStatistic({required this.diveType, required this.diveCount});
}
