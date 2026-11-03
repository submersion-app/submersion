import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_image.dart';

/// The database as bytes: its schema and rows copied inside one transaction
/// into a scratch database whose file comes back whole (issue #4121).
/// Proven here on the native engine, where the bytes can be written out and
/// opened again.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
  });

  tearDown(() => db.close());

  Future<sqlite3.Database> reopen(Uint8List image) async {
    final dir = await Directory.systemTemp.createTemp('database_image_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'image.db'));
    await file.writeAsBytes(image);
    final reopened = sqlite3.sqlite3.open(file.path);
    addTearDown(reopened.close);
    return reopened;
  }

  test(
    'starts with the SQLite header and carries the schema version',
    () async {
      final image = await readDatabaseImage(db);
      expect(String.fromCharCodes(image.sublist(0, 16)), 'SQLite format 3\x00');
      expect(databaseImageUserVersion(image), AppDatabase.currentSchemaVersion);
    },
  );

  test('holds every table, index, trigger and view of the schema', () async {
    final image = await readDatabaseImage(db);
    final reopened = await reopen(image);
    // SQLite's own tables (the autoincrement counters, the planner's
    // statistics) are not schema: the counters travel as rows, the
    // statistics come back with the next ANALYZE.
    const sql =
        'SELECT type, name FROM sqlite_master '
        "WHERE sql IS NOT NULL AND substr(name, 1, 7) != 'sqlite_' "
        'ORDER BY type, name';
    final live = [
      for (final row in await db.customSelect(sql).get())
        '${row.read<String>('type')} ${row.read<String>('name')}',
    ];
    final copied = [
      for (final row in reopened.select(sql)) '${row['type']} ${row['name']}',
    ];
    expect(copied, live);
    expect(live, contains(startsWith('trigger ')));
    expect(live, contains(startsWith('index ')));
    expect(
      reopened.select('PRAGMA user_version').single.columnAt(0),
      AppDatabase.currentSchemaVersion,
    );
  });

  test('keeps every value type of a row', () async {
    await db.customStatement(
      'CREATE TABLE image_probe '
      '(id INTEGER PRIMARY KEY, note TEXT, weight REAL, raw BLOB, gone TEXT)',
    );
    await db.customStatement(
      "INSERT INTO image_probe (note, weight, raw, gone) "
      "VALUES ('hello', 1.5, X'00FF10', NULL)",
    );
    final image = await readDatabaseImage(db);
    final row = (await reopen(
      image,
    )).select('SELECT * FROM image_probe').single;
    expect(row['id'], 1);
    expect(row['note'], 'hello');
    expect(row['weight'], 1.5);
    expect(row['raw'], [0x00, 0xFF, 0x10]);
    expect(row['gone'], isNull);
  });

  test('reads a table in pieces without losing or repeating rows', () async {
    await db.customStatement(
      'CREATE TABLE image_probe (id INTEGER PRIMARY KEY, note TEXT)',
    );
    for (var i = 1; i <= 5; i++) {
      await db.customStatement(
        "INSERT INTO image_probe (note) VALUES ('row $i')",
      );
    }
    final image = await readDatabaseImage(db, rowsPerRead: 2);
    final notes = [
      for (final row in (await reopen(
        image,
      )).select('SELECT note FROM image_probe ORDER BY id'))
        row['note'],
    ];
    expect(notes, ['row 1', 'row 2', 'row 3', 'row 4', 'row 5']);
  });

  test('triggers do not fire while the rows are copied', () async {
    await db.customStatement(
      'CREATE TABLE image_probe (id INTEGER PRIMARY KEY, note TEXT)',
    );
    await db.customStatement('CREATE TABLE probe_log (n INTEGER)');
    await db.customStatement(
      'CREATE TRIGGER probe_ai AFTER INSERT ON image_probe '
      'BEGIN INSERT INTO probe_log VALUES (1); END',
    );
    await db.customStatement("INSERT INTO image_probe (note) VALUES ('hello')");
    final image = await readDatabaseImage(db);
    final reopened = await reopen(image);
    expect(
      reopened.select('SELECT count(*) AS n FROM probe_log').single['n'],
      1,
    );
    expect(
      reopened
          .select(
            "SELECT count(*) AS n FROM sqlite_master WHERE name = 'probe_ai'",
          )
          .single['n'],
      1,
    );
  });

  test('copies a table declared without a rowid whole', () async {
    await db.customStatement(
      'CREATE TABLE norowid_probe (k TEXT PRIMARY KEY, v TEXT) WITHOUT ROWID',
    );
    await db.customStatement(
      "INSERT INTO norowid_probe VALUES ('a', '1'), ('b', '2'), ('c', '3')",
    );
    final image = await readDatabaseImage(db, rowsPerRead: 2);
    final values = [
      for (final row in (await reopen(
        image,
      )).select('SELECT v FROM norowid_probe ORDER BY k'))
        row['v'],
    ];
    expect(values, ['1', '2', '3']);
  });

  test('autoincrement counters carry over', () async {
    await db.customStatement(
      'CREATE TABLE seq_probe (id INTEGER PRIMARY KEY AUTOINCREMENT, v TEXT)',
    );
    await db.customStatement("INSERT INTO seq_probe (v) VALUES ('a'), ('b')");
    await db.customStatement('DELETE FROM seq_probe WHERE id = 2');
    final image = await readDatabaseImage(db);
    final reopened = await reopen(image);
    reopened.execute("INSERT INTO seq_probe (v) VALUES ('c')");
    expect(
      [
        for (final row in reopened.select(
          'SELECT id FROM seq_probe ORDER BY id',
        ))
          row['id'],
      ],
      [1, 3],
    );
  });
}
