import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Issue #509 cloud clear: freeing this device's footprint (3a) and the
/// full-backend wipe (3b).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  Uint8List b(String s) => Uint8List.fromList(s.codeUnits);

  test('deleteDeviceSyncFile removes only this device’s files (manifest, base '
      'parts, changesets)', () async {
    // dev1: a manifest, a base part, and a changeset -- all should go.
    cloud.seedFile(ChangesetLogLayout.manifestName('dev1'), b('m1'));
    cloud.seedFile(ChangesetLogLayout.basePartName('dev1', 0, 0), b('bp1'));
    cloud.seedFile(ChangesetLogLayout.changesetName('dev1', 5), b('cs1'));
    // dev2: must survive.
    cloud.seedFile(ChangesetLogLayout.manifestName('dev2'), b('m2'));

    await buildService().deleteDeviceSyncFile('dev1');

    expect(cloud.bytesOf(ChangesetLogLayout.manifestName('dev1')), isNull);
    expect(
      cloud.bytesOf(ChangesetLogLayout.basePartName('dev1', 0, 0)),
      isNull,
    );
    expect(cloud.bytesOf(ChangesetLogLayout.changesetName('dev1', 5)), isNull);
    expect(
      cloud.bytesOf(ChangesetLogLayout.manifestName('dev2')),
      isNotNull,
      reason: 'other devices keep syncing',
    );
  });
}
