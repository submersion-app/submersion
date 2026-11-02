@TestOn('browser')
library;

import 'package:drift/wasm.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/background_database_connection_web.dart';
import 'package:submersion/core/database/database.dart';

import '../web_test_assets.dart';

/// Forget this device deletes the database through drift's probe, in
/// whichever browser storage drift put it (issue #4121): afterwards the
/// probe lists no copy and a reopen starts from an empty schema.
void main() {
  const path = '/opfs/Submersion/wipe-test.db';

  final previousAssetBase = BackgroundDatabaseConnection.assetBase;
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
  });
  tearDownAll(() {
    BackgroundDatabaseConnection.assetBase = previousAssetBase;
  });

  test('deleteStoredDatabases removes what drift stored', () async {
    final first = await BackgroundDatabaseConnection.open(path);
    final db = AppDatabase(first.connection);
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS wipe_probe (id INTEGER PRIMARY KEY)',
    );
    await db.customStatement('INSERT INTO wipe_probe DEFAULT VALUES');
    await db.close();

    await BackgroundDatabaseConnection.deleteStoredDatabases(path);

    final name = BackgroundDatabaseConnection.databaseNameFor(path);
    final probe = await WasmDatabase.probe(
      sqlite3Uri: BackgroundDatabaseConnection.sqlite3Uri,
      driftWorkerUri: BackgroundDatabaseConnection.driftWorkerUri,
      databaseName: name,
    );
    expect(probe.existingDatabases.where((e) => e.$2 == name), isEmpty);

    final again = await BackgroundDatabaseConnection.open(path);
    final reopened = AppDatabase(again.connection);
    addTearDown(reopened.close);
    final tables = await reopened
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'wipe_probe'",
        )
        .get();
    expect(tables, isEmpty, reason: 'the reopened database is a fresh one');
  });
}
