@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_image.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/database/scratch_database.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/web_library_paths.dart';

import '../web_test_assets.dart';

/// A browser restore (issue #4121) installs the backup under a new name and
/// moves the browser's preference only once it opens: the old library stays
/// put until then, and is swept up after.
void main() {
  final previousAssetBase = BackgroundDatabaseConnection.assetBase;
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
  });
  tearDownAll(() {
    BackgroundDatabaseConnection.assetBase = previousAssetBase;
  });

  late SharedPreferences prefs;

  Future<AppDatabase> openLibrary() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await DatabaseService.instance.initialize(
      locationService: DatabaseLocationService(prefs),
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS restore_probe (note TEXT)',
    );
    await db.customStatement('DELETE FROM restore_probe');
    await db.customStatement(
      "INSERT INTO restore_probe (note) VALUES ('backed up')",
    );
    return db;
  }

  Future<String> note() async =>
      (await DatabaseService.instance.database
              .customSelect('SELECT note FROM restore_probe')
              .getSingle())
          .read<String>('note');

  tearDown(() async {
    await DatabaseService.instance.close();
    DatabaseService.instance.resetForTesting();
    for (final name
        in await BackgroundDatabaseConnection.storedDatabaseNames()) {
      await BackgroundDatabaseConnection.deleteStoredDatabases(
        '/opfs/Submersion/$name.db',
      );
    }
  });

  test('a restore opens the backup under a new name, then points the '
      'browser at it and removes the old library', () async {
    final db = await openLibrary();
    final image = await readDatabaseImage(db);
    await db.customStatement("UPDATE restore_probe SET note = 'edited later'");

    await DatabaseService.instance.restoreImage(image);

    final restored = await DatabaseService.instance.databasePath;
    expect(restored, isNot(kWebDatabasePath));
    expect(DatabaseLocationService(prefs).webLibraryPath, restored);
    expect(await note(), 'backed up');
    expect(
      await BackgroundDatabaseConnection.storedDatabaseNames(),
      isNot(contains('submersion')),
      reason: 'the replaced library is deleted once nothing holds it',
    );
  });

  test('a backup that does not open leaves the library and the preference '
      'as they were', () async {
    await openLibrary();
    final newer = await withScratchDatabase((scratch) async {
      scratch.execute('CREATE TABLE dives (id TEXT)');
      scratch.execute(
        'PRAGMA user_version = ${AppDatabase.currentSchemaVersion + 1}',
      );
    });

    await expectLater(
      DatabaseService.instance.restoreImage(newer),
      throwsA(isA<DatabaseVersionMismatchException>()),
    );

    expect(await DatabaseService.instance.databasePath, kWebDatabasePath);
    expect(DatabaseLocationService(prefs).webLibraryPath, kWebDatabasePath);
    expect(await note(), 'backed up');
    expect(
      supersededWebLibraryNames(
        await BackgroundDatabaseConnection.storedDatabaseNames(),
        activePath: kWebDatabasePath,
      ),
      isEmpty,
      reason: 'the image that failed to open is not left behind',
    );
  });
}
