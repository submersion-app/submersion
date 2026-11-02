@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/platform/web_database_status.dart';

import '../web_test_assets.dart';

/// The browser database end to end: drift's WasmDatabase in the compiled
/// worker, the app's schema, the app's SQL functions, and persistence across
/// a close and reopen.
void main() {
  const path = '/opfs/Submersion/submersion.db';

  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
  });

  test('opens AppDatabase on WasmDatabase and creates the schema', () async {
    final connection = await BackgroundDatabaseConnection.open(path);
    final db = AppDatabase(connection.connection);
    addTearDown(db.close);
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.read<int>('user_version'), AppDatabase.currentSchemaVersion);
    final status = WebDatabaseStatusHolder.current;
    expect(status, isNotNull, reason: 'the open records what drift chose');
    expect(status!.persists, isTrue, reason: '$status');
  });

  test('the app SQL functions resolve in the worker', () async {
    final connection = await BackgroundDatabaseConnection.open(path);
    final db = AppDatabase(connection.connection);
    addTearDown(db.close);
    final lower = await db
        .customSelect("SELECT unicode_lower('ÄB') AS v")
        .getSingle();
    expect(lower.read<String>('v'), 'äb');
    final digest = await db
        .customSelect("SELECT row_digest('a', 'b') AS v")
        .getSingle();
    expect(digest.read<String>('v'), isNotEmpty);
  });

  test('a row written before close is read back after reopen', () async {
    final first = await BackgroundDatabaseConnection.open(path);
    final db1 = AppDatabase(first.connection);
    await db1.customStatement(
      'CREATE TABLE IF NOT EXISTS web_probe (id INTEGER PRIMARY KEY, note TEXT)',
    );
    await db1.customStatement("INSERT INTO web_probe (note) VALUES ('hello')");
    await db1.close();

    final second = await BackgroundDatabaseConnection.open(path);
    final db2 = AppDatabase(second.connection);
    addTearDown(db2.close);
    final rows = await db2.customSelect('SELECT note FROM web_probe').get();
    expect(rows.map((r) => r.read<String>('note')), ['hello']);
    await db2.customStatement('DROP TABLE web_probe');
  });

  test('an encryption key is refused in the browser', () {
    expect(
      () => BackgroundDatabaseConnection.open(path, keyHex: '00'),
      throwsArgumentError,
    );
  });
}
