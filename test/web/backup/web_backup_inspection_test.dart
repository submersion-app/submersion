@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/scratch_database.dart';
import 'package:submersion/features/backup/data/services/backup_image_inspection.dart';

import '../web_test_assets.dart';

/// A browser restore reads a backup's bytes in the page's memory before it
/// swaps them in (issue #4121).
void main() {
  final previousAssetBase = BackgroundDatabaseConnection.assetBase;
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
  });
  tearDownAll(() {
    BackgroundDatabaseConnection.assetBase = previousAssetBase;
  });

  test('the page reads a backup held in memory', () async {
    final image = await withScratchDatabase((db) async {
      db.execute('CREATE TABLE dive_sites (id TEXT)');
      db.execute('PRAGMA user_version = 311');
    });

    final info = await inspectBackupImage(image);

    expect(info.hasSubmersionTables, isTrue);
    expect(info.schemaVersion, 311);
  });
}
