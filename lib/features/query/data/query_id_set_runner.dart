import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/utils/stream_debounce.dart';

/// A clause the CALLER applies beside a compiled query, over its root alias
/// (`r0`): visibility-style narrowing that compares rows with the active
/// diver, which a saved query must not name. Values are bound.
typedef QueryScope = ({String sql, List<Object> params});

/// Runs any entity's [CompiledQuery] as an id set (#2365 PR 3). The site,
/// equipment and trip lists narrow their hydrated rows to it, so loading,
/// sorting and grouping stay where they are.
class QueryIdSetRunner {
  QueryIdSetRunner(this._db);

  final AppDatabase _db;

  /// The same debounce the dive list's ticks use.
  static const changeTickDebounce = Duration(milliseconds: 300);

  Future<Set<String>> ids(CompiledQuery compiled, {QueryScope? scope}) async {
    final a = compiled.rootAlias;
    final clauses = [
      if (!compiled.isEmpty) compiled.where,
      if (scope != null) scope.sql,
    ];
    final where = clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}';
    final rows = await _db
        .customSelect(
          'SELECT $a.${compiled.idColumn} AS id FROM ${compiled.table} $a'
          '$where',
          variables: [
            for (final p in compiled.params) Variable<Object>(p as Object),
            if (scope != null)
              for (final p in scope.params) Variable<Object>(p),
          ],
          readsFrom: tablesNamed(compiled.tablesTouched),
        )
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  /// Drift tables by their SQL names, for `readsFrom` and [watchTables].
  Set<TableInfo> tablesNamed(Set<String> names) => {
    for (final n in names)
      _db.allTables.firstWhere(
        (t) => t.actualTableName == n,
        orElse: () => throw ArgumentError.value(n, 'names', 'unknown table'),
      ),
  };

  /// A debounced tick over exactly [names].
  Stream<void> watchTables(Set<String> names) => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          for (final t in tablesNamed(names)) TableUpdateQuery.onTable(t),
        ]),
      )
      .debounce(changeTickDebounce);
}
