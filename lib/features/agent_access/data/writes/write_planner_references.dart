part of 'write_planner.dart';

/// How a pass marks the records a plan links to and names them, and
/// what it reads of a table to do so.
extension _References on _Pass {
  /// Adds a marker for each record a plan links to, so one that goes away
  /// after the preview refuses the plan instead of quietly not linking.
  Future<void> _markReferences(
    WritableEntry entry,
    Map<String, RelationDelta> deltas,
  ) async {
    for (final MapEntry(key: name, value: delta) in deltas.entries) {
      final table = records.named(entry.relations[name]!.refEntity).table;
      for (final id in delta.add) {
        await _markReference(table, id);
      }
    }
  }

  Future<void> _markReference(String table, String id) async {
    if (!_referenced.add((table, id))) return;
    if (!await _versioned(table)) {
      // Nothing to compare but whether the row is still there.
      markers.add(
        RecordMarker(
          table: table,
          id: id,
          updatedAt: null,
          versioned: false,
          footprint: await _presence(table, id),
          readFootprint: () => _presence(table, id),
        ),
      );
      return;
    }
    final row = await db
        .customSelect(
          'SELECT updated_at FROM $table WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    markers.add(
      RecordMarker(
        table: table,
        id: id,
        updatedAt: row?.read<int>('updated_at'),
      ),
    );
  }

  /// Whether [table] has an `updated_at` column.
  Future<bool> _versioned(String table) async =>
      (await _columnsOf(table)).contains('updated_at');

  /// The column names of [table].
  Future<Set<String>> _columnsOf(String table) async =>
      _tableColumns[table] ??= {
        for (final row
            in await db
                .customSelect(
                  'SELECT name FROM pragma_table_info(?)',
                  variables: [Variable.withString(table)],
                )
                .get())
          row.read<String>('name'),
      };

  /// The names of what a change links, so a diver reads names, not ids.
  Future<Map<String, String>> _names(
    WritableEntry entry,
    Map<String, RelationDelta> deltas,
    Map<String, Set<String>> indirect,
  ) async {
    final names = <String, String>{};
    for (final relation in {...deltas.keys, ...indirect.keys}) {
      final delta = deltas[relation];
      final ids = {...?delta?.add, ...?delta?.remove, ...?indirect[relation]};
      if (ids.isEmpty) continue;
      final table = records.named(entry.relations[relation]!.refEntity).table;
      final columns = await _columnsOf(table);
      // What the table calls a record: a species by its common name, a
      // preset by its display name.
      final name =
          const [
            'name',
            'common_name',
            'display_name',
          ].where(columns.contains).firstOrNull ??
          'id';
      for (final chunk in seriesIdChunks(ids.toList())) {
        final marks = List.filled(chunk.length, '?').join(', ');
        final rows = await db
            .customSelect(
              'SELECT id, $name AS title FROM $table WHERE id IN ($marks)',
              variables: [for (final id in chunk) Variable.withString(id)],
            )
            .get();
        for (final row in rows) {
          names[row.read<String>('id')] = row.read<String>('title');
        }
      }
    }
    return names;
  }
}
