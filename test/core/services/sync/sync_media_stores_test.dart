import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Sync replication for `media_stores` (media store Phase 1, spec
/// 2026-07-10). Like `certifications`, this table carries its own `hlc`
/// column, so its export uses the simple hlc-filter pattern.
void main() {
  group('media_stores sync', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    String hlcAt(int physical, String node) =>
        '${physical.toString().padLeft(15, '0')}:000000:$node';

    Map<String, dynamic> storeRow(String id, {required String hlc}) => {
      'id': id,
      'providerType': 's3',
      'displayHint': 'dive-media @ minio.example.com',
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': hlc,
    };

    test('full export includes a media_stores row', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'mediaStores',
        storeRow('store-1', hlc: hlcAt(1000, 'dev-a')),
      );

      final payload = await serializer.exportData(
        deviceId: 'dev-a',
        deletions: const [],
      );

      final ids = payload.data.mediaStores.map((r) => r['id']).toSet();
      expect(ids, contains('store-1'));
    });

    test('round trip: wipe and re-import restores providerType and '
        'displayHint', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'mediaStores',
        storeRow('store-1', hlc: hlcAt(1000, 'dev-a')),
      );

      final payload = await serializer.exportData(
        deviceId: 'dev-a',
        deletions: const [],
      );
      final exportedRow = payload.data.mediaStores.singleWhere(
        (r) => r['id'] == 'store-1',
      );

      final db = DatabaseService.instance.database;
      await serializer.deleteAllRecords('mediaStores');
      expect(
        await (db.select(
          db.mediaStores,
        )..where((t) => t.id.equals('store-1'))).getSingleOrNull(),
        isNull,
        reason: 'sanity: the wipe actually removed the row',
      );

      await serializer.upsertRecord('mediaStores', exportedRow);

      final restored = await (db.select(
        db.mediaStores,
      )..where((t) => t.id.equals('store-1'))).getSingle();
      expect(restored.providerType, 's3');
      expect(restored.displayHint, 'dive-media @ minio.example.com');
    });

    test('incremental export: only rows with hlc > watermark are '
        'included', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'mediaStores',
        storeRow('store-old', hlc: hlcAt(1000, 'dev-a')),
      );
      await serializer.upsertRecord(
        'mediaStores',
        storeRow('store-new', hlc: hlcAt(9000, 'dev-a')),
      );

      final changeset = await serializer.exportChangeset(
        deviceId: 'dev-a',
        hlcWatermark: hlcAt(5000, 'dev-a'),
        deletions: const [],
      );

      final ids = changeset.data.mediaStores.map((r) => r['id']).toSet();
      expect(ids, contains('store-new'));
      expect(ids, isNot(contains('store-old')));
    });

    test('end to end: a peer-published store descriptor replicates via '
        'performSync', () async {
      final cloud = FakeCloudStorageProvider();
      final data = SyncData(
        mediaStores: [storeRow('store-1', hlc: hlcAt(1000, 'peer-dev'))],
      );
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-dev',
        checksum: sha256
            .convert(utf8.encode(jsonEncode(data.toJson())))
            .toString(),
        data: data,
        deletions: const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      ).performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final db = DatabaseService.instance.database;
      final restored = await (db.select(
        db.mediaStores,
      )..where((t) => t.id.equals('store-1'))).getSingleOrNull();
      expect(restored, isNotNull);
      expect(restored!.providerType, 's3');
    });

    test('per-record plumbing: fetchRecord, recordIdsFor, deleteRecord, '
        'and SyncData.fromJson all handle mediaStores', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'mediaStores',
        storeRow('store-1', hlc: hlcAt(1000, 'dev-a')),
      );

      final fetched = await serializer.fetchRecord('mediaStores', 'store-1');
      expect(fetched, isNotNull);
      expect(fetched!['displayHint'], 'dive-media @ minio.example.com');

      final missing = await serializer.fetchRecord('mediaStores', 'nope');
      expect(missing, isNull);

      expect(await serializer.recordIdsFor('mediaStores'), {'store-1'});

      final payload = await serializer.exportData(
        deviceId: 'dev-a',
        deletions: const [],
      );
      final rehydrated = SyncData.fromJson(payload.data.toJson());
      expect(rehydrated.mediaStores.map((r) => r['id']), contains('store-1'));

      await serializer.deleteRecord('mediaStores', 'store-1');
      expect(await serializer.recordIdsFor('mediaStores'), isEmpty);
    });
  });
}
