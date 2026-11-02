import 'package:sqlite3/sqlite3.dart' show Database;

import 'package:submersion/features/agent_access/data/sql/sql_denied_set.dart';

/// A b-tree in the database file: a table, or an index on one.
class SqlRoot {
  const SqlRoot({
    required this.table,
    this.index,
    this.denied = false,
    this.deniedColumns = const {},
  });

  final String table;

  /// Null for the table's own b-tree.
  final String? index;

  /// No statement may open this b-tree.
  final bool denied;

  /// Column position to name, for a table that is readable but for these. An
  /// index cursor never carries one: an index holding a denied column is
  /// [denied], because a seek reads the value without a `Column` step.
  final Map<int, String> deniedColumns;
}

/// Every b-tree in the file by root page, as [inspectSqlProgram] needs it.
class SqlReadCatalog {
  const SqlReadCatalog(this._roots);

  final Map<int, SqlRoot> _roots;

  SqlRoot? root(int page) => _roots[page];

  /// Reads the catalogue from [db]. Call it inside the transaction the
  /// statement runs in, so the root pages match the program.
  factory SqlReadCatalog.load(Database db) {
    final marks = kSqlDeniedColumns.map((_) => '?').join(', ');
    final columns = kSqlDeniedColumns.toList();

    // A table holding a denied column, with where the column sits.
    final positions = <String, Map<int, String>>{};
    final wholeTable = <String>{};
    for (final row in db.select(
      'SELECT m.name AS tbl, x.name AS col, x.cid AS cid '
      'FROM sqlite_schema m, pragma_table_xinfo(m.name) x '
      "WHERE m.type = 'table' AND x.name IN ($marks)",
      columns,
    )) {
      final table = row['tbl'] as String;
      (positions[table] ??= {})[row['cid'] as int] = row['col'] as String;
    }
    // `Column` numbers storage slots. Those equal the declared position only
    // on a rowid table with no generated column, so anything else is refused
    // whole rather than checked against the wrong slot.
    for (final table in positions.keys) {
      final shape = db.select(
        'SELECT '
        '(SELECT wr FROM pragma_table_list WHERE name = ? AND schema = ?) '
        'AS without_rowid, '
        '(SELECT count(*) FROM pragma_table_xinfo(?) WHERE hidden != 0) '
        'AS generated',
        [table, 'main', table],
      ).first;
      if (shape['without_rowid'] != 0 || shape['generated'] != 0) {
        wholeTable.add(table);
      }
    }

    // Indexes over a denied column, expression indexes included: a NULL
    // column name means an expression, which might be over anything.
    final deniedIndexes = <String>{};
    for (final table in positions.keys) {
      for (final row in db.select(
        'SELECT l.name AS idx, x.name AS col, x.cid AS cid '
        'FROM pragma_index_list(?) l, pragma_index_xinfo(l.name) x '
        'WHERE x.key = 1',
        [table],
      )) {
        final column = row['col'] as String?;
        if (column == null || kSqlDeniedColumns.contains(column)) {
          deniedIndexes.add(row['idx'] as String);
        }
      }
    }

    final roots = <int, SqlRoot>{1: const SqlRoot(table: kSqlSchemaTable)};
    for (final row in db.select(
      'SELECT type, name, tbl_name, rootpage FROM sqlite_schema '
      "WHERE rootpage > 0 AND type IN ('table', 'index')",
    )) {
      final table = row['tbl_name'] as String;
      final isIndex = row['type'] == 'index';
      final name = row['name'] as String;
      final denied =
          !sqlTableReadable(table) ||
          wholeTable.contains(table) ||
          (isIndex && deniedIndexes.contains(name));
      roots[row['rootpage'] as int] = SqlRoot(
        table: table,
        index: isIndex ? name : null,
        denied: denied,
        deniedColumns: isIndex || denied
            ? const {}
            : positions[table] ?? const {},
      );
    }
    return SqlReadCatalog(roots);
  }
}
