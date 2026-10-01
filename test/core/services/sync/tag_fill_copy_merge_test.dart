import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/sync_test_helpers.dart';
import '../../../helpers/test_database.dart';

/// A fill read from an NFC tag (source nfc) is a copy of a fill logged on
/// some device, under the same id. The copy carries less (rounded values, no
/// notes), so whichever clock is newer, the original wins the merge (spec
/// section 11).
void main() {
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() {
    SyncClock.instance.reset();
    DatabaseService.instance.resetForTesting();
  });

  String hlcAt(int physical, String node) =>
      '${physical.toString().padLeft(15, '0')}:000000:$node';

  Map<String, dynamic> fill({
    required String source,
    required String hlc,
    required int updatedAt,
    String? notes,
    double o2 = 32.15,
  }) => {
    'id': 'fill-1',
    'diverId': null,
    'passportId': 'pp-1',
    'equipmentId': null,
    'filledAt': 1790000000000,
    'o2Percent': o2,
    'hePercent': 0.0,
    'pressureBar': 232.0,
    'temperatureC': null,
    'analyzer': null,
    'stationName': 'Blue Water Fills',
    'stationKey': null,
    'signedRecord': null,
    'source': source,
    'notes': notes,
    'createdAt': updatedAt,
    'updatedAt': updatedAt,
    'hlc': hlc,
  };

  Future<void> uploadPeer(
    Map<String, dynamic>? row, {
    Map<String, List<SyncDeletion>> deletions = const {},
  }) async {
    final data = SyncData(cylinderFills: [?row]);
    final payload = SyncPayload(
      version: syncFormatVersion,
      exportedAt: 1700000000000,
      deviceId: 'peer',
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: deletions,
    );
    await seedPeerBaseFromPayload(cloud, 'peer', payload);
  }

  Future<Map<String, dynamic>> syncAndRead() async {
    await impersonateFreshDevice();
    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(result.status, isNot(SyncResultStatus.error));
    return (await SyncDataSerializer().fetchRecord('cylinderFills', 'fill-1'))!;
  }

  test('the original keeps its place over a newer tag copy', () async {
    await SyncDataSerializer().upsertRecord(
      'cylinderFills',
      fill(
        source: 'manual',
        hlc: hlcAt(1000, 'origin'),
        updatedAt: 1000,
        notes: 'topped',
      ),
    );
    await uploadPeer(
      fill(source: 'nfc', hlc: hlcAt(9000, 'peer'), updatedAt: 9000, o2: 32.2),
    );
    final row = await syncAndRead();
    expect(row['source'], 'manual');
    expect(row['notes'], 'topped');
    expect(row['o2Percent'], 32.15);
  });

  test('a tag copy gives way to the original, even an older one', () async {
    await SyncDataSerializer().upsertRecord(
      'cylinderFills',
      fill(source: 'nfc', hlc: hlcAt(9000, 'here'), updatedAt: 9000, o2: 32.2),
    );
    await uploadPeer(
      fill(
        source: 'manual',
        hlc: hlcAt(1000, 'peer'),
        updatedAt: 1000,
        notes: 'topped',
      ),
    );
    final row = await syncAndRead();
    expect(row['source'], 'manual');
    expect(row['notes'], 'topped');
  });

  test('a tag copy never brings back a fill deleted here', () async {
    await SyncDataSerializer().upsertRecord(
      'cylinderFills',
      fill(source: 'manual', hlc: hlcAt(1000, 'here'), updatedAt: 1000),
    );
    // A peer that never saw the delete taps the tag afterwards: its copy is
    // newer than the deletion by every clock.
    final later = DateTime.now().millisecondsSinceEpoch + 86400000;
    await uploadPeer(
      fill(source: 'nfc', hlc: hlcAt(later, 'peer'), updatedAt: later),
    );
    // After the fresh-device reset, which clears the deletion log.
    await impersonateFreshDevice();
    await CylinderFillRepository().delete('fill-1');
    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(result.status, isNot(SyncResultStatus.error));
    expect(
      await SyncDataSerializer().fetchRecord('cylinderFills', 'fill-1'),
      isNull,
    );
  });

  test("a peer's delete removes a tag copy here, with no conflict", () async {
    // Copied from the tag after the peer deleted the fill, so the copy is
    // newer than the deletion.
    final later = DateTime.now().millisecondsSinceEpoch + 86400000;
    await SyncDataSerializer().upsertRecord(
      'cylinderFills',
      fill(source: 'nfc', hlc: hlcAt(later, 'here'), updatedAt: later),
    );
    await uploadPeer(
      null,
      deletions: {
        'cylinderFills': [const SyncDeletion(id: 'fill-1', deletedAt: 1000)],
      },
    );
    await impersonateFreshDevice();
    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(result.status, isNot(SyncResultStatus.error));
    expect(result.conflictsFound, 0);
    expect(
      await SyncDataSerializer().fetchRecord('cylinderFills', 'fill-1'),
      isNull,
    );
  });

  test('two originals still merge by their clocks', () async {
    await SyncDataSerializer().upsertRecord(
      'cylinderFills',
      fill(source: 'manual', hlc: hlcAt(1000, 'here'), updatedAt: 1000),
    );
    await uploadPeer(
      fill(
        source: 'manual',
        hlc: hlcAt(9000, 'peer'),
        updatedAt: 9000,
        notes: 'edited',
      ),
    );
    expect((await syncAndRead())['notes'], 'edited');
  });
}
