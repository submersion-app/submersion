@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/wasm.dart';

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_image.dart';

import '../web_test_assets.dart';

/// A browser's backup is a copy of the live database's schema and rows into
/// an in-memory SQLite database in the page (issue #4121): drift keeps the
/// file where a page cannot read it, so the copy comes back as bytes that a
/// second in-memory sqlite3 opens again.
void main() {
  const path = '/opfs/Submersion/submersion.db';

  final previousAssetBase = BackgroundDatabaseConnection.assetBase;
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
  });
  tearDownAll(() {
    BackgroundDatabaseConnection.assetBase = previousAssetBase;
  });

  test(
    'the image is a SQLite file at the current schema version that opens again',
    () async {
      final connection = await BackgroundDatabaseConnection.open(path);
      final db = AppDatabase(connection.connection);
      addTearDown(db.close);
      await db.customStatement(
        'CREATE TABLE IF NOT EXISTS image_probe '
        '(id INTEGER PRIMARY KEY, note TEXT, weight REAL, raw BLOB)',
      );
      await db.customStatement('DELETE FROM image_probe');
      await db.customStatement(
        "INSERT INTO image_probe (note, weight, raw) "
        "VALUES ('hello', 1.5, X'00FF10')",
      );

      final image = await readDatabaseImage(db);

      expect(String.fromCharCodes(image.sublist(0, 16)), 'SQLite format 3\x00');
      expect(databaseImageUserVersion(image), AppDatabase.currentSchemaVersion);

      // Written into an in-memory file system the way sqlite3 itself writes,
      // then opened by a second sqlite3 beside drift's worker.
      final sqlite = await WasmSqlite3.loadFromUrl(
        Uri.parse('${kWebTestAssetBase}sqlite3.wasm'),
      );
      final files = InMemoryFileSystem();
      final file = files
          .xOpen(
            Sqlite3Filename('/image.db'),
            SqlFlag.SQLITE_OPEN_READWRITE | SqlFlag.SQLITE_OPEN_CREATE,
          )
          .file;
      file.xWrite(image, 0);
      file.xClose();
      sqlite.registerVirtualFileSystem(files, makeDefault: true);
      final reopened = sqlite.open('/image.db');
      addTearDown(reopened.close);

      final row = reopened.select('SELECT * FROM image_probe').single;
      expect(row['note'], 'hello');
      expect(row['weight'], 1.5);
      expect(row['raw'], [0x00, 0xFF, 0x10]);
      expect(
        reopened
            .select(
              "SELECT count(*) AS n FROM sqlite_master WHERE type = 'trigger'",
            )
            .single['n'],
        greaterThan(0),
      );
    },
  );
}
