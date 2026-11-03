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

/// Rows [ON DELETE CASCADE] takes with [id] of [table], by table, however deep.
/// The schema is the source, so a child table added later is counted without
/// anyone remembering to. Tables with none, and those in [except], are left
/// out.
Future<Map<String, int>> countCascaded(
  String table,
  String id, {
  Set<String> except = const {},
}) async {
  final keys = await _foreignKeys();
  final conditions = <String, Set<String>>{};
  void walk(String parent, String? scope, Set<String> path) {
    for (final key in keys) {
      if (key.parent != parent || !key.cascades) continue;
      if (path.contains(key.child)) continue;
      final condition = scope == null
          ? '${key.column} = ?1'
          : '${key.column} IN '
                '(SELECT ${key.target} FROM $parent WHERE $scope)';
      (conditions[key.child] ??= {}).add(condition);
      walk(key.child, condition, {...path, key.child});
    }
  }

  walk(table, null, {table});
  return _counted(conditions, id, except);
}

/// Rows that stay when [id] of [table] goes but lose their link to it, by
/// table: a `SET NULL` key clears itself, and one with no action has to be
/// cleared by the repository or the delete fails. Tables with none, and those
/// in [except], are left out.
Future<Map<String, int>> countUnlinked(
  String table,
  String id, {
  Set<String> except = const {},
}) async {
  final conditions = <String, Set<String>>{};
  for (final key in await _foreignKeys()) {
    if (key.parent != table || key.cascades) continue;
    (conditions[key.child] ??= {}).add('${key.column} = ?1');
  }
  return _counted(conditions, id, except);
}

/// Rows matching any of a table's conditions, so a row two links reach counts
/// once.
Future<Map<String, int>> _counted(
  Map<String, Set<String>> conditions,
  String id,
  Set<String> except,
) async {
  final counts = <String, int>{};
  for (final MapEntry(key: table, value: where) in conditions.entries) {
    if (except.contains(table)) continue;
    final count = await countRows(table, where.join(' OR '), id);
    if (count > 0) counts[table] = count;
  }
  return counts;
}

/// How many rows of [table] match [where], which reads [id] as `?1`.
Future<int> countRows(String table, String where, String id) async {
  final row = await DatabaseService.instance.database
      .customSelect(
        'SELECT COUNT(*) AS n FROM $table WHERE $where',
        variables: [Variable.withString(id)],
      )
      .getSingle();
  return row.read<int>('n');
}

typedef _ForeignKey = ({
  String child,
  String column,
  String parent,
  String target,
  bool cascades,
});

final _foreignKeysByDatabase = Expando<Future<List<_ForeignKey>>>();

/// Every foreign key in the schema, read once per database.
Future<List<_ForeignKey>> _foreignKeys() {
  final db = DatabaseService.instance.database;
  return _foreignKeysByDatabase[db] ??= db
      .customSelect(
        'SELECT m.name AS child, f."from" AS col, f."table" AS parent, '
        "COALESCE(f.\"to\", 'id') AS target, f.on_delete AS action "
        'FROM sqlite_master m, pragma_foreign_key_list(m.name) f '
        "WHERE m.type = 'table'",
      )
      .get()
      .then(
        (rows) => [
          for (final row in rows)
            (
              child: row.read<String>('child'),
              column: row.read<String>('col'),
              parent: row.read<String>('parent'),
              target: row.read<String>('target'),
              cascades: row.read<String>('action') == 'CASCADE',
            ),
        ],
      );
}

/// How many rows of each table hang off [id], from table to its link column.
/// Tables with none are left out.
Future<Map<String, int>> countOwned(
  Map<String, String> links,
  String id,
) async {
  final counts = <String, int>{};
  for (final MapEntry(key: table, value: column) in links.entries) {
    final count = await countRows(table, '$column = ?1', id);
    if (count > 0) counts[table] = count;
  }
  return counts;
}
