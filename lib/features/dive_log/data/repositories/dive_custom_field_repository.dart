import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart'
    as domain;
import 'package:uuid/uuid.dart';

/// Repository for managing user-defined key:value custom fields on dive logs.
class DiveCustomFieldRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  DiveCustomFieldRepository(this._db);

  /// Get all custom fields for a single dive, ordered by sort order.
  Future<List<domain.DiveCustomField>> getFieldsForDive(String diveId) async {
    final query = _db.select(_db.diveCustomFields)
      ..where((cf) => cf.diveId.equals(diveId))
      ..orderBy([(cf) => OrderingTerm.asc(cf.sortOrder)]);
    final rows = await query.get();
    return rows.map(_mapRowToField).toList();
  }

  /// Batch-load custom fields for multiple dives, grouped by dive ID.
  ///
  /// Returns a map of diveId to list of custom fields.
  /// Dives with no custom fields will not have an entry in the map.
  Future<Map<String, List<domain.DiveCustomField>>> getFieldsForDiveIds(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};
    final rows =
        await (_db.select(_db.diveCustomFields)
              ..where((cf) => cf.diveId.isIn(diveIds))
              ..orderBy([(cf) => OrderingTerm.asc(cf.sortOrder)]))
            .get();

    final result = <String, List<domain.DiveCustomField>>{};
    for (final row in rows) {
      result.putIfAbsent(row.diveId, () => []).add(_mapRowToField(row));
    }
    return result;
  }

  /// Replace all custom fields for a dive (delete existing, insert new).
  ///
  /// This runs inside a transaction to ensure atomicity.
  Future<void> replaceFieldsForDive(
    String diveId,
    List<domain.DiveCustomField> fields,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.diveCustomFields,
      )..where((cf) => cf.diveId.equals(diveId))).go();

      final now = DateTime.now().millisecondsSinceEpoch;
      for (final field in fields) {
        final id = field.id.isNotEmpty ? field.id : _uuid.v4();
        await _db
            .into(_db.diveCustomFields)
            .insert(
              DiveCustomFieldsCompanion(
                id: Value(id),
                diveId: Value(diveId),
                fieldKey: Value(field.key),
                fieldValue: Value(field.value),
                sortOrder: Value(field.sortOrder),
                createdAt: Value(now),
              ),
            );
      }
    });
  }

  /// Get all distinct custom field keys used by a specific diver.
  ///
  /// This is useful for auto-complete suggestions when adding new custom fields.
  Future<List<String>> getDistinctKeysForDiver(String diverId) async {
    final result = await _db
        .customSelect(
          'SELECT DISTINCT cf.field_key FROM dive_custom_fields cf '
          'INNER JOIN dives d ON cf.dive_id = d.id '
          'WHERE d.diver_id = ? '
          'ORDER BY cf.field_key',
          variables: [Variable(diverId)],
        )
        .get();

    return result.map((row) => row.data['field_key'] as String).toList();
  }

  domain.DiveCustomField _mapRowToField(DiveCustomField row) {
    return domain.DiveCustomField(
      id: row.id,
      key: row.fieldKey,
      value: row.fieldValue,
      sortOrder: row.sortOrder,
    );
  }
}
