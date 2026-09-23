import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/photo_picker_service.dart';
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
      FakeGalleryAsset(id: 'A-b1', bytes: frame1, takenAt: taken),
      diveId: dive,
    );
    final id2 = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(id: 'A-b2', bytes: frame2, takenAt: taken),
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
      ),
    );
    h.b.gallery.add(
      FakeGalleryAsset(
        id: 'B-b2',
        bytes: frame2,
        takenAt: taken,
        filename: null,
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
    // Slice 8 gives FakeGalleryAsset a cloudId and stamps it at link time.
  }, skip: 'Media sync program S6: turns green in slice 8 (cloud identifier)');

  test(
    'S7: limited photo access on the origin device is inconclusive, '
    'not missing',
    () async {
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
      await h.b.checkTile(id);
      expect((await h.b.media(id))!.isOrphaned, isFalse);
    },
    skip:
        'Media sync program S7: turns green in slice 9 (Android limited access)',
  );
}
