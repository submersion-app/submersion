/// Decides whether a compiled statement may run, from SQLite's own view of it.
///
/// The bundled SQLite is built with `OMIT_AUTHORIZATION`, so no authorizer
/// callback exists. `EXPLAIN` is what remains: it lists the program SQLite
/// will run, and a view, a CTE and a subquery have all been flattened into it
/// by then, so a read through any of them opens the same root page as a
/// direct read. Matching names in the SQL text would miss all three.
library;

import 'package:submersion/features/agent_access/data/sql/sql_read_catalog.dart';

/// The statements that return rows. `ATTACH`, `BEGIN` and `PRAGMA` all report
/// read-only, so that flag cannot stand in for this list.
const Set<String> kSqlAllowedKeywords = {'SELECT', 'WITH', 'VALUES'};

/// `OPFLAG_P2ISREG`: the root page is in a register, not in P2.
const int _rootInRegister = 0x10;

/// One instruction of an `EXPLAIN` listing.
class SqlExplainStep {
  const SqlExplainStep({
    required this.opcode,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p5,
  });

  final String opcode;
  final int p1;
  final int p2;
  final int p3;
  final int p5;
}

/// Why a statement may not run. Names structure, never a row value.
class SqlRefusal {
  const SqlRefusal(this.message, {this.details = const {}});

  final String message;
  final Map<String, Object?> details;
}

/// The first keyword of [sql] in upper case, or null when there is none.
///
/// Skips exactly what SQLite's tokenizer skips before a statement, so what
/// this returns is the keyword SQLite will see. Anything it cannot read, such
/// as a comment that never closes, answers null and is refused.
String? sqlLeadingKeyword(String sql) {
  var i = 0;
  while (i < sql.length) {
    final unit = sql[i];
    if (unit == ' ' ||
        unit == '\t' ||
        unit == '\n' ||
        unit == '\r' ||
        unit == '\f') {
      i++;
    } else if (sql.startsWith('--', i)) {
      final end = sql.indexOf('\n', i);
      if (end < 0) return null;
      i = end + 1;
    } else if (sql.startsWith('/*', i)) {
      final end = sql.indexOf('*/', i + 2);
      if (end < 0) return null;
      i = end + 2;
    } else {
      break;
    }
  }
  final start = i;
  while (i < sql.length && _isLetter(sql.codeUnitAt(i))) {
    i++;
  }
  return i == start ? null : sql.substring(start, i).toUpperCase();
}

bool _isLetter(int unit) =>
    (unit >= 0x41 && unit <= 0x5a) || (unit >= 0x61 && unit <= 0x7a);

/// The first reason [program] may not run against [catalog], or null.
///
/// Fails closed: a root the catalogue does not know, a cursor on anything but
/// the main database, and every virtual table are refused. A cursor no
/// `OpenRead` opened, such as a sorter's, needs no check, because its rows
/// could only have come through a read that was checked here.
SqlRefusal? inspectSqlProgram(
  List<SqlExplainStep> program,
  SqlReadCatalog catalog,
) {
  final cursors = <int, SqlRoot>{};
  for (final step in program) {
    switch (step.opcode) {
      case 'OpenRead' || 'ReopenIdx':
        if (step.p3 != 0 || step.p5 & _rootInRegister != 0) {
          return const SqlRefusal(
            'This statement reads outside the main database.',
          );
        }
        final root = catalog.root(step.p2);
        if (root == null) {
          return const SqlRefusal('This statement reads an unknown table.');
        }
        if (root.denied) return _deniedTable(root);
        cursors[step.p1] = root;
      case 'OpenDup':
        final source = cursors[step.p2];
        if (source != null) cursors[step.p1] = source;
      case 'OpenWrite':
        return const SqlRefusal('Only read-only statements may run.');
      case 'VOpen':
        return const SqlRefusal(
          'Virtual tables, including pragma_ and json_each, are not available '
          'here.',
        );
      case 'Column':
        final refusal = _deniedColumn(cursors[step.p1], step.p2);
        if (refusal != null) return refusal;
      // A whole record, so every column it holds.
      case 'RowData' when cursors[step.p1]?.deniedColumns.isNotEmpty ?? false:
        final root = cursors[step.p1]!;
        return _deniedColumn(root, root.deniedColumns.keys.first);
      case 'IsType' when step.p1 >= 0:
        final refusal = _deniedColumn(cursors[step.p1], step.p3);
        if (refusal != null) return refusal;
    }
  }
  return null;
}

SqlRefusal _deniedTable(SqlRoot root) => SqlRefusal(
  'The table ${root.table} is not available to the SQL window.',
  details: {'table': root.table},
);

SqlRefusal? _deniedColumn(SqlRoot? root, int position) {
  final column = root?.deniedColumns[position];
  if (column == null) return null;
  return SqlRefusal(
    'The column ${root!.table}.$column is not available to the SQL window. '
    'Name the columns you need instead of using *.',
    details: {'table': root.table, 'column': column},
  );
}
