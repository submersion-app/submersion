import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// The exact `SyncData.toJson` key set of the last released build
/// (v1.4.9.95). Released builds computed their payload checksum over a JSON
/// document containing ONLY these 32 keys, so accepting their files means
/// validating against the writer's encoding, not this build's.
const legacySyncDataKeys = [
  'divers',
  'diverSettings',
  'dives',
  'diveProfiles',
  'diveTanks',
  'diveEquipment',
  'diveWeights',
  'diveSites',
  'equipment',
  'equipmentSets',
  'equipmentSetItems',
  'media',
  'buddies',
  'diveBuddies',
  'certifications',
  'serviceRecords',
  'diveCenters',
  'trips',
  'liveaboardDetails',
  'itineraryDays',
  'tags',
  'diveTags',
  'diveTypes',
  'tankPresets',
  'diveComputers',
  'tankPressureProfiles',
  'tideRecords',
  'settings',
  'species',
  'sightings',
  'diveProfileEvents',
  'gasSwitches',
];

/// Serialize a payload exactly the way a released (pre-per-device-expansion)
/// build did: 32 data keys, checksum over that 32-key document, hand-built
/// envelope with no fields this build may have added since.
Uint8List craftLegacyFile(
  String deviceId,
  List<Map<String, dynamic>> dives, {
  int version = 2,
}) {
  final dataMap = <String, dynamic>{
    for (final key in legacySyncDataKeys) key: <Map<String, dynamic>>[],
  };
  dataMap['dives'] = dives;
  final checksum = sha256.convert(utf8.encode(jsonEncode(dataMap))).toString();
  final envelope = <String, dynamic>{
    'version': version,
    'exportedAt': 1700000000000,
    'deviceId': deviceId,
    'lastSyncTimestamp': null,
    'checksum': checksum,
    'data': dataMap,
    'deletions': <String, dynamic>{},
  };
  return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  /// A valid dive JSON map (as produced by export) with the given id.
  /// Mirrors sync_per_device_files_test.dart.
  Future<Map<String, dynamic>> validDiveMap(String id) async {
    final diveRepo = DiveRepository();
    await diveRepo.createDive(createTestDiveWithBottomTime(id: id));
    final exported = await SyncDataSerializer().exportData(
      deviceId: 'seed',
      deletions: const [],
    );
    final map = exported.data.dives.firstWhere((d) => d['id'] == id);
    await diveRepo.deleteDive(id);
    await SyncRepository().resetSyncState();
    return map;
  }

  group('legacy payload compatibility', () {
    test('validateChecksum accepts a 32-key legacy payload', () async {
      final dive = await validDiveMap('legacy-dive-1');
      final bytes = craftLegacyFile('legacy-device', [dive]);

      final payload = SyncDataSerializer().deserializePayload(
        utf8.decode(bytes),
      );

      expect(
        SyncDataSerializer().validateChecksum(payload),
        isTrue,
        reason:
            'the checksum must be validated against the writer\'s own '
            'encoding (32 keys), not this build\'s re-serialization (39 keys)',
      );
    });

    test('performSync merges a legacy shared file end to end', () async {
      final dive = await validDiveMap('legacy-dive-2');
      cloud.seedFile(
        'submersion_sync.json',
        craftLegacyFile('old-phone', [dive]),
      );

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      final merged = await DiveRepository().getDiveById('legacy-dive-2');
      expect(
        merged,
        isNotNull,
        reason: 'the legacy file\'s dive must arrive in the local database',
      );
    });

    test('rejects a tampered legacy payload', () async {
      final dive = await validDiveMap('legacy-dive-3');
      final bytes = craftLegacyFile('legacy-device', [dive]);
      // Flip the dive's id after the checksum was computed.
      final doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      ((doc['data'] as Map<String, dynamic>)['dives'] as List).first['id'] =
          'tampered';
      final payload = SyncDataSerializer().deserializePayload(jsonEncode(doc));

      expect(SyncDataSerializer().validateChecksum(payload), isFalse);
    });

    test('skips payloads from a newer format version', () async {
      final dive = await validDiveMap('future-dive');
      cloud.seedFile(
        'submersion_sync_future-device.json',
        craftLegacyFile('future-device', [
          dive,
        ], version: syncFormatVersion + 1),
      );

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(
        await DiveRepository().getDiveById('future-dive'),
        isNull,
        reason:
            'a payload written by a NEWER format must be skipped, not '
            'half-applied with undefined semantics',
      );
    });

    test('deletes the legacy shared file after merging it', () async {
      final dive = await validDiveMap('legacy-dive-4');
      cloud.seedFile(
        'submersion_sync.json',
        craftLegacyFile('old-phone', [dive]),
      );

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(
        await cloud.fileExists('submersion_sync.json'),
        isFalse,
        reason:
            'after its data is merged (and re-exported into our per-device '
            'file) the legacy shared file must be cleaned up -- left in '
            'place it is re-merged forever and resurrects deletions once '
            'their tombstones age out. A still-active old device recreates '
            'it on its next sync (uploads are full snapshots), so nothing '
            'is lost.',
      );
    });

    test('deletes a legacy file this device itself authored', () async {
      // Single-device upgrader: the canonical file was written by THIS
      // device before the upgrade. It is skipped as own data but must
      // still be cleaned up.
      final deviceId = await SyncRepository().getDeviceId();
      cloud.seedFile('submersion_sync.json', craftLegacyFile(deviceId, []));

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(await cloud.fileExists('submersion_sync.json'), isFalse);
    });

    test('keeps a legacy-named file it could not parse', () async {
      cloud.seedFile(
        'submersion_sync.json',
        Uint8List.fromList(utf8.encode('not json at all')),
      );

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(
        await cloud.fileExists('submersion_sync.json'),
        isTrue,
        reason:
            'an unparseable file was NOT merged; deleting it would discard '
            'data sight-unseen',
      );
    });
  });
}
