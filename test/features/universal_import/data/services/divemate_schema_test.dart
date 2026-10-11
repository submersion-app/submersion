import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/features/universal_import/data/services/divemate_schema.dart';

import '../../../../fixtures/divemate/build_divemate_ddb.dart';

/// A Diving Log logbook: the same `Logbook` table, written by Diving Log.
Uint8List _divingLogBytes({String? program, bool typeOfDive = false}) {
  final dir = Directory.systemTemp.createTempSync('divinglog_schema');
  addTearDown(() => dir.deleteSync(recursive: true));
  final path = p.join(dir.path, 'logbook.sql');
  final db = sqlite3.open(path);
  db.execute(
    'CREATE TABLE Logbook (ID INTEGER, Divedate TEXT'
    '${typeOfDive ? ', TypeOfDive INTEGER' : ''})',
  );
  if (program != null) {
    db.execute('CREATE TABLE DBInfo (PrgName TEXT)');
    db.execute('INSERT INTO DBInfo VALUES (?)', [program]);
  }
  db.close();
  return File(path).readAsBytesSync();
}

void main() {
  test('DBInfo naming DiveMate marks the file as DiveMate', () async {
    expect(await DiveMateSchema.isDiveMateDb(buildDiveMateDdb()), isTrue);
  });

  test('without DBInfo, the TypeOfDive column still marks it', () async {
    expect(
      await DiveMateSchema.isDiveMateDb(buildDiveMateDdb(withDbInfo: false)),
      isTrue,
    );
  });

  test('with DBInfo but no TypeOfDive, DBInfo alone marks it', () async {
    expect(
      await DiveMateSchema.isDiveMateDb(
        buildDiveMateDdb(withTypeOfDive: false),
      ),
      isTrue,
    );
  });

  test('a Diving Log logbook is not DiveMate', () async {
    expect(await DiveMateSchema.isDiveMateDb(_divingLogBytes()), isFalse);
    expect(
      await DiveMateSchema.isDiveMateDb(_divingLogBytes(program: 'Diving Log')),
      isFalse,
    );
  });

  test('DBInfo naming another program wins over a TypeOfDive column', () async {
    // The column is only a fallback for a file that does not say who wrote
    // it; a file that does is taken at its word.
    expect(
      await DiveMateSchema.isDiveMateDb(
        _divingLogBytes(program: 'Diving Log', typeOfDive: true),
      ),
      isFalse,
    );
  });

  test('bytes that are not SQLite are not DiveMate, without a throw', () async {
    expect(
      await DiveMateSchema.isDiveMateDb(Uint8List.fromList([1, 2, 3])),
      isFalse,
    );
  });
}
