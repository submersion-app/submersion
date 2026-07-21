import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Sync replication for `media_enrichment` (the depth/time association for a
/// linked photo). Like `media_stores`/`buddy_roles`, this table carries its
/// own `hlc` column, so its export uses the simple hlc-filter pattern. Unlike
/// them it is a child of both `media` and `dives`, so each fixture seeds those
/// parent rows first (FKs are enforced in the test database).
void main() {
  group('media_enrichment sync', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    String hlcAt(int physical, String node) =>
        '${physical.toString().padLeft(15, '0')}:000000:$node';

    Map<String, dynamic> mediaRow(String id, String diveId) => {
      'id': id,
      'diveId': diveId,
      'filePath': '/photos/$id.jpg',
      'fileType': 'photo',
      'sourceType': 'platformGallery',
      'isFavorite': false,
      'isOrphaned': false,
      'createdAt': 1000,
      'updatedAt': 1000,
    };

    Map<String, dynamic> enrichmentRow(
      String id, {
      required String mediaId,
      required String diveId,
      required String hlc,
    }) => {
      'id': id,
      'mediaId': mediaId,
      'diveId': diveId,
      'depthMeters': 18.3,
      'temperatureCelsius': 21.0,
      'elapsedSeconds': 600,
      'matchConfidence': 'exact',
      'timestampOffsetSeconds': 0,
      'createdAt': 1000,
      'hlc': hlc,
    };

    // Seeds a real dive (many required columns) via the repository helper, plus
    // a media row via the serializer, so an enrichment row's FKs resolve.
    Future<void> seedParents(
      SyncDataSerializer s, {
      required String diveId,
      required String mediaId,
    }) async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: diveId, diveNumber: 1),
      );
      await s.upsertRecord('media', mediaRow(mediaId, diveId));
    }

    test('full export includes a media_enrichment row', () async {
      final s = SyncDataSerializer();
      await seedParents(s, diveId: 'd1', mediaId: 'm1');
      await s.upsertRecord(
        'mediaEnrichment',
        enrichmentRow('e1', mediaId: 'm1', diveId: 'd1', hlc: hlcAt(1000, 'a')),
      );

      final payload = await s.exportData(deviceId: 'a', deletions: const []);

      expect(
        payload.data.mediaEnrichment.map((r) => r['id']).toSet(),
        contains('e1'),
      );
    });

    test(
      'round trip: wipe and re-import restores depth and confidence',
      () async {
        final s = SyncDataSerializer();
        await seedParents(s, diveId: 'd1', mediaId: 'm1');
        await s.upsertRecord(
          'mediaEnrichment',
          enrichmentRow(
            'e1',
            mediaId: 'm1',
            diveId: 'd1',
            hlc: hlcAt(1000, 'a'),
          ),
        );

        final payload = await s.exportData(deviceId: 'a', deletions: const []);
        final exported = payload.data.mediaEnrichment.singleWhere(
          (r) => r['id'] == 'e1',
        );

        final db = DatabaseService.instance.database;
        await s.deleteAllRecords('mediaEnrichment');
        expect(
          await (db.select(
            db.mediaEnrichment,
          )..where((t) => t.id.equals('e1'))).getSingleOrNull(),
          isNull,
          reason: 'sanity: the wipe actually removed the row',
        );

        await s.upsertRecord('mediaEnrichment', exported);

        final restored = await (db.select(
          db.mediaEnrichment,
        )..where((t) => t.id.equals('e1'))).getSingle();
        expect(restored.depthMeters, 18.3);
        expect(restored.matchConfidence, 'exact');
        expect(restored.diveId, 'd1');
      },
    );

    test(
      'incremental export: only rows with hlc > watermark are included',
      () async {
        final s = SyncDataSerializer();
        await seedParents(s, diveId: 'd1', mediaId: 'm1');
        await s.upsertRecord('media', mediaRow('m2', 'd1'));
        await s.upsertRecord(
          'mediaEnrichment',
          enrichmentRow(
            'e-old',
            mediaId: 'm1',
            diveId: 'd1',
            hlc: hlcAt(1000, 'a'),
          ),
        );
        await s.upsertRecord(
          'mediaEnrichment',
          enrichmentRow(
            'e-new',
            mediaId: 'm2',
            diveId: 'd1',
            hlc: hlcAt(9000, 'a'),
          ),
        );

        final changeset = await s.exportChangeset(
          deviceId: 'a',
          hlcWatermark: hlcAt(5000, 'a'),
          deletions: const [],
        );

        final ids = changeset.data.mediaEnrichment.map((r) => r['id']).toSet();
        expect(ids, contains('e-new'));
        expect(ids, isNot(contains('e-old')));
      },
    );

    test(
      'per-record plumbing: recordIdsFor, deleteRecord, SyncData.fromJson',
      () async {
        final s = SyncDataSerializer();
        await seedParents(s, diveId: 'd1', mediaId: 'm1');
        await s.upsertRecord(
          'mediaEnrichment',
          enrichmentRow(
            'e1',
            mediaId: 'm1',
            diveId: 'd1',
            hlc: hlcAt(1000, 'a'),
          ),
        );

        expect(await s.recordIdsFor('mediaEnrichment'), {'e1'});

        final payload = await s.exportData(deviceId: 'a', deletions: const []);
        final rehydrated = SyncData.fromJson(payload.data.toJson());
        expect(rehydrated.mediaEnrichment.map((r) => r['id']), contains('e1'));

        await s.deleteRecord('mediaEnrichment', 'e1');
        expect(await s.recordIdsFor('mediaEnrichment'), isEmpty);
      },
    );

    test(
      'end to end: a peer-published enrichment replicates via performSync',
      () async {
        // Parents already present locally (they synced earlier); the peer
        // publishes only the enrichment for them.
        await seedParents(SyncDataSerializer(), diveId: 'd1', mediaId: 'm1');

        final cloud = FakeCloudStorageProvider();
        final data = SyncData(
          mediaEnrichment: [
            enrichmentRow(
              'e1',
              mediaId: 'm1',
              diveId: 'd1',
              hlc: hlcAt(1000, 'peer-dev'),
            ),
          ],
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
          db.mediaEnrichment,
        )..where((t) => t.id.equals('e1'))).getSingleOrNull();
        expect(restored, isNotNull);
        expect(restored!.depthMeters, 18.3);
      },
    );
  });
}
