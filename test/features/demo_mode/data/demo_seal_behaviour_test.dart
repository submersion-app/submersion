import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

import '../../../helpers/global_test_defaults.dart';

Matcher sealed(DemoSealedFeature feature) => throwsA(
  isA<DemoModeSealedException>().having((e) => e.feature, 'feature', feature),
);

void main() {
  setUp(() => DemoModeGate.instance.debugActive = true);
  tearDown(applyGlobalTestDefaults);

  test('a cloud backend refuses every write in demo mode', () async {
    // Fails before reading credentials or opening a connection.
    final provider = WebDavStorageProvider();

    await expectLater(
      provider.uploadFile(Uint8List(1), 'f.json'),
      sealed(DemoSealedFeature.sync),
    );
    await expectLater(
      provider.uploadFileFromPath('/nowhere', 'f.json'),
      sealed(DemoSealedFeature.sync),
    );
    await expectLater(
      provider.deleteFile('f.json'),
      sealed(DemoSealedFeature.sync),
    );
    await expectLater(
      provider.createFolder('Submersion Sync'),
      sealed(DemoSealedFeature.sync),
    );
  });

  test('exports refuse in demo mode', () async {
    await expectLater(
      saveTextToFile(
        'csv',
        'dives.csv',
        dialogTitle: 'Save',
        mimeType: 'text/csv',
      ),
      sealed(DemoSealedFeature.export),
    );
    await expectLater(
      saveAndShareFile('csv', 'dives.csv', 'text/csv'),
      sealed(DemoSealedFeature.share),
    );
  });

  test(
    'DatabaseService.restore refuses and leaves the open database usable',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      DatabaseService.instance.setTestDatabase(db);
      addTearDown(DatabaseService.instance.resetForTesting);
      addTearDown(db.close);

      await expectLater(
        DatabaseService.instance.restore('/nowhere/backup.db'),
        sealed(DemoSealedFeature.restore),
      );
      expect(identical(DatabaseService.instance.database, db), isTrue);
      await db.customSelect('SELECT 1').get();
    },
  );

  test('a reset of the database file refuses', () async {
    await expectLater(
      DatabaseService.instance.resetDatabase(backupPath: '/nowhere'),
      sealed(DemoSealedFeature.databaseFile),
    );
  });
}
