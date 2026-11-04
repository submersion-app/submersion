import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/documents/data/repositories/document_row_mapper.dart'
    show kDocumentOwnerColumns;
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwner;

/// Dive counts by owner, from [sql], which reads [id] as `?1` and [more]
/// from `?2` on, as [marksFrom2] writes them, and yields `owner` and `n`. A
/// dive with no owner counts under an empty key.
Future<Map<String, int>> countDivesByOwner(
  String sql,
  String id, [
  List<String> more = const [],
]) async {
  final rows = await DatabaseService.instance.database
      .customSelect(
        sql,
        variables: [
          for (final value in [id, ...more]) Variable.withString(value),
        ],
      )
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
          ? '"${key.column}" = ?1'
          : '"${key.column}" IN '
                '(SELECT "${key.target}" FROM "$parent" WHERE $scope)';
      (conditions[key.child] ??= {}).add(condition);
      walk(key.child, condition, {...path, key.child});
    }
  }

  walk(table, null, {table});
  return _counted(conditions, id, except);
}

/// What a delete of [id] of [table] takes and unlinks when its repository
/// also deletes the child tables in [byHand], whose keys have no action:
/// [parts] are the rows deleted at any depth, cascaded or by hand, and
/// [unlinked] the rows that stay and lose a link to any of them. Tables in
/// [except] are left out of both.
Future<({Map<String, int> parts, Map<String, int> unlinked})> countDeleted(
  String table,
  String id, {
  required Set<String> byHand,
  Set<String> except = const {},
}) async {
  final keys = await _foreignKeys();
  final deleted = <String, Set<String>>{};
  final unlinked = <String, Set<String>>{};
  void walk(String parent, String? scope, Set<String> path) {
    for (final key in keys) {
      if (key.parent != parent) continue;
      final takes = key.cascades || byHand.contains(key.child);
      // A key back into the path, such as a side trip's parent trip, is
      // only ever an unlink; following it would never end.
      if (takes && path.contains(key.child)) continue;
      final condition = scope == null
          ? '"${key.column}" = ?1'
          : '"${key.column}" IN '
                '(SELECT "${key.target}" FROM "$parent" WHERE $scope)';
      if (takes) {
        (deleted[key.child] ??= {}).add(condition);
        walk(key.child, condition, {...path, key.child});
      } else {
        (unlinked[key.child] ??= {}).add(condition);
      }
    }
  }

  walk(table, null, {table});
  return (
    parts: await _counted(deleted, id, except),
    unlinked: await _counted(unlinked, id, {...except, ...deleted.keys}),
  );
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
    (conditions[key.child] ??= {}).add('"${key.column}" = ?1');
  }
  return _counted(conditions, id, except);
}

/// Rows matching any of a table's conditions, so a row two links reach counts
/// once. One statement for every table: a reach is read again at apply, inside
/// the write transaction.
Future<Map<String, int>> _counted(
  Map<String, Set<String>> conditions,
  String id,
  Set<String> except,
) async {
  final tables = [
    for (final MapEntry(key: table, value: where) in conditions.entries)
      if (!except.contains(table)) (table: table, where: where.join(' OR ')),
  ];
  if (tables.isEmpty) return const {};
  final row = await DatabaseService.instance.database
      .customSelect(
        'SELECT ${[for (final (i, t) in tables.indexed) '(SELECT COUNT(*) FROM "${t.table}" WHERE ${t.where}) AS c$i'].join(', ')}',
        variables: [Variable.withString(id)],
      )
      .getSingle();
  return {
    for (final (i, t) in tables.indexed)
      if (row.read<int>('c$i') > 0) t.table: row.read<int>('c$i'),
  };
}

/// How many rows of [table] match [where], which reads [id] as `?1` and
/// [more] from `?2` on, as [marksFrom2] writes them.
Future<int> countRows(
  String table,
  String where,
  String id, [
  List<String> more = const [],
]) async {
  final row = await DatabaseService.instance.database
      .customSelect(
        'SELECT COUNT(*) AS n FROM "$table" WHERE $where',
        variables: [
          for (final value in [id, ...more]) Variable.withString(value),
        ],
      )
      .getSingle();
  return row.read<int>('n');
}

/// The placeholders for [count] values bound after the id: `?2, ?3, ...`.
String marksFrom2(int count) =>
    [for (var i = 0; i < count; i++) '?${i + 2}'].join(', ');

typedef _ForeignKey = ({
  String child,
  String column,
  String parent,
  String target,
  bool cascades,
});

final _foreignKeysByDatabase = Expando<Future<List<_ForeignKey>>>();

/// Every foreign key in the schema, read once per database. A read that fails
/// is not kept, so the next delete tries again.
Future<List<_ForeignKey>> _foreignKeys() {
  final db = DatabaseService.instance.database;
  final held = _foreignKeysByDatabase[db];
  if (held != null) return held;
  final read = _readForeignKeys(db);
  _foreignKeysByDatabase[db] = read;
  read.then(
    (_) {},
    onError: (Object _) {
      if (identical(_foreignKeysByDatabase[db], read)) {
        _foreignKeysByDatabase[db] = null;
      }
    },
  );
  return read;
}

Future<List<_ForeignKey>> _readForeignKeys(AppDatabase db) => db
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

/// How many documents [owners] hold between them: the documents a delete
/// takes with it.
Future<int> countDocuments(List<DocumentOwner> owners) async {
  var count = 0;
  for (final owner in owners) {
    final column = kDocumentOwnerColumns[owner.kind];
    final id = owner.id;
    if (column == null || id == null) continue;
    count += await countRows('documents', '"$column" = ?1', id);
  }
  return count;
}

/// How many rows of each table hang off [id], from table to its link column.
/// Tables with none are left out.
Future<Map<String, int>> countOwned(
  Map<String, String> links,
  String id,
) async {
  final counts = <String, int>{};
  for (final MapEntry(key: table, value: column) in links.entries) {
    final count = await countRows(table, '"$column" = ?1', id);
    if (count > 0) counts[table] = count;
  }
  return counts;
}
