import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/services/change_log_settler.dart';
import 'package:submersion/features/documents/data/services/equipment_file_converter.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

import '../../core/database/change_log/change_log_support.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await insertDiver(db, 'diver');
  });
  tearDown(tearDownTestDatabase);

  Future<void> forgetSetup() async {
    await ChangeLogSettler(db).settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  }

  Future<List<ChangeLogOperationRow>> operations() async {
    await ChangeLogSettler(db).settle();
    return db.select(db.changeLogOperations).get();
  }

  test('the gear file conversion logs under automatic', () async {
    await db.customStatement(
      'INSERT INTO equipment (id, diver_id, name, type, created_at, '
      "updated_at) VALUES ('gear', 'diver', 'Perdix', 'computer', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO media (id, equipment_id, file_path, original_filename, '
      "file_type, created_at, updated_at) VALUES ('file', 'gear', "
      "'/x/Invoice.pdf', 'Invoice.pdf', 'document', 0, 0)",
    );
    await forgetSetup();

    await EquipmentFileConverter(
      readBytes: (_) async => Uint8List.fromList([1, 2, 3]),
      prefs: prefs,
    ).run();

    final all = await operations();
    expect(all, isNotEmpty);
    expect(all.map((o) => o.source).toSet(), {ChangeLogSource.automatic.name});
    expect(all.map((o) => o.label).toSet(), {
      ChangeLogLabels.gearFileConversion,
    });
  });

  test('stamping cloud ids logs under automatic', () async {
    await db.customStatement(
      "INSERT INTO media (id, file_path, file_type, platform_asset_id, created_at, "
      "updated_at) VALUES ('m1', 'x', 'photo', 'asset', 0, 0)",
    );
    await forgetSetup();

    await MediaRepository().stampCloudAssetIds([
      (id: 'm1', platformAssetId: 'asset', cloudAssetId: 'cloud-1'),
    ]);

    final operation = (await operations()).single;
    expect(operation.source, ChangeLogSource.automatic.name);
    expect(operation.label, ChangeLogLabels.galleryBackfill);
  });

  test('a job that only stamps bookkeeping logs nothing', () async {
    await db.customStatement(
      "INSERT INTO media (id, file_path, file_type, platform_asset_id, created_at, "
      "updated_at) VALUES ('m1', 'x', 'photo', 'asset', 0, 0)",
    );
    await forgetSetup();
    final device = await SyncRepository().getDeviceId();

    await db.customStatement(
      "UPDATE media SET origin_device_id = '$device' WHERE id = 'm1'",
    );

    expect(await operations(), isEmpty);
  });
}
