import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_source.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/resumable_base_publish.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

/// Issue #1032: a wiped backend forces the whole library out as one base -- 80
/// parts and ~640 MB for the reporter. Every interrupted attempt restarted from
/// part 0, so on a phone it could never finish. These tests pin that a second
/// attempt continues the first.
void main() {
  late Directory publishDir;
  late ResumableBasePublishStore store;

  setUp(() async {
    await setUpTestDatabase();
    publishDir = await Directory.systemTemp.createTemp('base_publish');
    store = ResumableBasePublishStore(directory: () async => publishDir);
  });

  tearDown(() async {
    await tearDownTestDatabase();
    if (await publishDir.exists()) await publishDir.delete(recursive: true);
  });

  ResumableBasePublish record({
    required String dataPath,
    required int byteLength,
    String providerId = 'fake',
    String deviceId = 'dev1',
    int seq = 1,
    String? epochId,
    int createdAt = 100,
  }) => ResumableBasePublish(
    providerId: providerId,
    deviceId: deviceId,
    seq: seq,
    dataPath: dataPath,
    byteLength: byteLength,
    createdAt: createdAt,
    epochId: epochId,
  );

  Future<String> writeExport(String name, int bytes) async {
    final path = '${publishDir.path}/$name';
    await File(path).writeAsBytes(List.filled(bytes, 0x41));
    return path;
  }

  group('ResumableBasePublishStore', () {
    test('finds a record whose export is intact', () async {
      final path = await writeExport('a.json', 50);
      await store.save(record(dataPath: path, byteLength: 50, epochId: 'e1'));

      final found = await store.find(
        providerId: 'fake',
        deviceId: 'dev1',
        epochId: 'e1',
      );

      expect(found, isNotNull);
      expect(found!.seq, 1);
      expect(found.dataPath, path);
    });

    test('discards a record whose export the OS purged', () async {
      final path = await writeExport('gone.json', 50);
      await store.save(record(dataPath: path, byteLength: 50, epochId: 'e1'));
      await File(path).delete();

      final found = await store.find(
        providerId: 'fake',
        deviceId: 'dev1',
        epochId: 'e1',
      );

      expect(found, isNull);
      expect(
        await File(ResumableBasePublish.sidecarPathFor(path)).exists(),
        isFalse,
        reason: 'a record with no export is dead weight and is cleaned up',
      );
    });

    test('discards a truncated export rather than resuming it', () async {
      final path = await writeExport('short.json', 20);
      await store.save(record(dataPath: path, byteLength: 50, epochId: 'e1'));

      expect(
        await store.find(providerId: 'fake', deviceId: 'dev1', epochId: 'e1'),
        isNull,
      );
      expect(await File(path).exists(), isFalse);
    });

    test('discards an export stamped with a superseded epoch', () async {
      final path = await writeExport('old.json', 50);
      await store.save(record(dataPath: path, byteLength: 50, epochId: 'old'));

      expect(
        await store.find(providerId: 'fake', deviceId: 'dev1', epochId: 'new'),
        isNull,
        reason: 'those bytes would publish a base every peer ignores',
      );
      expect(await File(path).exists(), isFalse);
    });

    test('ignores records belonging to another backend', () async {
      final path = await writeExport('other.json', 50);
      await store.save(
        record(dataPath: path, byteLength: 50, providerId: 's3'),
      );

      expect(await store.find(providerId: 'dropbox', deviceId: 'dev1'), isNull);
      expect(
        await File(path).exists(),
        isTrue,
        reason: 'another backend’s in-flight publish is not ours to delete',
      );
    });

    test('keeps only the newest of several attempts', () async {
      final oldPath = await writeExport('old.json', 50);
      final newPath = await writeExport('new.json', 50);
      await store.save(
        record(dataPath: oldPath, byteLength: 50, seq: 1, createdAt: 1),
      );
      await store.save(
        record(dataPath: newPath, byteLength: 50, seq: 2, createdAt: 2),
      );

      final found = await store.find(providerId: 'fake', deviceId: 'dev1');

      expect(found!.seq, 2);
      expect(await File(oldPath).exists(), isFalse);
    });

    test('a corrupt sidecar takes its export with it', () async {
      // The export can be hundreds of megabytes in a directory nothing else
      // purges, so an unreadable RECORD must not strand its BYTES there. The
      // data path is derivable from the sidecar's name (PR #1033 review).
      final path = await writeExport('corrupt.json', 50);
      await File(
        ResumableBasePublish.sidecarPathFor(path),
      ).writeAsString('{not json');

      final found = await store.find(providerId: 'fake', deviceId: 'dev1');

      expect(found, isNull);
      expect(await File(path).exists(), isFalse);
      expect(
        await File(ResumableBasePublish.sidecarPathFor(path)).exists(),
        isFalse,
      );
      expect(publishDir.listSync(), isEmpty);
    });

    test('clearForProvider also reclaims a corrupt sidecar’s export', () async {
      final path = await writeExport('corrupt.json', 50);
      await File(
        ResumableBasePublish.sidecarPathFor(path),
      ).writeAsString('{not json');

      await store.clearForProvider('fake');

      expect(await File(path).exists(), isFalse);
      expect(publishDir.listSync(), isEmpty);
    });

    test('dataPathForSidecar is the inverse of sidecarPathFor', () async {
      const data = '/tmp/ssv1_base_dev_1.abc.json';
      expect(
        ResumableBasePublish.dataPathForSidecar(
          ResumableBasePublish.sidecarPathFor(data),
        ),
        data,
      );
    });

    test('reclaims an export whose sidecar was never written', () async {
      // _recordResumable moves the export into place and only then writes the
      // sidecar. An app killed inside that window leaves a data file nothing
      // references, and find() scans sidecars, so it would never be seen again
      // -- a whole library stranded in a directory nothing purges (#1033).
      final orphan = await writeExport('orphan.json', 50);
      await File(
        orphan,
      ).setLastModified(DateTime.now().subtract(const Duration(hours: 1)));

      await store.find(providerId: 'fake', deviceId: 'dev1');

      expect(await File(orphan).exists(), isFalse);
    });

    test('spares an export young enough to still be mid-write', () async {
      // The only writer here is _recordResumable, and publishes are
      // serialized, but a file written moments ago is likelier to be one in
      // flight than an orphan. A true orphan is reclaimed by the next sync.
      final fresh = await writeExport('fresh.json', 50);

      await store.find(providerId: 'fake', deviceId: 'dev1');

      expect(await File(fresh).exists(), isTrue);
    });

    test('never sweeps an export a sidecar still points at', () async {
      final path = await writeExport('kept.json', 50);
      await File(
        path,
      ).setLastModified(DateTime.now().subtract(const Duration(hours: 1)));
      // A record for a DIFFERENT backend: skipped by this find, but its export
      // is still referenced and must survive.
      await store.save(
        record(dataPath: path, byteLength: 50, providerId: 's3'),
      );

      await store.find(providerId: 'fake', deviceId: 'dev1');

      expect(await File(path).exists(), isTrue);
    });

    test('clearForProvider drops only that backend’s records', () async {
      final mine = await writeExport('mine.json', 50);
      final theirs = await writeExport('theirs.json', 50);
      await store.save(
        record(dataPath: mine, byteLength: 50, providerId: 'fake'),
      );
      await store.save(
        record(dataPath: theirs, byteLength: 50, providerId: 's3'),
      );

      await store.clearForProvider('fake');

      expect(await File(mine).exists(), isFalse);
      expect(await File(theirs).exists(), isTrue);
    });
  });

  /// Issue #1304: every base publish on Windows died with
  /// `PathNotFoundException` because the export's basename was taken by
  /// splitting on `Platform.pathSeparator`. Export paths are assembled by
  /// interpolation, so on Windows they mix separators and the backslash split
  /// left a leading `Temp/` on the name -- moving the export into a
  /// subdirectory of the publish dir that nothing ever creates.
  ///
  /// The host running these tests is POSIX, so the Windows style is pinned
  /// explicitly rather than inherited from the platform.
  group('basePublishTargetPath', () {
    final windows = p.Context(style: p.Style.windows);
    const name =
        'ssv1_base_11d9442e-c184-4e1f-8fd1-8f6dc8ff8f05_1.'
        '7dd38a42-104f-495a-937d-48ced42d37bd.json';

    const publishDirPath =
        'C:\\Users\\chaeh\\AppData\\Roaming\\Eric Griffin\\submersion'
        '\\sync_base_publish';

    test('lands a mixed-separator Windows export in the publish dir', () {
      // Exactly the shapes from the #1304 report: the temp dir carries
      // backslashes, the filename was appended with a literal '/'.
      final target = basePublishTargetPath(
        publishDirPath,
        'C:\\Users\\chaeh\\AppData\\Local\\Temp/$name',
        context: windows,
      );

      expect(windows.basename(target), name);
      expect(
        windows.dirname(target),
        publishDirPath,
        reason: 'a "Temp" segment here is a directory that never gets created',
      );
    });

    test('lands a pure-backslash Windows export in the publish dir', () {
      final target = basePublishTargetPath(
        publishDirPath,
        'C:\\Users\\chaeh\\AppData\\Local\\Temp\\$name',
        context: windows,
      );

      expect(target, '$publishDirPath\\$name');
    });

    test('leaves POSIX paths flat in the publish dir', () {
      final target = basePublishTargetPath(
        '/var/support/sync_base_publish',
        '/var/folders/t7/T/$name',
        context: p.Context(style: p.Style.posix),
      );

      expect(target, '/var/support/sync_base_publish/$name');
    });
  });

  /// Part skipping lives here rather than at the writer, where the 8 MiB part
  /// size would need a multi-megabyte fixture to produce a second part.
  group('BasePartFileSource.skipPart', () {
    test('skips the network for parts already uploaded, hashing all', () async {
      final dir = await Directory.systemTemp.createTemp('skip');
      final path = '${dir.path}/base.json';
      final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      await File(path).writeAsBytes(data);

      final sent = <int>[];
      final res = await BasePartFileSource(path, partSize: 256).uploadAll(
        (i, bytes) async => sent.add(i),
        skipPart: (i) => i < 2, // parts 0 and 1 landed on the first attempt
      );

      expect(sent, [2, 3], reason: 'only the missing parts go over the wire');
      expect(
        res.wholeChecksum,
        BaseChunker.checksum(data),
        reason:
            'checksums still describe the whole file, so a manifest '
            'written on a resumed pass is indistinguishable from a fresh one',
      );
      expect(res.partCount, 4);
      await dir.delete(recursive: true);
    });

    test('a file truncated between attempts fails verification', () async {
      // The reason skipped parts are re-hashed instead of trusting recorded
      // checksums: stale checksums would certify bytes that are no longer there.
      final dir = await Directory.systemTemp.createTemp('trunc');
      final path = '${dir.path}/base.json';
      final full = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      await File(path).writeAsBytes(full.sublist(0, 600));

      final res = await BasePartFileSource(
        path,
        partSize: 256,
      ).uploadAll((i, bytes) async {}, skipPart: (i) => true);

      expect(res.wholeChecksum, isNot(BaseChunker.checksum(full)));
      await dir.delete(recursive: true);
    });
  });

  group('ChangesetWriter resume', () {
    late FakeCloudStorageProvider provider;
    late ChangesetWriter writer;
    late String folder;

    setUp(() async {
      final db = DatabaseService.instance.database;
      final serializer = SyncDataSerializer();
      writer = ChangesetWriter(
        serializer,
        ChangesetCodec(serializer),
        PublishStateStore(db),
        compactionByteRatio: 1000.0,
        compactionMaxChangesets: 1 << 30,
        resumableStore: store,
      );
      provider = FakeCloudStorageProvider();
      folder = await provider.getOrCreateSyncFolder();
    });

    Future<ChangesetWriteResult> publish() async {
      final repo = SyncRepository();
      return writer.publish(
        provider: provider,
        deviceId: await repo.getDeviceId(),
        folderId: folder,
        deletions: await repo.getAllDeletions(),
      );
    }

    Future<List<CloudFileInfo>> listing() => provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );

    Future<Uint8List?> download(String name) async {
      final match = (await listing()).where((f) => f.name == name).firstOrNull;
      return match == null ? null : provider.downloadFile(match.id);
    }

    test('an interrupted base publish leaves an export to resume', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      provider.failUploadsAfter = 0; // die on the very first part

      await expectLater(publish(), throwsA(anything));

      final deviceId = await SyncRepository().getDeviceId();
      final pending = await store.find(
        providerId: provider.providerId,
        deviceId: deviceId,
      );
      expect(
        pending,
        isNotNull,
        reason:
            'without this the next attempt re-exports and re-uploads all of '
            'it, which is why the reported sync never converged',
      );
      expect(await File(pending!.dataPath).exists(), isTrue);
      expect(
        await download(ChangesetLogLayout.manifestName(deviceId)),
        isNull,
        reason: 'the manifest is the commit point and must not be written',
      );
    });

    test('the next attempt reuses the export and keeps its seq', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      provider.failUploadsAfter = 0;
      await expectLater(publish(), throwsA(anything));

      final deviceId = await SyncRepository().getDeviceId();
      final pending = (await store.find(
        providerId: provider.providerId,
        deviceId: deviceId,
      ))!;

      provider.failUploadsAfter = null;
      final result = await publish();

      expect(result.kind, ChangesetWriteKind.base);
      expect(
        result.seq,
        pending.seq,
        reason:
            'parts already uploaded are named with this seq; changing it '
            'would orphan every one of them',
      );
      expect(
        await File(pending.dataPath).exists(),
        isFalse,
        reason: 'a committed publish spends its export',
      );
      expect(
        await store.find(providerId: provider.providerId, deviceId: deviceId),
        isNull,
      );
    });

    test(
      'the resumed manifest describes the bytes actually uploaded',
      () async {
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
        );
        final deviceId = await SyncRepository().getDeviceId();

        provider.failUploadsAfter = 0;
        await expectLater(publish(), throwsA(anything));
        provider.failUploadsAfter = null;
        await publish();

        final manifest = SyncManifest.fromBytes(
          (await download(ChangesetLogLayout.manifestName(deviceId)))!,
        );
        final assembled = <int>[];
        for (var i = 0; i < manifest.basePartCount!; i++) {
          assembled.addAll(
            (await download(
              ChangesetLogLayout.basePartName(deviceId, manifest.baseSeq!, i),
            ))!,
          );
        }

        expect(assembled.length, manifest.baseBytes);
        expect(
          BaseChunker.checksum(Uint8List.fromList(assembled)),
          manifest.baseChecksum,
        );
      },
    );

    test('an uninterrupted publish leaves no export behind', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );

      await publish();

      expect(
        await store.find(
          providerId: provider.providerId,
          deviceId: await SyncRepository().getDeviceId(),
        ),
        isNull,
        reason: 'nothing reclaims this directory, so it must not accumulate',
      );
      expect(publishDir.listSync(), isEmpty);
    });
  });
}
