import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart' show TankRole, WeightType;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Issue #4651: a bulk edit of a dive's child rows reaches peers without
/// restamping the dive, so a peer's newer edit to that dive survives this
/// device's sync, no stale copy of the dive is published, and the child
/// change itself still travels. One case per bulk writer family.
void main() {
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  /// A synced dive 'd1' named 'Original' with tank 't1' and course 'c1',
  /// beside gear 'e1' (also the one item of set 's1'), tag 'tag1' and a
  /// later course 'c2' to add.
  Future<void> seedSyncedDive() async {
    final repository = DiveRepository();
    await repository.createDive(
      createTestDiveWithBottomTime(
        id: 'd1',
        diveNumber: 1,
      ).copyWith(name: 'Original'),
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id, tank_role) '
      "VALUES ('t1', 'd1', 'backGas')",
    );
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('e1', 'Wing', 'bcd', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO equipment_sets (id, name, created_at, updated_at) '
      "VALUES ('s1', 'Warm water', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO equipment_set_items (set_id, equipment_id) '
      "VALUES ('s1', 'e1')",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at) '
      "VALUES ('tag1', 'Night', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('diver-1', 'D', 1, 1)",
    );
    for (final (id, day) in [('c1', 1), ('c2', 2)]) {
      await db.customStatement(
        'INSERT INTO courses (id, diver_id, name, agency, start_date, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, 1, 1)',
        [id, 'diver-1', 'Course $id', 'tdi', day],
      );
    }
    await repository.bulkAddCourses(['d1'], ['c1']);
    final first = await buildService().performSync();
    expect(first.status, isNot(SyncResultStatus.error), reason: 'precondition');
  }

  /// Every [entity] row a peer rebuilds from this device's log: its base,
  /// then each changeset after it in order.
  Future<List<Map<String, dynamic>>> publishedRows(String entity) async {
    final deviceId = await SyncRepository().getDeviceId();
    final manifest = (await ownManifest(cloud, deviceId))!;
    final rows = <Map<String, dynamic>>[];
    void overlay(SyncData data) {
      rows.addAll(
        ((data.toJson()[entity] as List?) ?? const [])
            .cast<Map<String, dynamic>>(),
      );
    }

    final base = await cloudBasePayload(cloud, deviceId);
    if (base != null) overlay(base.data);
    final folder = await cloud.getOrCreateSyncFolder();
    final files = await cloud.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    final changesets =
        [
          for (final f in files)
            if (f.name.contains(deviceId) &&
                (ChangesetLogLayout.changesetSeqOf(f.name) ?? 0) >
                    (manifest.baseSeq ?? 0))
              f,
        ]..sort(
          (a, b) => ChangesetLogLayout.changesetSeqOf(
            a.name,
          )!.compareTo(ChangesetLogLayout.changesetSeqOf(b.name)!),
        );
    const codec = ChangesetCodec();
    for (final f in changesets) {
      overlay(
        ((await codec.decodeVerifiedChangeset(
          await cloud.downloadFile(f.id),
        )).payload).data,
      );
    }
    return rows;
  }

  final cases =
      <
        (
          String,
          Future<void> Function(DiveRepository),
          String,
          bool Function(Map<String, dynamic>),
        )
      >[
        (
          'tank roles',
          (r) => r.setTankRoles(['t1'], TankRole.twinSet),
          'diveTanks',
          (row) => row['id'] == 't1' && row['tankRole'] == 'twinSet',
        ),
        (
          'weights',
          (r) => r.bulkAddWeights(
            ['d1'],
            [
              const domain.DiveWeight(
                id: '',
                diveId: '',
                weightType: WeightType.belt,
                amountKg: 4,
              ),
            ],
          ),
          'diveWeights',
          (row) => row['diveId'] == 'd1',
        ),
        (
          'tags',
          (r) => r.bulkAddTags(['d1'], ['tag1']),
          'diveTags',
          (row) => row['diveId'] == 'd1' && row['tagId'] == 'tag1',
        ),
        (
          'dive types',
          (r) => r.bulkAddDiveTypes(['d1'], ['night']),
          'diveDiveTypes',
          (row) => row['diveId'] == 'd1' && row['diveTypeId'] == 'night',
        ),
        (
          'courses',
          (r) => r.bulkAddCourses(['d1'], ['c2']),
          'diveCourses',
          (row) => row['diveId'] == 'd1' && row['courseId'] == 'c2',
        ),
        (
          'gear',
          (r) => r.bulkReplaceEquipment(['d1'], ['e1']),
          'diveEquipment',
          (row) => row['diveId'] == 'd1' && row['equipmentId'] == 'e1',
        ),
        (
          'equipment set',
          (r) => r.bulkAddEquipmentSets(['d1'], ['s1']),
          'diveEquipment',
          (row) =>
              row['diveId'] == 'd1' &&
              row['equipmentId'] == 'e1' &&
              row['viaSetId'] == 's1',
        ),
      ];

  for (final (family, edit, entity, matches) in cases) {
    test('a peer\'s newer rename survives a bulk $family edit', () async {
      await seedSyncedDive();
      final serializer = SyncDataSerializer();
      final synced = (await serializer.fetchRecord('dives', 'd1'))!;
      final ours = Hlc.parse(synced['hlc'] as String);

      // Device B renames the dive while this device is offline: newer than
      // the copy both devices share, older than the bulk edit made here.
      final theirs = {
        ...synced,
        'name': 'Renamed by B',
        'hlc': Hlc(ours.physicalTime + 1, 0, 'peer-b').toString(),
      };
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await edit(DiveRepository());

      final peerData = SyncData(dives: [theirs]);
      await seedPeerBaseFromPayload(
        cloud,
        'peer-b',
        SyncPayload(
          version: syncFormatVersion,
          exportedAt: 9000,
          deviceId: 'peer-b',
          checksum: sha256
              .convert(utf8.encode(jsonEncode(peerData.toJson())))
              .toString(),
          data: peerData,
          deletions: const {},
        ),
      );

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final dive = (await serializer.fetchRecord('dives', 'd1'))!;
      expect(
        dive['name'],
        'Renamed by B',
        reason: 'a bulk child edit must not outrank a real edit made elsewhere',
      );
      final published = await publishedRows('dives');
      expect(
        published.where((r) => r['id'] == 'd1').last['name'],
        isNot('Original'),
        reason: 'a stale copy of the dive must not be published',
      );
      expect(
        (await publishedRows(entity)).any(matches),
        isTrue,
        reason: 'the bulk edit itself is published',
      );
    });
  }
}
