import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

/// A gallery row's verdict depends on where it was linked (media sync
/// program spec 6.1), so the link has to record it. Store-backed and network
/// rows resolve the same way on every device and still record none.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  MediaItem item(MediaSourceType type, {String? origin}) => MediaItem(
    id: '',
    mediaType: MediaType.photo,
    sourceType: type,
    platformAssetId: 'A-1',
    originDeviceId: origin,
    takenAt: DateTime(2026, 7, 1),
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );

  Future<String?> originOf(MediaItem created) async =>
      (await MediaRepository().getMediaById(created.id))!.originDeviceId;

  test('a gallery link records the device that made it', () async {
    final created = await MediaRepository().createMedia(
      item(MediaSourceType.platformGallery),
    );
    expect(await originOf(created), await SyncRepository().getDeviceId());
  });

  test('an origin the caller already names is kept', () async {
    final created = await MediaRepository().createMedia(
      item(MediaSourceType.platformGallery, origin: 'phone'),
    );
    expect(await originOf(created), 'phone');
  });

  test('store-backed and network rows still record none', () async {
    for (final type in [
      MediaSourceType.mediaStore,
      MediaSourceType.networkUrl,
    ]) {
      final created = await MediaRepository().createMedia(item(type));
      expect(await originOf(created), isNull, reason: type.name);
    }
  });
}
