import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';

@GenerateMocks([PhotoPickerService])
import 'resolved_asset_providers_test.mocks.dart';

/// A resolution can be cached and still be stale: the asset it points at may
/// have been deleted from the library since. These providers are the place
/// that notices (the bytes come back null) and must drop the cached mapping,
/// or every later load repeats the same dead lookup.
void main() {
  late LocalCacheDatabase db;
  late LocalAssetCacheRepository cache;
  late MockPhotoPickerService picker;

  const mediaId = 'media-1';
  const assetId = 'local-1';

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    cache = LocalAssetCacheRepository(database: db);
    picker = MockPhotoPickerService();

    when(picker.supportsGalleryBrowsing).thenReturn(true);
    // The cached mapping still verifies as loadable (size: 50 probe), so
    // resolution succeeds and the providers go on to load real bytes.
    when(
      picker.getThumbnail(assetId, size: 50),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

    await cache.cacheResolution(
      mediaId: mediaId,
      localAssetId: assetId,
      method: 'original_id',
    );
  });

  tearDown(() => db.close());

  MediaItem item() => MediaItem(
    id: mediaId,
    platformAssetId: 'original-asset-id',
    originalFilename: 'IMG_001.jpg',
    mediaType: MediaType.photo,
    takenAt: DateTime(2025, 6, 15, 10, 30),
    width: 4000,
    height: 3000,
    createdAt: DateTime(2025, 6, 15),
    updatedAt: DateTime(2025, 6, 15),
  );

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        localAssetCacheRepositoryProvider.overrideWithValue(cache),
        photoPickerServiceProvider.overrideWithValue(picker),
        assetResolutionServiceProvider.overrideWithValue(
          AssetResolutionService(
            cacheRepository: cache,
            photoPickerService: picker,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('resolvedThumbnailProvider clears the cached resolution when the '
      'thumbnail no longer loads', () async {
    when(picker.getThumbnail(assetId)).thenAnswer((_) async => null);

    final result = await container().read(
      resolvedThumbnailProvider(item()).future,
    );

    expect(result.isUnavailable, isTrue);
    expect(await cache.getCacheEntry(mediaId), isNull);
  });

  test('resolvedThumbnailProvider returns bytes and keeps the cached '
      'resolution when the thumbnail loads', () async {
    when(
      picker.getThumbnail(assetId),
    ).thenAnswer((_) async => Uint8List.fromList([9, 9, 9]));

    final result = await container().read(
      resolvedThumbnailProvider(item()).future,
    );

    expect(result.isAvailable, isTrue);
    expect(result.bytes, equals(Uint8List.fromList([9, 9, 9])));
    expect((await cache.getCacheEntry(mediaId))?.localAssetId, equals(assetId));
  });

  test('resolvedFullResolutionProvider clears the cached resolution when the '
      'full-size bytes no longer load', () async {
    when(picker.getFileBytes(assetId)).thenAnswer((_) async => null);

    final result = await container().read(
      resolvedFullResolutionProvider(item()).future,
    );

    expect(result.isUnavailable, isTrue);
    expect(await cache.getCacheEntry(mediaId), isNull);
  });

  test('resolvedFullResolutionProvider returns bytes when the asset '
      'loads', () async {
    when(
      picker.getFileBytes(assetId),
    ).thenAnswer((_) async => Uint8List.fromList([7, 7]));

    final result = await container().read(
      resolvedFullResolutionProvider(item()).future,
    );

    expect(result.isAvailable, isTrue);
    expect(result.bytes, equals(Uint8List.fromList([7, 7])));
  });
}
