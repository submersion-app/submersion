import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/services/database_service.dart';

/// Dive counts by owner, from [sql], which takes [id] and yields `owner` and
/// `n`. A dive with no owner counts under an empty key.
Future<Map<String, int>> countDivesByOwner(String sql, String id) async {
  final rows = await DatabaseService.instance.database
      .customSelect(sql, variables: [Variable.withString(id)])
      .get();
  return {
    for (final row in rows)
      row.readNullable<String>('owner') ?? '': row.read<int>('n'),
  };
}

/// How many rows of each table hang off [id], from table to its link column.
/// Tables with none are left out.
Future<Map<String, int>> countOwned(
  Map<String, String> links,
  String id,
) async {
  final counts = <String, int>{};
  for (final MapEntry(key: table, value: column) in links.entries) {
    final row = await DatabaseService.instance.database
        .customSelect(
          'SELECT COUNT(*) AS n FROM $table WHERE $column = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    final count = row.read<int>('n');
    if (count > 0) counts[table] = count;
  }
  return counts;
}
