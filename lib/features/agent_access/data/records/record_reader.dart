import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// One window over an entity's visible rows.
class RecordPage {
  const RecordPage({required this.ids, required this.total});

  final List<String> ids;
  final int total;
}

/// Asks SQL which rows a diver may see, so one rule (the entity's scope)
/// governs both fetching by id and listing.
class RecordReader {
  const RecordReader(this._db);

  final AppDatabase _db;

  /// The ids from [ids] that [diverId] may see, in the order given.
  Future<List<String>> visibleIds(
    RecordEntry entry,
    List<String> ids,
    String diverId,
  ) => visibleRows(entry.table, entry.scope, ids, diverId);

  /// [visibleIds] for a block that lists ids from another table.
  Future<List<String>> visibleRows(
    String table,
    RecordScope rule,
    List<String> ids,
    String diverId,
  ) async {
    final visible = <String>{};
    final scope = rule(diverId, 'r0');
    for (final chunk in seriesIdChunks(ids)) {
      final marks = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT r0.id AS id FROM $table r0 '
            'WHERE r0.id IN ($marks)'
            '${scope == null ? '' : ' AND ${scope.sql}'}',
            variables: [
              for (final id in chunk) Variable<String>(id),
              if (scope != null)
                for (final p in scope.params) Variable<Object>(p),
            ],
          )
          .get();
      visible.addAll(rows.map((r) => r.read<String>('id')));
    }
    return [
      for (final id in ids)
        if (visible.contains(id)) id,
    ];
  }

  /// One window over what [diverId] may see, narrowed to one parent when
  /// [parentId] names it.
  Future<RecordPage> page(
    RecordEntry entry,
    String diverId, {
    String? parentId,
    required int limit,
    required int offset,
  }) async {
    final parentColumn = entry.parentColumn;
    if (parentId != null && parentColumn == null) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        '${entry.name} has no parent, so parent_id does not apply.',
        details: {'entity': entry.name, 'parent_id': parentId},
      );
    }
    final scope = entry.scope(diverId, 'r0');
    final clauses = [
      if (scope != null) scope.sql,
      if (parentId != null) 'r0.$parentColumn = ?',
    ];
    final where = clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}';
    final variables = [
      if (scope != null)
        for (final p in scope.params) Variable<Object>(p),
      if (parentId != null) Variable<Object>(parentId),
    ];
    final count = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM ${entry.table} r0$where',
          variables: variables,
        )
        .getSingle();
    final rows = await _db
        .customSelect(
          'SELECT r0.id AS id FROM ${entry.table} r0$where '
          'ORDER BY ${entry.orderBy}, r0.id LIMIT ? OFFSET ?',
          variables: [
            ...variables,
            Variable<int>(limit),
            Variable<int>(offset),
          ],
        )
        .get();
    return RecordPage(
      ids: [for (final r in rows) r.read<String>('id')],
      total: count.read<int>('n'),
    );
  }
}
