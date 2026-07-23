import 'dart:typed_data';

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
      // Cached asset is still loadable
      when(
        mockPicker.getThumbnail('cached-local-id', size: 50),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final result = await service.resolveAssetId(createTestItem());

      expect(result.localAssetId, equals('cached-local-id'));
      expect(result.status, equals(ResolutionStatus.resolved));
      verifyNever(mockPicker.getAssetsInDateRange(any, any));
    });

    test(
      'clears cache and re-resolves when cached ID is no longer loadable',
      () async {
        when(mockPicker.supportsGalleryBrowsing).thenReturn(true);
        when(
          mockCache.getCachedAssetId('media-1'),
        ).thenAnswer((_) async => 'stale-cached-id');
        // The cached asset is no longer loadable
        when(
          mockPicker.getThumbnail('stale-cached-id', size: 50),
        ).thenAnswer((_) async => null);
        // After clearing, no cache entry
        when(mockCache.getCacheEntry('media-1')).thenAnswer((_) async => null);
        // The original ID also doesn't work
        when(
          mockPicker.getThumbnail('original-asset-id', size: 50),
        ).thenAnswer((_) async => null);
        // Gallery search returns a match
        when(mockPicker.getAssetsInDateRange(any, any)).thenAnswer(
          (_) async => [
            AssetInfo(
              id: 'new-local-id',
              type: AssetType.image,
              createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
              width: 4032,
              height: 3024,
              filename: 'IMG_001.jpg',
            ),
          ],
        );
        when(mockCache.clearEntry('media-1')).thenAnswer((_) async {});
        when(
          mockCache.cacheResolution(
            mediaId: anyNamed('mediaId'),
            localAssetId: anyNamed('localAssetId'),
            method: anyNamed('method'),
          ),
        ).thenAnswer((_) async {});

        final result = await service.resolveAssetId(createTestItem());

        // Should have cleared the stale cache entry
        verify(mockCache.clearEntry('media-1')).called(1);
        // Should have resolved to the new ID via filename matching
        expect(result.localAssetId, equals('new-local-id'));
        expect(result.status, equals(ResolutionStatus.resolved));
      },
    );

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

  // photo_manager's darwin layer serializes title as "" (not null) unless
  // FilterOption.needTitle is set, so both the stored originalFilename and
  // every candidate filename can be empty. An empty name is the ABSENCE of a
  // signal; treating it as a value silently reduces tier 1 to a timestamp-only
  // match that can bind the wrong asset.
  group('matchByFilenameAndTimestamp with empty filenames', () {
    test('returns null when the item filename is empty', () {
      final item = createTestItem(
        originalFilename: '',
        takenAt: DateTime(2025, 6, 15, 10, 30, 0),
      );

      final candidates = [
        AssetInfo(
          id: 'only-candidate',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
          width: 4000,
          height: 3000,
          filename: '',
        ),
      ];

      expect(
        AssetResolutionService.matchByFilenameAndTimestamp(item, candidates),
        isNull,
      );
    });

    test('ignores candidates whose filename is empty', () {
      final item = createTestItem(
        originalFilename: 'IMG_001.jpg',
        takenAt: DateTime(2025, 6, 15, 10, 30, 0),
      );

      final candidates = [
        AssetInfo(
          id: 'no-name',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
          width: 4000,
          height: 3000,
          filename: '',
        ),
      ];

      expect(
        AssetResolutionService.matchByFilenameAndTimestamp(item, candidates),
        isNull,
      );
    });
  });

  // Interval/burst sequences (a GoPro shooting every 2s) produce frames with
  // identical dimensions and no usable filename. The default +-2s window sees
  // the neighbours and refuses to guess, but capture timestamps survive the
  // iCloud round-trip intact, so the exact second is unique.
  group('matchByTimestampAndDimensions tolerance (burst sequences)', () {
    List<AssetInfo> burstFrames() => [
      AssetInfo(
        id: 'burst-minus-2s',
        type: AssetType.image,
        createDateTime: DateTime(2025, 6, 15, 10, 30, 8),
        width: 4000,
        height: 3000,
        filename: '',
      ),
      AssetInfo(
        id: 'burst-exact',
        type: AssetType.image,
        createDateTime: DateTime(2025, 6, 15, 10, 30, 10),
        width: 4000,
        height: 3000,
        filename: '',
      ),
      AssetInfo(
        id: 'burst-plus-2s',
        type: AssetType.image,
        createDateTime: DateTime(2025, 6, 15, 10, 30, 12),
        width: 4000,
        height: 3000,
        filename: '',
      ),
    ];

    MediaItem burstItem() => createTestItem(
      originalFilename: '',
      takenAt: DateTime(2025, 6, 15, 10, 30, 10),
      width: 4000,
      height: 3000,
    );

    test('default window is ambiguous across a burst', () {
      expect(
        AssetResolutionService.matchByTimestampAndDimensions(
          burstItem(),
          burstFrames(),
        ),
        isNull,
      );
    });

    test('zero tolerance resolves the burst frame uniquely', () {
      expect(
        AssetResolutionService.matchByTimestampAndDimensions(
          burstItem(),
          burstFrames(),
          tolerance: Duration.zero,
        ),
        equals('burst-exact'),
      );
    });

    test('zero tolerance matches on the capture SECOND, not the instant', () {
      // Gallery candidates can never carry sub-second precision
      // (photo_manager derives createDateTime from an integer second), but a
      // stored takenAt is epoch milliseconds. An exact-instant comparison
      // would make such a row unmatchable by any candidate at all.
      final item = createTestItem(
        originalFilename: '',
        takenAt: DateTime(2025, 6, 15, 10, 30, 10, 400),
        width: 4000,
        height: 3000,
      );

      expect(
        AssetResolutionService.matchByTimestampAndDimensions(
          item,
          burstFrames(),
          tolerance: Duration.zero,
        ),
        equals('burst-exact'),
      );
    });

    test('zero tolerance still refuses two frames in the same second', () {
      final sameSecond = [
        AssetInfo(
          id: 'twin-a',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 10),
          width: 4000,
          height: 3000,
          filename: '',
        ),
        AssetInfo(
          id: 'twin-b',
          type: AssetType.image,
          createDateTime: DateTime(2025, 6, 15, 10, 30, 10),
          width: 4000,
          height: 3000,
          filename: '',
        ),
      ];

      expect(
        AssetResolutionService.matchByTimestampAndDimensions(
          burstItem(),
          sameSecond,
          tolerance: Duration.zero,
        ),
        isNull,
      );
    });
  });
}
