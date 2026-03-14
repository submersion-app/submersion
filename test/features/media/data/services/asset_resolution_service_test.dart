import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

@GenerateMocks([LocalAssetCacheRepository, PhotoPickerService])
import 'asset_resolution_service_test.mocks.dart';

void main() {
  late MockLocalAssetCacheRepository mockCache;
  late MockPhotoPickerService mockPicker;
  late AssetResolutionService service;

  setUp(() {
    mockCache = MockLocalAssetCacheRepository();
    mockPicker = MockPhotoPickerService();
    service = AssetResolutionService(
      cacheRepository: mockCache,
      photoPickerService: mockPicker,
    );
  });

  MediaItem createTestItem({
    String id = 'media-1',
    String? platformAssetId = 'original-asset-id',
    String? originalFilename = 'IMG_001.jpg',
    DateTime? takenAt,
    int width = 4032,
    int height = 3024,
  }) {
    return MediaItem(
      id: id,
      platformAssetId: platformAssetId,
      originalFilename: originalFilename,
      mediaType: MediaType.photo,
      takenAt: takenAt ?? DateTime(2025, 6, 15, 10, 30, 0),
      width: width,
      height: height,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('resolveAssetId', () {
    test('returns cached ID when cache hit exists', () async {
      when(mockPicker.supportsGalleryBrowsing).thenReturn(true);
      when(
        mockCache.getCachedAssetId('media-1'),
      ).thenAnswer((_) async => 'cached-local-id');
      when(mockCache.isExpired('media-1')).thenAnswer((_) async => false);

      final result = await service.resolveAssetId(createTestItem());

      expect(result.localAssetId, equals('cached-local-id'));
      expect(result.status, equals(ResolutionStatus.resolved));
      verifyNever(mockPicker.getAssetsInDateRange(any, any));
    });

    test(
      'returns null with unresolved status when cache has unexpired unresolved entry',
      () async {
        when(mockPicker.supportsGalleryBrowsing).thenReturn(true);
        when(
          mockCache.getCachedAssetId('media-1'),
        ).thenAnswer((_) async => null);
        when(mockCache.getCacheEntry('media-1')).thenAnswer(
          (_) async => const CacheEntry(
            mediaId: 'media-1',
            localAssetId: null,
            resolvedAt: 0,
            resolutionMethod: 'unresolved',
            attemptCount: 0,
          ),
        );
        when(mockCache.isExpired('media-1')).thenAnswer((_) async => false);

        final result = await service.resolveAssetId(createTestItem());

        expect(result.localAssetId, isNull);
        expect(result.status, equals(ResolutionStatus.unavailable));
      },
    );

    test('returns platformAssetId for desktop platforms', () async {
      when(mockPicker.supportsGalleryBrowsing).thenReturn(false);

      final item = createTestItem();
      final result = await service.resolveAssetId(item);

      expect(result.localAssetId, equals('original-asset-id'));
      expect(result.status, equals(ResolutionStatus.resolved));
    });
  });

  group('matchByFilenameAndTimestamp (tier 1)', () {
    test('matches single asset with same filename and close timestamp', () {
      final item = createTestItem(
        originalFilename: 'IMG_001.jpg',
        takenAt: DateTime(2025, 6, 15, 10, 30, 0),
      );

      final candidates = [
        AssetInfo(
          id: 'local-match',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
          width: 4032,
          height: 3024,
          filename: 'IMG_001.jpg',
        ),
        AssetInfo(
          id: 'local-other',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 2),
          width: 4032,
          height: 3024,
          filename: 'IMG_002.jpg',
        ),
      ];

      final match = AssetResolutionService.matchByFilenameAndTimestamp(
        item,
        candidates,
      );

      expect(match, equals('local-match'));
    });

    test('returns null when multiple assets match filename', () {
      final item = createTestItem(
        originalFilename: 'IMG_001.jpg',
        takenAt: DateTime(2025, 6, 15, 10, 30, 0),
      );

      final candidates = [
        AssetInfo(
          id: 'dup-1',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
          width: 4032,
          height: 3024,
          filename: 'IMG_001.jpg',
        ),
        AssetInfo(
          id: 'dup-2',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 2),
          width: 4032,
          height: 3024,
          filename: 'IMG_001.jpg',
        ),
      ];

      final match = AssetResolutionService.matchByFilenameAndTimestamp(
        item,
        candidates,
      );

      expect(match, isNull);
    });
  });

  group('matchByTimestampAndDimensions (tier 2)', () {
    test('matches single asset with same dimensions and tight timestamp', () {
      final item = createTestItem(
        takenAt: DateTime(2025, 6, 15, 10, 30, 0),
        width: 4032,
        height: 3024,
      );

      final candidates = [
        AssetInfo(
          id: 'dim-match',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
          width: 4032,
          height: 3024,
          filename: 'different.jpg',
        ),
        AssetInfo(
          id: 'dim-miss',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
          width: 1920,
          height: 1080,
          filename: 'other.jpg',
        ),
      ];

      final match = AssetResolutionService.matchByTimestampAndDimensions(
        item,
        candidates,
      );

      expect(match, equals('dim-match'));
    });

    test('returns null when timestamp exceeds 2-second window', () {
      final item = createTestItem(
        takenAt: DateTime(2025, 6, 15, 10, 30, 0),
        width: 4032,
        height: 3024,
      );

      final candidates = [
        AssetInfo(
          id: 'too-far',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 4),
          width: 4032,
          height: 3024,
          filename: 'file.jpg',
        ),
      ];

      final match = AssetResolutionService.matchByTimestampAndDimensions(
        item,
        candidates,
      );

      expect(match, isNull);
    });
  });
}
