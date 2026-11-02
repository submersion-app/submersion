import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/scratch_database.dart';

/// The database as the bytes of one SQLite file: its schema and rows
/// copied, inside one transaction, into a scratch database that is read
/// back whole (issue #4121). Drift's browser storage keeps the file where a
/// page cannot read it and neither engine compiles SQLite's page table in,
/// so a copy is what both can do; natively only the tests use it.
///
/// Tables are created first, then every row is copied, then the indexes,
/// triggers and views: a trigger created before the rows would fire on the
/// copy, and an index built after them is built once.
Future<Uint8List> readDatabaseImage(
  GeneratedDatabase db, {
  int rowsPerRead = 5000,
}) => db.transaction(() async {
  final schema = await db
      .customSelect(
        'SELECT type, name, sql FROM sqlite_master '
        "WHERE sql IS NOT NULL AND substr(name, 1, 7) != 'sqlite_' "
        'ORDER BY rowid',
      )
      .get();
  final userVersion = (await db.customSelect('PRAGMA user_version').getSingle())
      .read<int>('user_version');
  final tables = [
    for (final row in schema)
      if (row.read<String>('type') == 'table') row,
  ];
  final others = [
    for (final row in schema)
      if (row.read<String>('type') != 'table') row,
  ];
  return withScratchDatabase((scratch) async {
    registerAppSqlFunctions(scratch);
    for (final table in tables) {
      scratch.execute(table.read<String>('sql'));
    }
    for (final table in tables) {
      await _copyRows(
        db,
        scratch,
        table.read<String>('name'),
        rowsPerRead,
        // A table declared WITHOUT ROWID cannot be read in pieces by it.
        byRowid: !RegExp(
          r'WITHOUT\s+ROWID',
          caseSensitive: false,
        ).hasMatch(table.read<String>('sql')),
      );
    }
    // AUTOINCREMENT counters live in a table SQLite creates on its own as
    // soon as a table with such a column exists, in the live database and
    // in the copy alike.
    // Copying rows with their ids has already set the copy's counters to
    // the ids it saw; the live counters, which remember deleted rows too,
    // replace them.
    if (_hasTable(scratch, 'sqlite_sequence')) {
      scratch.execute('DELETE FROM sqlite_sequence');
      await _copyRows(
        db,
        scratch,
        'sqlite_sequence',
        rowsPerRead,
        byRowid: true,
      );
    }
    for (final other in others) {
      scratch.execute(other.read<String>('sql'));
    }
    scratch.execute('PRAGMA user_version = $userVersion');
  });
});

/// The schema version stored in a database image's header (bytes 60 to 63,
/// big-endian), without opening it.
int databaseImageUserVersion(Uint8List image) =>
    ByteData.sublistView(image, 60, 64).getUint32(0);

const _rowidAlias = '__rowid__';

/// Copies [table]: in pieces of [rowsPerRead] rows ordered by rowid when
/// it has one, so a long table never has to fit in memory twice at once;
/// whole when it was declared WITHOUT ROWID.
Future<void> _copyRows(
  GeneratedDatabase db,
  CommonDatabase scratch,
  String table,
  int rowsPerRead, {
  required bool byRowid,
}) async {
  final name = _quote(table);
  CommonPreparedStatement? insert;
  int? after;
  try {
    while (true) {
      final rows = byRowid
          ? await db
                .customSelect(
                  'SELECT rowid AS ${_quote(_rowidAlias)}, * FROM $name '
                  '${after == null ? '' : 'WHERE rowid > ? '}'
                  'ORDER BY rowid LIMIT ?',
                  variables: [
                    if (after != null) Variable.withInt(after),
                    Variable.withInt(rowsPerRead),
                  ],
                )
                .get()
          : await db.customSelect('SELECT * FROM $name').get();
      if (rows.isEmpty) return;
      final columns = [
        for (final column in rows.first.data.keys)
          if (column != _rowidAlias) column,
      ];
      insert ??= scratch.prepare(
        'INSERT INTO $name (${columns.map(_quote).join(', ')}) '
        'VALUES (${List.filled(columns.length, '?').join(', ')})',
      );
      scratch.execute('BEGIN');
      for (final row in rows) {
        insert.execute([for (final column in columns) row.data[column]]);
      }
      scratch.execute('COMMIT');
      if (!byRowid || rows.length < rowsPerRead) return;
      after = rows.last.read<int>(_rowidAlias);
    }
  } finally {
    insert?.close();
  }
}

bool _hasTable(CommonDatabase scratch, String name) => scratch.select(
  "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
  [name],
).isNotEmpty;

String _quote(String identifier) => '"${identifier.replaceAll('"', '""')}"';
