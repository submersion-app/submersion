@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/database.dart';

import '../web_test_assets.dart';

/// Reads around write transactions on the browser database must answer
/// (issue #4121). This suite runs on IndexedDB, since `flutter test` serves
/// without the isolation headers; the first run's stall was drift 2.34.3's
/// locked OPFS mode on a nested transaction (drift issue #3870), which the
/// smoke runner's fresh first-run test covers on an isolated page. The
/// nested case here pins the same shape on the storage the suite has.
void main() {
  const path = '/opfs/Submersion/transaction-test.db';

  final previousAssetBase = BackgroundDatabaseConnection.assetBase;
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
  });
  tearDownAll(() {
    BackgroundDatabaseConnection.assetBase = previousAssetBase;
  });

  test('a read answers after a write transaction', () async {
    final connection = await BackgroundDatabaseConnection.open(path);
    final db = AppDatabase(connection.connection);
    addTearDown(db.close);
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS tx_probe (id INTEGER PRIMARY KEY, v TEXT)',
    );
    await db.transaction(() async {
      await db.customStatement("INSERT INTO tx_probe (v) VALUES ('a')");
      await db.customStatement("INSERT INTO tx_probe (v) VALUES ('b')");
    });
    final count = await db
        .customSelect('SELECT count(*) AS n FROM tx_probe')
        .getSingle()
        .timeout(const Duration(seconds: 15));
    expect(count.read<int>('n'), greaterThanOrEqualTo(2));
  });

  test('a read issued while a transaction runs answers once it ends', () async {
    final connection = await BackgroundDatabaseConnection.open(path);
    final db = AppDatabase(connection.connection);
    addTearDown(db.close);
    late Future<int> concurrent;
    await db.transaction(() async {
      await db.customStatement("INSERT INTO tx_probe (v) VALUES ('c')");
      concurrent = db
          .customSelect('SELECT count(*) AS n FROM tx_probe')
          .getSingle()
          .then((row) => row.read<int>('n'));
      await db.customStatement("INSERT INTO tx_probe (v) VALUES ('d')");
    });
    expect(
      await concurrent.timeout(const Duration(seconds: 15)),
      greaterThanOrEqualTo(2),
    );
    final after = await db
        .customSelect('SELECT count(*) AS n FROM tx_probe')
        .getSingle()
        .timeout(const Duration(seconds: 15));
    expect(after.read<int>('n'), greaterThanOrEqualTo(4));
  });

  test('a transaction nested in another commits and reads back', () async {
    final connection = await BackgroundDatabaseConnection.open(path);
    final db = AppDatabase(connection.connection);
    addTearDown(db.close);
    await db
        .transaction(() async {
          await db.customStatement("INSERT INTO tx_probe (v) VALUES ('e')");
          await db.transaction(() async {
            await db.customStatement("INSERT INTO tx_probe (v) VALUES ('f')");
          });
        })
        .timeout(const Duration(seconds: 15));
    final rows = await db
        .customSelect("SELECT v FROM tx_probe WHERE v IN ('e', 'f')")
        .get()
        .timeout(const Duration(seconds: 15));
    expect(rows.map((r) => r.read<String>('v')).toSet(), {'e', 'f'});
  });
}
