import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

/// Set up this device's photo step counts what a store would hold (issue
/// #3482): photos and videos, never signatures or documents.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  MediaItem item(MediaType type) => MediaItem(
    id: '',
    mediaType: type,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'A-${type.name}',
    takenAt: DateTime(2026, 7, 1),
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );

  test('counts photos and videos only', () async {
    final repo = MediaRepository();
    expect(await repo.countPhotosAndVideos(), 0);

    for (final type in MediaType.values) {
      await repo.createMedia(item(type));
    }
    await repo.createMedia(item(MediaType.photo));

    expect(await repo.countPhotosAndVideos(), 3);
  });
}
