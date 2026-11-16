import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';

/// What a diver sees of an entry another diver owns (issue #4527).
///
/// A diver's editing sitting is one entry about the record it was opened
/// on, whoever owns the other records it wrote. Another diver who owns one
/// of those records, or has it shared with them, sees the entry too, but
/// only its rows about such records, and titled with one of them: the
/// sitting's own record may be private to its owner.
abstract final class ChangeLogSharedView {
  /// Each table a diver can share, with its share table and that table's
  /// column naming the record.
  static const _shareable = {
    'dive_sites': ('site_shares', 'site_id'),
    'equipment': ('equipment_shares', 'equipment_id'),
    'trips': ('trip_shares', 'trip_id'),
  };

  /// Whether the root of an event [events] is a record [diverId] owns or
  /// that is shared with them.
  static ({String sql, List<Variable<Object>> variables}) seenRoot(
    String events,
    String diverId,
  ) {
    final clauses = [
      for (final MapEntry(key: table, value: (shares, key))
          in _shareable.entries)
        "($events.root_table = '$table' AND $events.root_id IN "
            '(SELECT $key FROM $shares WHERE diver_id = ? '
            'UNION SELECT id FROM $table WHERE diver_id = ?))',
    ];
    return (
      sql: '(${clauses.join(' OR ')})',
      variables: [
        for (var i = 0; i < clauses.length * 2; i++) Variable<Object>(diverId),
      ],
    );
  }

  /// [operations] as [diverId] reads them: an entry another diver owns
  /// keeps only the records of it [diverId] sees, and is titled with one of
  /// them, its own record if they see that. An entry with no such record,
  /// a summary for one, is left whole.
  static Future<List<ChangeLogOperation>> asSeenBy(
    AppDatabase db,
    List<ChangeLogOperation> operations,
    String diverId,
  ) async => [
    for (final operation in operations)
      operation.diverId == null || operation.diverId == diverId
          ? operation
          : await _restricted(db, operation, diverId),
  ];

  static Future<ChangeLogOperation> _restricted(
    AppDatabase db,
    ChangeLogOperation operation,
    String diverId,
  ) async {
    final seen = seenRoot('e', diverId);
    final rows = await db
        .customSelect(
          'SELECT e.root_table, e.root_id, MIN(e.id) AS first '
          'FROM change_log_events e WHERE e.operation_id = ? '
          'AND ${seen.sql} GROUP BY e.root_table, e.root_id ORDER BY first',
          variables: [Variable<String>(operation.id), ...seen.variables],
        )
        .get();
    if (rows.isEmpty) return operation;
    final shown = <ChangeLogRoot>{
      for (final row in rows)
        (
          table: row.read<String>('root_table'),
          id: row.read<String>('root_id'),
        ),
    };
    final ownTable = operation.rootTable;
    final ownId = operation.rootId;
    final own = ownTable == null || ownId == null
        ? null
        : (table: ownTable, id: ownId);
    if (own != null && shown.contains(own)) {
      return operation.restrictedTo(
        shown,
        root: own,
        label: operation.rootLabel,
      );
    }
    final root = shown.first;
    final name = await db
        .customSelect(
          'SELECT name FROM ${root.table} WHERE id = ?',
          variables: [Variable<String>(root.id)],
        )
        .getSingleOrNull();
    return operation.restrictedTo(
      shown,
      root: root,
      label: name?.readNullable<String>('name'),
    );
  }
}
