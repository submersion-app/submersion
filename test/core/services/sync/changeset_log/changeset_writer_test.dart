import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

void main() {
  late FakeCloudStorageProvider provider;
  late ChangesetWriter writer;
  late String folder;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    final serializer = SyncDataSerializer();
    writer = ChangesetWriter(
      serializer,
      ChangesetCodec(serializer),
      PublishStateStore(db),
      compactionByteRatio: 1000.0,
      compactionMaxChangesets: 1 << 30,
    );
    provider = FakeCloudStorageProvider();
    folder = await provider.getOrCreateSyncFolder();
  });
  tearDown(() => tearDownTestDatabase());

  Future<ChangesetWriteResult> publish() async {
    final deviceId = await SyncRepository().getDeviceId();
    final deletions = await SyncRepository().getAllDeletions();
    return writer.publish(
      provider: provider,
      deviceId: deviceId,
      folderId: folder,
      deletions: deletions,
    );
  }

  Future<List<String>> names() async {
    final files = await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    return files.map((f) => f.name).toList();
  }

  test('first publish with data writes a base + manifest', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.base);

    final deviceId = await SyncRepository().getDeviceId();
    final ns = await names();
    expect(ns, contains(ChangesetLogLayout.manifestName(deviceId)));
    expect(ns.any((n) => ChangesetLogLayout.basePartOf(n) != null), isTrue);

    final manifest = SyncManifest.fromBytes(
      await provider.downloadFile(
        '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
      ),
    );
    expect(manifest.baseSeq, isNotNull);
    expect(manifest.headSeq, manifest.baseSeq);
    expect(manifest.publishedHlcHigh, isNotNull);
    expect(manifest.basePartChecksums, isNotEmpty);
  });

  test('publish with no data is a no-op', () async {
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.noop);
    expect(await names(), isEmpty);
  });

  test(
    'cold-starts a fresh base (no crash) when local state has a base but the '
    'cloud manifest is missing',
    () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
      );
      await publish(); // base @1, manifest + local publish state

      // The cloud manifest becomes un-listable (eventual-consistency lag, or
      // wiped by another device) while local publish state still says a base
      // exists. Regression: the changeset branch did `ownManifest!` and threw
      // "Null check operator used on a null value" on the next publish.
      final deviceId = await SyncRepository().getDeviceId();
      await provider.deleteFile(
        '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
      );

      // Delete a dive and publish -- must recover, not throw.
      await DiveRepository().deleteDive('d1');
      final result = await publish();

      expect(
        result.kind,
        ChangesetWriteKind.base,
        reason: 'a missing cloud manifest must cold-start a fresh base',
      );
      final manifest = SyncManifest.fromBytes(
        await provider.downloadFile(
          '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
        ),
      );
      expect(
        manifest.baseSeq,
        greaterThan(1),
        reason: 'the fresh base uses a non-reused seq recovered from state',
      );
    },
  );

  test('second publish writes a changeset with only the new dive', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.changeset);

    final deviceId = await SyncRepository().getDeviceId();
    final files = await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    final csFiles = files
        .where((f) => ChangesetLogLayout.changesetSeqOf(f.name) != null)
        .toList();
    expect(csFiles, isNotEmpty);

    final payload = ChangesetCodec(
      SyncDataSerializer(),
    ).decodeChangeset(await provider.downloadFile(csFiles.first.id));
    final diveIds = payload.data.dives.map((d) => d['id']).toSet();
    expect(diveIds.contains('d2'), isTrue);
    expect(diveIds.contains('d1'), isFalse);

    final manifest = SyncManifest.fromBytes(
      await provider.downloadFile(
        '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
      ),
    );
    expect(manifest.headSeq, greaterThan(manifest.baseSeq!));
  });

  test('publish after base with no new changes is a no-op', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish();
    final before = (await names()).length;

    final result = await publish();
    expect(result.kind, ChangesetWriteKind.noop);
    expect(
      (await names()).length,
      before,
      reason: 'a no-op writes no new file',
    );
  });

  test(
    'lost local publish state recovers headSeq from the cloud manifest',
    () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await publish(); // base @ seq 1
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
      );
      await publish(); // changeset @ seq 2

      await PublishStateStore(
        DatabaseService.instance.database,
      ).resetForProvider(provider.providerId);

      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd3', diveNumber: 3),
      );
      final result = await publish();
      expect(result.kind, ChangesetWriteKind.changeset);
      expect(
        result.seq,
        3,
        reason: 'seq must continue from the cloud manifest, not reset to 1',
      );
    },
  );

  test(
    'a deletion publishes once as a changeset, then the next sync no-ops',
    () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await publish(); // base @1; publishedHlcHigh = d1's hlc

      await DiveRepository().deleteDive(
        'd1',
      ); // tombstone stamped with a fresh hlc
      final r1 = await publish();
      expect(
        r1.kind,
        ChangesetWriteKind.changeset,
        reason: 'a new tombstone (hlc > watermark) publishes once',
      );

      final before = (await names()).length;
      final r2 = await publish();
      expect(
        r2.kind,
        ChangesetWriteKind.noop,
        reason:
            'the tombstone is now <= the published watermark, so it must NOT '
            're-publish a fresh changeset on every subsequent sync (B1)',
      );
      expect(
        (await names()).length,
        before,
        reason: 'a no-op writes no new file',
      );
    },
  );

  test(
    'first base publish streams parts that reassemble to the library',
    () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
      );
      final result = await publish();
      expect(result.kind, ChangesetWriteKind.base);

      final deviceId = await SyncRepository().getDeviceId();
      final manifest = SyncManifest.fromBytes(
        await provider.downloadFile(
          '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
        ),
      );

      // Reassemble the streamed parts and verify checksum + parsed content.
      final parts = <int, List<int>>{};
      for (final f in await provider.listFiles(
        folderId: folder,
        namePattern: ChangesetLogLayout.prefix,
      )) {
        final bp = ChangesetLogLayout.basePartOf(f.name);
        if (bp != null && bp.baseSeq == manifest.baseSeq) {
          parts[bp.part] = await provider.downloadFile(f.id);
        }
      }
      final ordered = [
        for (final i in parts.keys.toList()..sort()) ...parts[i]!,
      ];
      expect(parts.length, manifest.basePartCount);
      expect(ordered.length, manifest.baseBytes);
      expect('sha256:${sha256.convert(ordered)}', manifest.baseChecksum);

      final payload = jsonDecode(utf8.decode(ordered)) as Map<String, dynamic>;
      final diveIds = ((payload['data'] as Map)['dives'] as List)
          .map((d) => (d as Map)['id'])
          .toSet();
      expect(diveIds, {'d1', 'd2'});
    },
  );

  group('post-adopt deferred base (changeset without a base)', () {
    /// Put the device in the adopted state: the library content exists
    /// locally (the adopted epoch, already published by the peers) and the
    /// publish state carries the null-baseSeq marker with the adopted
    /// watermark. Anything written AFTER this is a post-adopt local change.
    Future<void> adoptWithLibrary() async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'adopted-dive', diveNumber: 1),
      );
      await PublishStateStore(
        DatabaseService.instance.database,
      ).markAdoptedPendingBase(
        provider.providerId,
        await SyncRepository().maxRowHlc(),
      );
    }

    Future<SyncManifest> readOwnManifest() async {
      final deviceId = await SyncRepository().getDeviceId();
      return SyncManifest.fromBytes(
        await provider.downloadFile(
          '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
        ),
      );
    }

    test('the first publish after adopt writes a changeset, NOT a full base '
        '(the adopted library is already in the cloud)', () async {
      await adoptWithLibrary();
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'my-edit', diveNumber: 2),
      );

      final result = await publish();

      expect(result.kind, ChangesetWriteKind.changeset);
      expect(result.seq, 1);
      final ns = await names();
      expect(
        ns.any((n) => ChangesetLogLayout.basePartOf(n) != null),
        isFalse,
        reason:
            'no base part may be uploaded -- that is the redundant '
            'full-library re-upload this path exists to avoid',
      );

      final manifest = await readOwnManifest();
      expect(manifest.baseSeq, isNull);
      expect(manifest.headSeq, 1);

      final deviceId = await SyncRepository().getDeviceId();
      final payload = ChangesetCodec(SyncDataSerializer()).decodeChangeset(
        await provider.downloadFile(
          '$folder/${ChangesetLogLayout.changesetName(deviceId, 1)}',
        ),
      );
      final diveIds = payload.data.dives.map((d) => d['id']).toSet();
      expect(diveIds.contains('my-edit'), isTrue);
      expect(
        diveIds.contains('adopted-dive'),
        isFalse,
        reason:
            'rows at or below the adopted watermark are already published '
            'by the peers',
      );
    });

    test(
      'a second post-adopt publish appends the next changeset seq',
      () async {
        await adoptWithLibrary();
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'edit-1', diveNumber: 2),
        );
        await publish();
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'edit-2', diveNumber: 3),
        );

        final result = await publish();

        expect(result.kind, ChangesetWriteKind.changeset);
        expect(result.seq, 2);
        final manifest = await readOwnManifest();
        expect(manifest.baseSeq, isNull);
        expect(manifest.headSeq, 2);
      },
    );

    test('a post-adopt publish with nothing new is a no-op', () async {
      await adoptWithLibrary();

      final result = await publish();

      expect(result.kind, ChangesetWriteKind.noop);
      expect(await names(), isEmpty);
    });

    test(
      'a post-adopt deletion publishes its tombstone as a changeset',
      () async {
        await adoptWithLibrary();
        await DiveRepository().deleteDive('adopted-dive');

        final result = await publish();

        expect(result.kind, ChangesetWriteKind.changeset);
        final deviceId = await SyncRepository().getDeviceId();
        final payload = ChangesetCodec(SyncDataSerializer()).decodeChangeset(
          await provider.downloadFile(
            '$folder/${ChangesetLogLayout.changesetName(deviceId, 1)}',
          ),
        );
        expect(payload.deletions['dives'], isNotEmpty);
      },
    );

    test('a null adopted watermark falls back to a streamed base publish '
        '(never exportChangeset(null), the in-memory OOM path)', () async {
      // maxRowHlc() can legitimately be null at adopt: an empty adopted
      // library, or one whose rows all predate HLC stamping. A null
      // watermark in the changeset path would export the ENTIRE library
      // in memory -- the exact full-upload/OOM this mode exists to avoid.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'legacy-dive', diveNumber: 1),
      );
      await PublishStateStore(
        DatabaseService.instance.database,
      ).markAdoptedPendingBase(provider.providerId, null);
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'my-edit', diveNumber: 2),
      );

      final result = await publish();

      expect(
        result.kind,
        ChangesetWriteKind.base,
        reason:
            'with no watermark to delta against, the only safe publish '
            'is the streamed full base',
      );
    });

    test(
      'a base-less log folds into a real base when compaction trips',
      () async {
        final compactingWriter = ChangesetWriter(
          SyncDataSerializer(),
          ChangesetCodec(SyncDataSerializer()),
          PublishStateStore(DatabaseService.instance.database),
          compactionByteRatio: 1000.0,
          compactionMaxChangesets: 2,
        );
        await adoptWithLibrary();
        final deviceId = await SyncRepository().getDeviceId();

        Future<ChangesetWriteResult> publishCompacting() async =>
            compactingWriter.publish(
              provider: provider,
              deviceId: deviceId,
              folderId: folder,
              deletions: await SyncRepository().getAllDeletions(),
            );

        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'edit-1', diveNumber: 2),
        );
        final first = await publishCompacting();
        expect(first.kind, ChangesetWriteKind.changeset);

        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'edit-2', diveNumber: 3),
        );
        final second = await publishCompacting();

        expect(
          second.kind,
          ChangesetWriteKind.compacted,
          reason:
              'a log with no base must eventually fold into a real base so '
              'the device is a durable source for future cold-starts',
        );
        final manifest = await readOwnManifest();
        expect(manifest.baseSeq, isNotNull);
        expect(manifest.headSeq, manifest.baseSeq);
      },
    );
  });
}
