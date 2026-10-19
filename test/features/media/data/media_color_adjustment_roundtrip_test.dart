import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_record_overlay.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../helpers/test_database.dart';

/// Issue #3520: a photo's hand colour adjustment lives on its media row.
void main() {
  late AppDatabase db;
  late MediaRepository media;

  setUp(() async {
    db = await setUpTestDatabase();
    media = MediaRepository();
  });

  tearDown(tearDownTestDatabase);

  MediaItem item() {
    final now = DateTime.utc(2026, 7, 1, 10);
    return MediaItem(
      id: '',
      filePath: '/photos/reef.jpg',
      originalFilename: 'reef.jpg',
      mediaType: MediaType.photo,
      takenAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('createMedia and updateMedia round-trip the adjustment', () async {
    const adjustment = ColorAdjustment(warmth: 0.3, autoOverride: true);
    final created = await media.createMedia(
      item().copyWith(colorAdjustment: adjustment),
    );
    expect((await media.getMediaById(created.id))!.colorAdjustment, adjustment);
  });

  test(
    'a stale snapshot written back does not roll the adjustment back',
    () async {
      // A poller reads the row, waits on the network, then writes its copy
      // back; the diver adjusted the photo in between.
      final created = await media.createMedia(item());
      final stale = (await media.getMediaById(created.id))!;
      const saved = ColorAdjustment(warmth: 0.6);
      await MediaColorAdjustmentRepository().setColorAdjustment(
        created.id,
        saved,
      );
      await media.updateMedia(stale.copyWith(caption: 'from the poller'));
      final after = (await media.getMediaById(created.id))!;
      expect(after.caption, 'from the poller');
      expect(after.colorAdjustment, saved);
    },
  );

  test('a malformed stored value reads as no adjustment', () async {
    final created = await media.createMedia(item());
    await db.customStatement(
      "UPDATE media SET color_adjustment = '{' WHERE id = ?",
      [created.id],
    );
    expect((await media.getMediaById(created.id))!.colorAdjustment, isNull);
  });

  test('an older peer that omits the column keeps the local value', () async {
    const adjustment = ColorAdjustment(tint: -0.4);
    final created = await media.createMedia(
      item().copyWith(colorAdjustment: adjustment),
    );
    final row = await (db.select(
      db.media,
    )..where((t) => t.id.equals(created.id))).getSingle();
    final local = row.toJson();
    expect(local['colorAdjustment'], adjustment.toJsonString());

    final fromOldPeer = Map<String, dynamic>.of(local)
      ..remove('colorAdjustment')
      ..['caption'] = 'edited on an old build';
    final merged = MediaData.fromJson(
      overlayOntoLocal('media', fromOldPeer, local),
    );
    expect(merged.caption, 'edited on an old build');
    expect(merged.colorAdjustment, adjustment.toJsonString());
  });
}
