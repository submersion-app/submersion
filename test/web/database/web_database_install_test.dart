@TestOn('browser')
library;

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/background_database_connection_web.dart';
import 'package:submersion/core/database/scratch_database_web.dart';

import '../web_test_assets.dart';

/// A schema-less database at the image's version, so opening it runs no
/// migration.
class _ImageDatabase extends GeneratedDatabase {
  _ImageDatabase(super.e);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 5;
}

/// The bytes of a database at schema version 5 holding [notes], with its
/// header flagged WAL as a copy of a WAL-mode file is.
Future<Uint8List> walImage(List<String> notes) async {
  final bytes = await withScratchDatabase((scratch) async {
    scratch.execute('CREATE TABLE image_probe (note TEXT)');
    for (final note in notes) {
      scratch.execute('INSERT INTO image_probe (note) VALUES (?)', [note]);
    }
    scratch.execute('PRAGMA user_version = 5');
  });
  return Uint8List.fromList(bytes)
    ..[18] = 2
    ..[19] = 2;
}

Future<List<String>> readNotes(String path) async {
  final connection = await BackgroundDatabaseConnection.open(path);
  final db = _ImageDatabase(connection.connection);
  try {
    final rows = await db
        .customSelect('SELECT note FROM image_probe ORDER BY rowid')
        .get();
    return [for (final row in rows) row.read<String>('note')];
  } finally {
    await db.close();
  }
}

/// Restore and the sample logbook create a browser database from bytes
/// (issue #4121): drift writes the image when the name holds no database,
/// so an install replaces whatever was stored under it.
void main() {
  const path = '/opfs/Submersion/install-test.db';

  final previousAssetBase = BackgroundDatabaseConnection.assetBase;
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
  });
  tearDownAll(() {
    BackgroundDatabaseConnection.assetBase = previousAssetBase;
  });
  tearDown(() => BackgroundDatabaseConnection.deleteStoredDatabases(path));

  test('a WAL-flagged image installs and opens with its rows', () async {
    await BackgroundDatabaseConnection.installImage(
      path,
      await walImage(['first', 'second']),
    );

    expect(await BackgroundDatabaseConnection.readStoredSchemaVersion(path), 5);
    expect(await readNotes(path), ['first', 'second']);
  });

  test('an install replaces the database stored under the name', () async {
    await BackgroundDatabaseConnection.installImage(
      path,
      await walImage(['old']),
    );
    await BackgroundDatabaseConnection.installImage(
      path,
      await walImage(['new']),
    );

    expect(await readNotes(path), ['new']);
  });

  test('bytes that are not SQLite are refused and nothing is stored', () async {
    await expectLater(
      BackgroundDatabaseConnection.installImage(
        path,
        Uint8List.fromList(List.filled(200, 7)),
      ),
      throwsFormatException,
    );
    expect(await BackgroundDatabaseConnection.readStoredSchemaVersion(path), 0);
  });
}
