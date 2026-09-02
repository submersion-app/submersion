import 'package:flutter/services.dart';
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

    test('a cache hit costs no platform round-trip', () async {
      // The cached mapping is trusted rather than proven with a speculative
      // 50px fetch whose bytes are discarded. Staleness is detected by the
      // caller's real thumbnail fetch, which learns the same thing for free;
      // the old pre-check doubled every tile's PhotoKit traffic. Measured on a
      // 434-photo library: 1,568 verify round-trips costing 150s of wall time.
      when(mockPicker.supportsGalleryBrowsing).thenReturn(true);
      when(
        mockCache.getCachedAssetId('media-1'),
      ).thenAnswer((_) async => 'cached-local-id');

      final result = await service.resolveAssetId(createTestItem());

      expect(result.localAssetId, equals('cached-local-id'));
      expect(result.status, equals(ResolutionStatus.resolved));
      verifyNever(mockPicker.getThumbnail(any, size: anyNamed('size')));
      verifyNever(mockPicker.getAssetsInDateRange(any, any));
    });

    test(
      'reresolve clears the stale mapping and re-resolves from the gallery',
      () async {
        when(mockPicker.supportsGalleryBrowsing).thenReturn(true);
        // The caller reached here because the real thumbnail fetch for the
        // cached id came back empty, so the mapping is known to be stale.
        when(mockCache.getCacheEntry('media-1')).thenAnswer((_) async => null);
        // The original ID also doesn't work
        when(
          mockPicker.getThumbnail('original-asset-id', size: 50),
        ).thenAnswer((_) async => null);
        when(
          mockPicker.checkPermission(),
        ).thenAnswer((_) async => PhotoPermissionStatus.authorized);
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

        final result = await service.reresolve(createTestItem());

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

  // A gallery query against a library the app cannot access yet returns
  // zero candidates -- indistinguishable from "genuinely no matching
  // photo" unless permission is checked directly. Caching that as a long
  // (24h+) backoff means granting permission moments later doesn't help:
  // the item stays stuck showing unavailable until the backoff expires.
  // Permission is a transient, user-recoverable condition, so a resolution
  // attempt blocked by it must not be cached at all.
  group('resolveAssetId permission handling', () {
    void stubMissingPermission(PhotoPermissionStatus status) {
      when(mockPicker.supportsGalleryBrowsing).thenReturn(true);
      when(mockCache.getCachedAssetId('media-1')).thenAnswer((_) async => null);
      when(mockCache.getCacheEntry('media-1')).thenAnswer((_) async => null);
      when(
        mockPicker.getThumbnail('original-asset-id', size: 50),
      ).thenAnswer((_) async => null);
      when(mockPicker.checkPermission()).thenAnswer((_) async => status);
    }

    test(
      'does not cache or query the gallery when permission is not determined',
      () async {
        stubMissingPermission(PhotoPermissionStatus.notDetermined);

        final result = await service.resolveAssetId(createTestItem());

        // accessDenied, not unavailable. Callers are entitled to treat
        // unavailable as proof the asset is gone and orphan the row; nothing
        // was learned here, so that claim would be a fabrication.
        expect(result.status, equals(ResolutionStatus.accessDenied));
        expect(result.localAssetId, isNull);
        verifyNever(mockPicker.getAssetsInDateRange(any, any));
        verifyNever(
          mockCache.cacheResolution(
            mediaId: anyNamed('mediaId'),
            localAssetId: anyNamed('localAssetId'),
            method: anyNamed('method'),
          ),
        );
        verifyNever(mockCache.incrementAttempt(any));
      },
    );

    test('does not cache when permission is denied', () async {
      stubMissingPermission(PhotoPermissionStatus.denied);

      final result = await service.resolveAssetId(createTestItem());

      expect(result.status, equals(ResolutionStatus.accessDenied));
      verifyNever(mockPicker.getAssetsInDateRange(any, any));
      verifyNever(
        mockCache.cacheResolution(
          mediaId: anyNamed('mediaId'),
          localAssetId: anyNamed('localAssetId'),
          method: anyNamed('method'),
        ),
      );
    });

    test(
      'still searches the gallery when permission is only limited',
      () async {
        stubMissingPermission(PhotoPermissionStatus.limited);
        when(mockPicker.getAssetsInDateRange(any, any)).thenAnswer(
          (_) async => [
            AssetInfo(
              id: 'matched-id',
              type: AssetType.image,
              createDateTime: DateTime(2025, 6, 15, 10, 30, 1),
              width: 4032,
              height: 3024,
              filename: 'IMG_001.jpg',
            ),
          ],
        );
        when(
          mockCache.cacheResolution(
            mediaId: anyNamed('mediaId'),
            localAssetId: anyNamed('localAssetId'),
            method: anyNamed('method'),
          ),
        ).thenAnswer((_) async {});

        final result = await service.resolveAssetId(createTestItem());

        expect(result.status, equals(ResolutionStatus.resolved));
        expect(result.localAssetId, equals('matched-id'));
      },
    );

    // checkPermission() ultimately hits platform code (see
    // PhotoPickerServiceMobile.checkPermission()); a platform-channel
    // exception must not bubble out of resolveAssetId() and break a
    // Riverpod provider watching it. It should be treated like any other
    // gallery failure: log and report unavailable without caching.
    test(
      'returns accessDenied without caching when checkPermission throws',
      () async {
        when(mockPicker.supportsGalleryBrowsing).thenReturn(true);
        when(
          mockCache.getCachedAssetId('media-1'),
        ).thenAnswer((_) async => null);
        when(mockCache.getCacheEntry('media-1')).thenAnswer((_) async => null);
        when(
          mockPicker.getThumbnail('original-asset-id', size: 50),
        ).thenAnswer((_) async => null);
        when(
          mockPicker.checkPermission(),
        ).thenThrow(PlatformException(code: 'permission_check_failed'));

        final result = await service.resolveAssetId(createTestItem());

        expect(result.status, equals(ResolutionStatus.accessDenied));
        expect(result.localAssetId, isNull);
        verifyNever(mockPicker.getAssetsInDateRange(any, any));
        verifyNever(
          mockCache.cacheResolution(
            mediaId: anyNamed('mediaId'),
            localAssetId: anyNamed('localAssetId'),
            method: anyNamed('method'),
          ),
        );
      },
    );
  });

  /// Drives the full tier ladder rather than the matchers in isolation, so
  /// the order the tiers run in is pinned: the exact-second tier must be
  /// reached before the fuzzy window, which is the whole point of adding it.
  group('resolveAssetId tier selection', () {
    /// Cross-device state: nothing cached, and the stored platformAssetId
    /// does not load here, so resolution falls through to gallery matching.
    void stubGalleryFallback(List<AssetInfo> candidates) {
      when(mockPicker.supportsGalleryBrowsing).thenReturn(true);
      when(mockCache.getCachedAssetId('media-1')).thenAnswer((_) async => null);
      when(mockCache.getCacheEntry('media-1')).thenAnswer((_) async => null);
      when(
        mockPicker.getThumbnail('original-asset-id', size: 50),
      ).thenAnswer((_) async => null);
      when(
        mockPicker.checkPermission(),
      ).thenAnswer((_) async => PhotoPermissionStatus.authorized);
      when(
        mockPicker.getAssetsInDateRange(any, any),
      ).thenAnswer((_) async => candidates);
      when(
        mockCache.cacheResolution(
          mediaId: anyNamed('mediaId'),
          localAssetId: anyNamed('localAssetId'),
          method: anyNamed('method'),
        ),
      ).thenAnswer((_) async {});
    }

    AssetInfo frame(String id, int second) => AssetInfo(
      id: id,
      type: AssetType.image,
      createDateTime: DateTime(2025, 6, 15, 10, 30, second),
      width: 4000,
      height: 3000,
      filename: '',
    );

    test('resolves a burst frame via the exact-second tier', () async {
      // Three interval-shot frames two seconds apart. The fuzzy +-2s window
      // sees all three and cannot choose; the exact second is unique.
      stubGalleryFallback([
        frame('burst-minus-2s', 8),
        frame('burst-exact', 10),
        frame('burst-plus-2s', 12),
      ]);

      final result = await service.resolveAssetId(
        createTestItem(
          originalFilename: '',
          takenAt: DateTime(2025, 6, 15, 10, 30, 10),
          width: 4000,
          height: 3000,
        ),
      );

      expect(result.status, equals(ResolutionStatus.resolved));
      expect(result.localAssetId, equals('burst-exact'));
      verify(
        mockCache.cacheResolution(
          mediaId: 'media-1',
          localAssetId: 'burst-exact',
          method: 'exact_timestamp_dimensions',
        ),
      ).called(1);
    });

    test('falls back to the fuzzy window when no exact second matches', () {
      // A lone candidate one second off: the exact tier finds nothing, so
      // the +-2s dimension tier takes it.
      stubGalleryFallback([frame('drifted', 11)]);

      return service
          .resolveAssetId(
            createTestItem(
              originalFilename: '',
              takenAt: DateTime(2025, 6, 15, 10, 30, 10),
              width: 4000,
              height: 3000,
            ),
          )
          .then((result) {
            expect(result.status, equals(ResolutionStatus.resolved));
            expect(result.localAssetId, equals('drifted'));
            verify(
              mockCache.cacheResolution(
                mediaId: 'media-1',
                localAssetId: 'drifted',
                method: 'timestamp_dimensions',
              ),
            ).called(1);
          });
    });

    test('records unresolved when every tier is ambiguous', () async {
      // Two frames sharing the exact capture second and dimensions: nothing
      // distinguishes them, so the service must refuse rather than guess.
      stubGalleryFallback([frame('twin-a', 10), frame('twin-b', 10)]);
      when(
        mockCache.cacheResolution(
          mediaId: anyNamed('mediaId'),
          localAssetId: null,
          method: 'unresolved',
        ),
      ).thenAnswer((_) async {});

      final result = await service.resolveAssetId(
        createTestItem(
          originalFilename: '',
          takenAt: DateTime(2025, 6, 15, 10, 30, 10),
          width: 4000,
          height: 3000,
        ),
      );

      expect(result.status, equals(ResolutionStatus.unavailable));
      expect(result.localAssetId, isNull);
    });
  });

  group('galleryQueryBucket', () {
    // These lock the instant-preserving contract. Be aware that the bug they
    // were written for -- reinterpreting a UTC DateTime's calendar fields as
    // local -- is INVISIBLE on a host running at UTC, where the two readings
    // coincide. CI runs Linux at UTC, so these pass there either way; they
    // genuinely discriminate only off-UTC. Keeping them anyway: they document
    // and pin the contract, and the last assertion below fails everywhere if
    // the toLocal() calls are removed and replaced with field copying.
    test('a UTC input lands in a bucket that still contains that instant', () {
      final instant = DateTime.utc(2026, 12, 27, 14, 2, 36);
      final (start, end) = AssetResolutionService.galleryQueryBucket(
        instant.subtract(const Duration(seconds: 5)),
        instant.add(const Duration(seconds: 5)),
      );

      expect(start.isAfter(instant), isFalse);
      expect(end.isBefore(instant), isFalse);
    });

    test('the same instant buckets identically however it is expressed', () {
      // A UTC DateTime and its toLocal() twin are the SAME instant, so they
      // must produce the same query window. Under the old field-copying code
      // they produced windows a whole UTC offset apart, which is what stranded
      // the raw-instant reading.
      final utc = DateTime.utc(2026, 12, 27, 14, 2, 36);
      final local = utc.toLocal();

      final fromUtc = AssetResolutionService.galleryQueryBucket(utc, utc);
      final fromLocal = AssetResolutionService.galleryQueryBucket(local, local);

      expect(fromUtc.$1, equals(fromLocal.$1));
      expect(fromUtc.$2, equals(fromLocal.$2));
    });

    test('the bucket is always a local DateTime, whatever went in', () {
      // The gallery API takes local bounds; handing it a UTC DateTime is how
      // the window drifted in the first place.
      final (start, end) = AssetResolutionService.galleryQueryBucket(
        DateTime.utc(2026, 12, 27, 14, 2, 36),
        DateTime.utc(2026, 12, 27, 14, 2, 46),
      );

      expect(start.isUtc, isFalse);
      expect(end.isUtc, isFalse);
    });

    test('the end bucket rolls over the hour correctly', () {
      final (_, end) = AssetResolutionService.galleryQueryBucket(
        DateTime(2026, 12, 27, 14, 59, 55),
        DateTime(2026, 12, 27, 14, 59, 58),
      );

      expect(end, equals(DateTime(2026, 12, 27, 15, 0)));
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

  // MediaItem.takenAt is stored wall-clock-as-UTC, while photo_manager reports
  // AssetInfo.createDateTime as LOCAL. Both matchers used to compare the two
  // as instants, so on any host west or east of UTC the difference was the
  // host's offset rather than real clock drift, and every tier missed. The
  // picker write path masked this by persisting an unnormalised local
  // timestamp; once that was corrected these comparisons had to convert.
  //
  // NOTE: these cases can only fail on a host whose local time is not UTC --
  // where the two conventions coincide there is nothing to convert. CI runners
  // default to UTC, so treat them as a guard for developer machines.
  group('wall-clock-UTC takenAt against a local gallery candidate', () {
    List<AssetInfo> candidatesAt(DateTime local) => [
      AssetInfo(
        id: 'local-match',
        type: AssetType.image,
        createDateTime: local,
        width: 4032,
        height: 3024,
        filename: 'IMG_001.jpg',
      ),
    ];

    test('tier 1 matches on filename plus the same wall-clock second', () {
      final item = createTestItem(
        originalFilename: 'IMG_001.jpg',
        takenAt: DateTime.utc(2025, 6, 15, 10, 30, 0),
      );

      expect(
        AssetResolutionService.matchByFilenameAndTimestamp(
          item,
          candidatesAt(DateTime(2025, 6, 15, 10, 30, 1)),
        ),
        equals('local-match'),
      );
    });

    test('tier 2 matches on the exact wall-clock capture second', () {
      final item = createTestItem(
        originalFilename: '',
        takenAt: DateTime.utc(2025, 6, 15, 10, 30, 0),
      );

      expect(
        AssetResolutionService.matchByTimestampAndDimensions(
          item,
          candidatesAt(DateTime(2025, 6, 15, 10, 30, 0)),
          tolerance: Duration.zero,
        ),
        equals('local-match'),
      );
    });

    test('a genuinely distant candidate is still rejected', () {
      final item = createTestItem(
        originalFilename: 'IMG_001.jpg',
        takenAt: DateTime.utc(2025, 6, 15, 10, 30, 0),
      );

      expect(
        AssetResolutionService.matchByFilenameAndTimestamp(
          item,
          candidatesAt(DateTime(2025, 6, 15, 10, 31, 0)),
        ),
        isNull,
      );
    });

    // Rows written by the pre-normalisation import path hold the INSTANT of a
    // local DateTime, which MediaRepository then hydrates as UTC -- so their
    // calendar fields are the capture time plus the host offset, and it is the
    // raw value, not the restated one, that lines up with a gallery candidate.
    // Nothing in the schema distinguishes them from correctly-written rows, so
    // both readings have to be tried or every already-linked photo becomes
    // unresolvable the moment its platformAssetId goes stale.
    DateTime legacyStored(DateTime captureLocal) =>
        DateTime.fromMillisecondsSinceEpoch(
          captureLocal.millisecondsSinceEpoch,
          isUtc: true,
        );

    test('tier 1 still matches a legacy row written as a local instant', () {
      final capture = DateTime(2025, 6, 15, 10, 30, 0);
      final item = createTestItem(
        originalFilename: 'IMG_001.jpg',
        takenAt: legacyStored(capture),
      );

      expect(
        AssetResolutionService.matchByFilenameAndTimestamp(
          item,
          candidatesAt(capture),
        ),
        equals('local-match'),
      );
    });

    test('tier 2 still matches a legacy row written as a local instant', () {
      final capture = DateTime(2025, 6, 15, 10, 30, 0);
      final item = createTestItem(
        originalFilename: '',
        takenAt: legacyStored(capture),
      );

      expect(
        AssetResolutionService.matchByTimestampAndDimensions(
          item,
          candidatesAt(capture),
          tolerance: Duration.zero,
        ),
        equals('local-match'),
      );
    });

    test('offering both readings still refuses an ambiguous pair', () {
      // One candidate sits on each reading of the same stored value, so the
      // row cannot be attributed to either without guessing.
      final capture = DateTime(2025, 6, 15, 10, 30, 0);
      final stored = legacyStored(capture);
      final item = createTestItem(
        originalFilename: 'IMG_001.jpg',
        takenAt: stored,
      );

      final ambiguous = [
        AssetInfo(
          id: 'on-legacy-reading',
          type: AssetType.image,
          createDateTime: capture,
          width: 4032,
          height: 3024,
          filename: 'IMG_001.jpg',
        ),
        AssetInfo(
          id: 'on-restated-reading',
          type: AssetType.image,
          createDateTime: DateTime(
            stored.year,
            stored.month,
            stored.day,
            stored.hour,
            stored.minute,
            stored.second,
          ),
          width: 4032,
          height: 3024,
          filename: 'IMG_001.jpg',
        ),
      ];

      // Vacuous on a UTC host, where the two readings collapse to one and the
      // list above holds two candidates at the same instant -- still ambiguous.
      expect(
        AssetResolutionService.matchByFilenameAndTimestamp(item, ambiguous),
        isNull,
      );
    });
  });
}
