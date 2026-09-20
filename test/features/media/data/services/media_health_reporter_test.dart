import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/services/media_health_reporter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;
  final bytes = List<int>.generate(1024, (i) => (i * 11) % 251);

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  MediaHealthReporter reporterFor(HarnessDevice d) => MediaHealthReporter(
    mediaRepository: MediaRepository(),
    syncRepository: SyncRepository(),
    assetCache: d.assetCache,
    queue: d.queue,
    registry: d.registry,
    attachState: MediaStoreAttachState(),
    store: () async => h.bucket,
    localDeviceId: () async => d.deviceId,
    localDeviceName: () async => d.name,
    deviceName: (id) => id == h.a.deviceId
        ? 'Device A'
        : (id == h.b.deviceId ? 'Device B' : null),
  );

  test('a foreign uploaded row on B is fully described', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkFile(bytes, diveId: dive);
    await h.a.enqueueUpload(id);
    await h.a.drain();
    await h.a.sync();
    await h.b.sync();
    await h.b.sync(); // publish clears B's own marks

    await h.b.activate();
    final onB = (await h.b.media(id))!;
    final report = await h.b.onThisDisk(
      () => reporterFor(h.b).forItem(onB, probeStore: true),
    );
    final row = report.rows.single;

    expect(row.linkedHere, isFalse);
    expect(row.originDeviceId, h.a.deviceId);
    expect(row.originDeviceName, 'Device A');
    expect(row.resolverVerdict, 'fromOtherDevice');
    expect(row.contentHash, isNotNull);
    expect(row.hlc, isNotNull);
    expect(row.filePath, onB.filePath);
    expect(row.storeObjectExists, isTrue);
    expect(row.storeObjectTier, 'original');
    expect(row.pending, isFalse);
    expect(row.queueState, isNull);
    expect(report.attachedStoreId, h.storeId);
    expect(report.markerStoreId, h.storeId);
    expect(report.deviceId, h.b.deviceId);
    expect(report.deviceName, 'Device B');

    final library = await h.b.onThisDisk(() => reporterFor(h.b).forLibrary());
    expect(library.rows, hasLength(1));
    expect(
      library.rows.single.storeObjectExists,
      isNull,
      reason: 'the library report does not probe the store',
    );
  });

  test('each source type reports the locator it actually uses', () async {
    // The row carries only three path columns, so deriving the pointer from
    // them printed null for every type that keeps its locator elsewhere: a
    // network row's URL, a connector row's remote asset id, a store row's
    // content hash. The reporter now takes the pointer from the one
    // exhaustive selection, OriginFacts.
    await h.a.activate();
    MediaItem item(
      MediaSourceType type, {
      String? url,
      String? remoteAssetId,
      String? contentHash,
      String? bookmarkRef,
      String? platformAssetId,
    }) => MediaItem(
      id: 'probe-${type.name}',
      mediaType: MediaType.photo,
      sourceType: type,
      url: url,
      remoteAssetId: remoteAssetId,
      contentHash: contentHash,
      bookmarkRef: bookmarkRef,
      platformAssetId: platformAssetId,
      takenAt: DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

    final expected = <MediaItem, String?>{
      item(MediaSourceType.networkUrl, url: 'https://example.com/a.jpg'):
          'https://example.com/a.jpg',
      item(MediaSourceType.manifestEntry, url: 'https://example.com/b.jpg'):
          'https://example.com/b.jpg',
      item(MediaSourceType.serviceConnector, remoteAssetId: 'asset-7'):
          'asset-7',
      item(MediaSourceType.mediaStore, contentHash: 'h' * 64): 'h' * 64,
      item(MediaSourceType.localFile, bookmarkRef: 'bm://scoped'):
          'bm://scoped',
      item(MediaSourceType.platformGallery, platformAssetId: 'PH-1'): 'PH-1',
      item(MediaSourceType.signature): null,
    };

    for (final entry in expected.entries) {
      final row = (await h.a.onThisDisk(
        () => reporterFor(h.a).forItem(entry.key),
      )).rows.single;
      expect(row.pointer, entry.value, reason: entry.key.sourceType.name);
      expect(
        row.toJson()['pointer'],
        entry.value,
        reason: '${entry.key.sourceType.name} in JSON',
      );
    }
  });

  test('the origin device names itself and sees its queue entry', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkFile(bytes, diveId: dive);
    await h.a.enqueueUpload(id);
    await h.a.drain();

    await h.a.activate();
    final onA = (await h.a.media(id))!;
    final row = (await h.a.onThisDisk(
      () => reporterFor(h.a).forItem(onA),
    )).rows.single;

    expect(row.linkedHere, isTrue);
    expect(row.originDeviceName, 'Device A');
    expect(row.resolverVerdict, 'available');
    expect(row.queueState, 'done');
    expect(row.pending, isTrue, reason: 'the upload stamps are unpublished');
  });

  test('a row with no origin reads as unknown, not local', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkFile(bytes, diveId: dive);
    await h.a.activate();
    await h.a.db.customStatement(
      'UPDATE media SET origin_device_id = NULL WHERE id = ?',
      [id],
    );
    final onA = (await h.a.media(id))!;
    final row = (await h.a.onThisDisk(
      () => reporterFor(h.a).forItem(onA),
    )).rows.single;

    expect(row.linkedHere, isNull);
    expect(row.toText(), contains('origin_device: unknown'));
  });

  test('a cloud-backed row never reaches the store resolver', () async {
    // Its registry resolver reads mediaStoreResolverProvider, which watches
    // the runtime, and building that starts a drain and a verify sweep. The
    // store probe is the verdict for these rows instead.
    final dive = await h.a.createDive();
    final id = await h.a.linkFile(bytes, diveId: dive);
    await h.a.activate();
    await h.a.db.customStatement(
      "UPDATE media SET source_type = 'mediaStore' WHERE id = ?",
      [id],
    );
    final row = (await h.a.media(id))!;

    final report = await h.a.onThisDisk(() => reporterFor(h.a).forItem(row));

    expect(report.rows.single.resolverVerdict, 'mediaStore');
  });

  test('a video rendition is probed under the compressed extension', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkFile(bytes, diveId: dive, name: 'reef.mov');
    await h.a.activate();
    // Compressed-only, as an upload-quality override leaves a row.
    const hash =
        'abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234';
    await h.a.db.customStatement(
      "UPDATE media SET content_hash = '$hash', "
      'remote_compressed_uploaded_at = 1 WHERE id = ?',
      [id],
    );
    // The pipeline writes a video rendition as mp4, never as .mov.
    h.bucket.objects[StoreKeys.renditionKey(hash, ext: 'mp4')] = [1, 2, 3];
    final row = (await h.a.media(id))!;

    final report = await h.a.onThisDisk(
      () => reporterFor(h.a).forItem(row, probeStore: true),
    );

    expect(report.rows.single.storeObjectExists, isTrue);
    expect(report.rows.single.storeObjectTier, 'rendition');
  });

  test('an unresolved cache entry reports its next retry by attempt', () async {
    final dive = await h.b.createDive();
    final id = await h.b.linkFile(bytes, diveId: dive);
    await h.b.activate();
    await h.b.assetCache.cacheResolution(
      mediaId: id,
      localAssetId: null,
      method: 'unresolved',
    );
    await h.b.assetCache.incrementAttempt(id);
    final entry = (await h.b.assetCache.getCacheEntry(id))!;
    final resolvedAt = DateTime.fromMillisecondsSinceEpoch(entry.resolvedAt);
    var onB = (await h.b.media(id))!;
    var row = (await reporterFor(h.b).forItem(onB)).rows.single;
    expect(row.cacheAttempts, 1);
    expect(row.cacheNextRetryAt, resolvedAt.add(const Duration(days: 3)));

    // incrementAttempt re-stamps resolvedAt, so read it back again.
    await h.b.assetCache.incrementAttempt(id);
    final again = (await h.b.assetCache.getCacheEntry(id))!;
    final resolvedAgain = DateTime.fromMillisecondsSinceEpoch(again.resolvedAt);
    onB = (await h.b.media(id))!;
    row = (await reporterFor(h.b).forItem(onB)).rows.single;
    expect(row.cacheAttempts, 2);
    expect(row.cacheNextRetryAt, resolvedAgain.add(const Duration(days: 7)));
  });
}
