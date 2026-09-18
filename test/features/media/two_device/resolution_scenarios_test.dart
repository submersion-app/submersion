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

  test(
    'S5: a gallery photo B does not have reads as from another device and '
    'never orphans the row',
    () async {
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
      // Note for slice 7: gallery rows are inserted with a null
      // originDeviceId (MediaRepository._effectiveOriginDeviceId), so
      // origin-aware verdicts need the origin stamped on gallery rows too.
    },
    skip:
        'Media sync program S5: turns green in slice 7 (origin-aware verdicts)',
  );

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
