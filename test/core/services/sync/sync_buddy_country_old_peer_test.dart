import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// A peer below v372 republishes a buddy without `country` and
/// `countryCode` (issue #4457). Its edit must apply, and the country this
/// device holds must survive, as cross_version_roundtrip_test.dart proves
/// for the columns of earlier rungs.
void main() {
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  test('an old-peer edit applies AND the country survives', () async {
    final created = await BuddyRepository().createBuddy(
      Buddy(
        id: '',
        name: 'Marco',
        country: 'Italy',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final row = (await SyncDataSerializer().fetchRecord(
      'buddies',
      created.id,
    ))!;
    expect(row['country'], 'Italy', reason: 'precondition');
    await SyncRepository().resetSyncState();

    // A pre-372 peer's republished shape: the keys are absent, not null.
    final peerRow = Map<String, dynamic>.from(row)
      ..remove('country')
      ..remove('countryCode')
      ..['name'] = 'Marco Rossi'
      ..['hlc'] = Hlc(
        Hlc.parse(row['hlc'] as String).physicalTime + 60000,
        0,
        'peer-pre372',
      ).toString()
      ..['updatedAt'] = (row['updatedAt'] as int) + 60000;

    final data = SyncData(buddies: [peerRow]);
    final payload = SyncPayload(
      version: syncFormatVersion,
      exportedAt: 9000,
      deviceId: 'peer-pre372',
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: const {},
    );
    await seedPeerBaseFromPayload(cloud, 'peer-pre372', payload);
    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(result.status, isNot(SyncResultStatus.error));

    final after = await BuddyRepository().getBuddyById(created.id);
    expect(after!.name, 'Marco Rossi');
    expect(after.country, 'Italy');
    expect(after.countryCode, 'IT');
  });
}
