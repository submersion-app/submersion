import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// A peer on an older build republishes a row without the columns its
/// schema lacks. The receiver used to fill each missing NOT NULL column with
/// its Drift default and write that over the value it held, so a diver's
/// setting went back to its default whenever an older device synced
/// (#2553). A missing key keeps the receiver's value; the default fills it
/// only for a row the receiver does not have.
void main() {
  late AppDatabase db;

  // A NOT NULL column with a constant default (v63), standing in for any
  // settings column newer than the peer.
  const newerKey = 'showDetailsPaneDives';

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Diver', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO diver_settings (id, diver_id, created_at, updated_at, "
      "show_details_pane_dives, depth_unit, hlc) "
      "VALUES ('ds-1', 'diver-1', 1, 1, 1, 'meters', "
      "'${const Hlc(1000, 0, 'local')}')",
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
    SyncClock.instance.reset();
  });

  Future<Map<String, dynamic>> row() async =>
      (await SyncDataSerializer().fetchRecord('diverSettings', 'ds-1'))!;

  /// [local] as an older build republishes it after editing the depth
  /// unit: no [newerKey], and a clock newer than the local row's.
  Map<String, dynamic> olderPeerEdit(Map<String, dynamic> local) =>
      Map<String, dynamic>.from(local)
        ..remove(newerKey)
        ..['depthUnit'] = 'feet'
        ..['updatedAt'] = 2
        ..['hlc'] = const Hlc(2000, 0, 'older-peer').toString();

  SyncPayload payload(SyncData data, int exportedAt) => SyncPayload(
    version: syncFormatVersion,
    exportedAt: exportedAt,
    deviceId: 'older-peer',
    checksum: sha256.convert(utf8.encode(jsonEncode(data.toJson()))).toString(),
    data: data,
    deletions: const {},
  );

  test('precondition: the local row holds a non-default value', () async {
    expect((await row())[newerKey], isTrue);
  });

  test('the merge applies the edit and keeps the newer column', () async {
    final cloud = FakeCloudStorageProvider();
    await SyncRepository().resetSyncState();
    final edit = olderPeerEdit(await row());
    await seedPeerBaseFromPayload(
      cloud,
      'older-peer',
      payload(SyncData(diverSettings: [edit]), 9000),
    );

    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();

    expect(result.status, isNot(SyncResultStatus.error));
    final after = await row();
    expect(after['depthUnit'], 'feet');
    expect(after[newerKey], isTrue);
  });

  test('upsertRecord keeps a column the payload omits', () async {
    final serializer = SyncDataSerializer();
    await serializer.upsertRecord('diverSettings', olderPeerEdit(await row()));

    final after = await row();
    expect(after['depthUnit'], 'feet');
    expect(after[newerKey], isTrue);
  });

  test('upsertRecords keeps a column the payload omits', () async {
    final serializer = SyncDataSerializer();
    await serializer.upsertRecords('diverSettings', [
      olderPeerEdit(await row()),
    ]);

    final after = await row();
    expect(after['depthUnit'], 'feet');
    expect(after[newerKey], isTrue);
  });

  test('an explicit value in the payload still wins', () async {
    final serializer = SyncDataSerializer();
    await serializer.upsertRecord('diverSettings', {
      ...olderPeerEdit(await row()),
      newerKey: false,
    });

    expect((await row())[newerKey], isFalse);
  });

  test('a row new to this device takes the column default', () async {
    final serializer = SyncDataSerializer();
    final born = olderPeerEdit(await row())..['id'] = 'ds-2';
    await serializer.upsertRecord('diverSettings', born);

    final created = await serializer.fetchRecord('diverSettings', 'ds-2');
    expect(created![newerKey], isFalse);
  });

  group('adopt', () {
    late SyncPayload newerBase;
    late SyncPayload olderEdit;

    setUp(() async {
      final local = await row();
      newerBase = payload(
        SyncData(
          divers: [
            (await SyncDataSerializer().fetchRecord('divers', 'diver-1'))!,
          ],
          diverSettings: [local],
        ),
        1000,
      );
      olderEdit = payload(
        SyncData(diverSettings: [olderPeerEdit(local)]),
        2000,
      );
    });

    SyncService service() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    );

    test('streaming: a later older-peer copy keeps the newer column', () async {
      await service().debugAdoptStreaming(const [], const [], [
        newerBase,
        olderEdit,
      ]);

      final after = await row();
      expect(after['depthUnit'], 'feet');
      expect(after[newerKey], isTrue);
    });

    test('in memory: a later older-peer copy keeps the newer column', () async {
      await service().debugAdoptInMemory([newerBase, olderEdit]);

      final after = await row();
      expect(after['depthUnit'], 'feet');
      expect(after[newerKey], isTrue);
    });
  });
}
