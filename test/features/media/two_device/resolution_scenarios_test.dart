import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

import '../../../helpers/fake_photo_picker_service.dart';
import '../../../helpers/two_device_media_harness.dart';

void main() {
  late TwoDeviceMediaHarness h;
  final taken = DateTime(2026, 7, 1, 10, 30);
  final photo = Uint8List.fromList(List<int>.generate(512, (i) => i % 251));

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test('S5: a gallery photo B does not have reads as from another device and '
      'never orphans the row', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(id: 'A-1', bytes: photo, takenAt: taken),
      diveId: dive,
    );
    await h.a.sync();
    await h.b.sync();

    final tile = await h.b.tile(id);
    expect(
      (tile.data as UnavailableData).kind,
      UnavailableKind.fromOtherDevice,
      reason: 'B never had this photo; it is not evidence it was deleted',
    );

    await h.b.checkTile(id);
    expect((await h.b.media(id))!.isOrphaned, isFalse);
    await h.b.sync();
    await h.a.sync();
    expect(
      (await h.a.media(id))!.isOrphaned,
      isFalse,
      reason: 'a peer must never plant the orphan flag',
    );
  });

  test('an old gallery row learns its origin after a sync, and peers with '
      'it', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(id: 'A-1', bytes: photo, takenAt: taken),
      diveId: dive,
    );
    // Linked before gallery rows recorded an origin.
    await h.a.clearOrigin(id);
    await h.a.sync();
    await h.b.sync();
    expect((await h.b.media(id))!.originDeviceId, isNull);

    await h.a.backfillGalleryOrigins();
    await h.a.sync();
    await h.b.sync();

    expect(
      (await h.b.media(id))!.originDeviceId,
      h.a.deviceId,
      reason: 'the linking device stamped it and the stamp synced',
    );
    final tile = await h.b.tile(id);
    expect(
      (tile.data as UnavailableData).kind,
      UnavailableKind.fromOtherDevice,
    );
  });

  test('S6: a burst pair shot in the same second resolves to the right frame '
      'on a peer sharing the photo library', () async {
    final frame1 = Uint8List.fromList(List<int>.generate(512, (i) => i % 251));
    final frame2 = Uint8List.fromList(
      List<int>.generate(512, (i) => (i * 7) % 251),
    );
    final dive = await h.a.createDive();
    final id1 = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(
        id: 'A-b1',
        bytes: frame1,
        takenAt: taken,
        cloudId: 'C-b1',
      ),
      diveId: dive,
    );
    final id2 = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(
        id: 'A-b2',
        bytes: frame2,
        takenAt: taken,
        cloudId: 'C-b2',
      ),
      diveId: dive,
    );
    // Same iCloud library on B: same photos, different local ids, and no
    // titles in the listing, so filename cannot break the tie.
    h.b.gallery.add(
      FakeGalleryAsset(
        id: 'B-b1',
        bytes: frame1,
        takenAt: taken,
        filename: null,
        cloudId: 'C-b1',
      ),
    );
    h.b.gallery.add(
      FakeGalleryAsset(
        id: 'B-b2',
        bytes: frame2,
        takenAt: taken,
        filename: null,
        cloudId: 'C-b2',
      ),
    );
    await h.a.sync();
    await h.b.sync();

    final t1 = await h.b.tile(id1);
    final t2 = await h.b.tile(id2);
    expect(
      t1.data,
      isA<BytesData>(),
      reason: 'a shared cloud identifier tells the frames apart',
    );
    expect((t1.data as BytesData).bytes, frame1);
    expect((t2.data as BytesData).bytes, frame2);
    expect(
      await h.b.assetCache.getCacheEntry(id1),
      isA<CacheEntry>().having((e) => e.resolutionMethod, 'method', 'cloud_id'),
    );
  });

  test('a peer that gave up on a photo retries as soon as its cloud id '
      'arrives', () async {
    final frame1 = Uint8List.fromList(List<int>.generate(512, (i) => i % 251));
    final frame2 = Uint8List.fromList(
      List<int>.generate(512, (i) => (i * 7) % 251),
    );
    final dive = await h.a.createDive();
    final id1 = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(
        id: 'A-b1',
        bytes: frame1,
        takenAt: taken,
        cloudId: 'C-b1',
      ),
      diveId: dive,
    );
    await h.a.linkGalleryPhoto(
      FakeGalleryAsset(
        id: 'A-b2',
        bytes: frame2,
        takenAt: taken,
        cloudId: 'C-b2',
      ),
      diveId: dive,
    );
    h.b.gallery
      ..add(
        FakeGalleryAsset(
          id: 'B-b1',
          bytes: frame1,
          takenAt: taken,
          filename: null,
          cloudId: 'C-b1',
        ),
      )
      ..add(
        FakeGalleryAsset(
          id: 'B-b2',
          bytes: frame2,
          takenAt: taken,
          filename: null,
          cloudId: 'C-b2',
        ),
      );
    // The row reaches B without its cloud id; B cannot tell the frames apart
    // and backs off.
    await h.a.clearCloudAssetId(id1);
    await h.a.sync();
    await h.b.sync();
    expect((await h.b.tile(id1)).data, isA<UnavailableData>());
    expect(
      (await h.b.assetCache.getCacheEntry(id1))!.resolutionMethod,
      'unresolved',
    );

    // A's one-time backfill stamps it, and the stamp moves the row clock,
    // so the peer takes the row.
    await h.a.backfillGalleryCloudIds();
    await h.a.sync();
    await h.b.sync();

    expect(
      await h.b.assetCache.getCacheEntry(id1),
      isNull,
      reason: 'the new cloud id lifted the backoff',
    );
    final tile = await h.b.tile(id1);
    expect((tile.data as BytesData).bytes, frame1);
  });

  // A relink points the row at another photo. A mapping the peer found for
  // the old one, even a cloud id match, now names the wrong photo.
  test('a peer that found a photo follows a relink to another', () async {
    final photo2 = Uint8List.fromList(
      List<int>.generate(512, (i) => (i * 3) % 251),
    );
    final dive = await h.a.createDive();
    final id = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(id: 'A-1', bytes: photo, takenAt: taken, cloudId: 'C-1'),
      diveId: dive,
    );
    h.b.gallery
      ..add(
        FakeGalleryAsset(
          id: 'B-1',
          bytes: photo,
          takenAt: taken,
          filename: null,
          cloudId: 'C-1',
        ),
      )
      ..add(
        FakeGalleryAsset(
          id: 'B-2',
          bytes: photo2,
          takenAt: taken,
          filename: null,
          cloudId: 'C-2',
        ),
      );
    await h.a.sync();
    await h.b.sync();
    expect(((await h.b.tile(id)).data as BytesData).bytes, photo);

    await h.a.activate();
    await MediaRepository().applyRepairWrites([
      RepairWrite(
        mediaId: id,
        newPlatformAssetId: 'A-2',
        newSourceType: MediaSourceType.platformGallery,
        newCloudAssetId: 'C-2',
      ),
    ]);
    await h.a.sync();
    await h.b.sync();

    expect(
      ((await h.b.tile(id)).data as BytesData).bytes,
      photo2,
      reason: 'the old mapping was dropped with the relink',
    );
  });

  test('a plain edit from the peer does not lift the backoff', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(id: 'A-1', bytes: photo, takenAt: taken),
      diveId: dive,
    );
    await h.a.sync();
    await h.b.sync();
    await h.b.tile(id);
    expect(
      (await h.b.assetCache.getCacheEntry(id))!.resolutionMethod,
      'unresolved',
    );

    await h.a.setManualElapsed(id, 42);
    await h.a.sync();
    await h.b.sync();

    expect(
      (await h.b.assetCache.getCacheEntry(id))!.resolutionMethod,
      'unresolved',
    );
  });

  test('S7: limited photo access on the origin device is inconclusive, '
      'not missing', () async {
    final dive = await h.b.createDive();
    final id = await h.b.linkGalleryPhoto(
      FakeGalleryAsset(id: 'B-7', bytes: photo, takenAt: taken),
      diveId: dive,
    );
    expect(await h.b.tileOutcome(id), TileOutcome.native);

    // The user later grants limited access and this photo is outside the
    // selected subset.
    h.b.gallery.permission = PhotoPermissionStatus.limited;
    h.b.gallery.hiddenFromLimitedAccess.add('B-7');
    await h.b.assetCache.clearEntry(id);

    final tile = await h.b.tile(id);
    expect((tile.data as UnavailableData).kind, UnavailableKind.accessDenied);
    expect((tile.data as UnavailableData).limitedAccess, isTrue);
    await h.b.checkTile(id);
    expect((await h.b.media(id))!.isOrphaned, isFalse);
  });
}
