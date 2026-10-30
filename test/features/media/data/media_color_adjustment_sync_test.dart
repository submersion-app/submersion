import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Issue #3520: a colour adjustment cleared on one device is cleared on the
/// others. Media rows merge through an upsert that leaves a null column
/// unwritten (so a peer on an older build cannot erase a column it does not
/// know), which means a clear stored as SQL NULL would never land.
void main() {
  late String id;
  final adjustments = MediaColorAdjustmentRepository();

  setUp(() async {
    await setUpTestDatabase();
    id = (await MediaRepository().createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        localPath: '/nowhere/reef.jpg',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    )).id;
  });

  tearDown(() async {
    await tearDownTestDatabase();
    SyncClock.instance.reset();
  });

  Future<void> apply(Map<String, dynamic> row) =>
      SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
      ).debugApplyPayload(
        SyncPayload(
          version: 1,
          exportedAt: 0,
          deviceId: 'peer',
          checksum: '',
          data: SyncData(media: [row]),
          deletions: const {},
        ),
      );

  Future<ColorAdjustment?> stored() async =>
      (await MediaRepository().getMediaById(id))!.colorAdjustment;

  /// The row a peer sends after its diver saves [adjustment] there.
  Future<Map<String, dynamic>> peerRowAfter(ColorAdjustment? adjustment) async {
    await adjustments.setColorAdjustment(id, adjustment);
    return (await SyncDataSerializer().fetchRecord('media', id))!;
  }

  /// This device's own, already published, adjustment.
  Future<void> holdLocally(ColorAdjustment adjustment) async {
    await adjustments.setColorAdjustment(id, adjustment);
    await SyncRepository().clearPendingRecords();
  }

  /// Applies the peer's [row] as the newest copy, so it wins the row.
  Future<void> applyNewest(Map<String, dynamic> row) =>
      apply({...row, 'hlc': SyncClock.instance.issue()});

  test('a reset on a peer clears the adjustment here', () async {
    final reset = await peerRowAfter(null);
    await holdLocally(const ColorAdjustment(warmth: 0.5));

    await applyNewest(reset);

    expect(await stored(), isNull);
  });

  test('sliders moved back to neutral on a peer clear it here too', () async {
    final neutral = await peerRowAfter(const ColorAdjustment());
    await holdLocally(const ColorAdjustment(tint: -0.3, autoOverride: false));

    await applyNewest(neutral);

    expect(await stored(), isNull);
  });

  test("a peer's adjustment still replaces this device's", () async {
    const theirs = ColorAdjustment(brightness: 0.2);
    final row = await peerRowAfter(theirs);
    await holdLocally(const ColorAdjustment(warmth: 0.5));

    await applyNewest(row);

    expect(await stored(), theirs);
  });
}
