import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

@GenerateMocks([MediaRepository, EnrichmentService])
import 'media_import_service_test.mocks.dart';

/// Helper to create an AssetInfo for testing.
AssetInfo _testAsset(String id, {String? filePath}) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2024, 1, 15, 10, 30),
  width: 1920,
  height: 1080,
  filePath: filePath,
);

/// Helper to create a minimal Dive for testing.
Dive _testDive({String id = 'dive-1'}) =>
    Dive(id: id, dateTime: DateTime(2024, 1, 15, 10, 0));

/// Helper to create a saved MediaItem returned by the repository.
MediaItem _savedMediaItem({
  required String id,
  required String diveId,
  required String platformAssetId,
}) => MediaItem(
  id: id,
  diveId: diveId,
  platformAssetId: platformAssetId,
  mediaType: MediaType.photo,
  takenAt: DateTime(2024, 1, 15, 10, 30),
  createdAt: DateTime(2024, 1, 15, 10, 30),
  updatedAt: DateTime(2024, 1, 15, 10, 30),
);

void main() {
  late MockMediaRepository mockMediaRepository;
  late MockEnrichmentService mockEnrichmentService;
  late MediaImportService service;
  late Dive testDive;

  setUp(() {
    mockMediaRepository = MockMediaRepository();
    mockEnrichmentService = MockEnrichmentService();
    service = MediaImportService(
      mediaRepository: mockMediaRepository,
      enrichmentService: mockEnrichmentService,
    );
    testDive = _testDive();
    // Default: no desktop rows linked. Tests exercising path-based dedupe
    // re-stub this for their specific dive id.
    when(
      mockMediaRepository.getLinkedLocalPathsForDive(any),
    ).thenAnswer((_) async => <String>{});
  });

  group('ImportResult', () {
    test(
      'totalAttempted includes imported, failures, and skippedDuplicates',
      () {
        final result = ImportResult(
          imported: [
            _savedMediaItem(id: 'm1', diveId: 'dive-1', platformAssetId: 'a1'),
          ],
          failures: const {'a2': 'error'},
          skippedDuplicates: 3,
        );

        expect(result.totalAttempted, 5);
      },
    );

    test('allSucceeded is true when no failures', () {
      final success = ImportResult(
        imported: [
          _savedMediaItem(id: 'm1', diveId: 'dive-1', platformAssetId: 'a1'),
        ],
        failures: const {},
        skippedDuplicates: 0,
      );

      expect(success.allSucceeded, isTrue);
    });

    test('allSucceeded is false when there are failures', () {
      const withFailures = ImportResult(
        imported: [],
        failures: {'a1': 'error'},
        skippedDuplicates: 0,
      );

      expect(withFailures.allSucceeded, isFalse);
    });

    test('allSucceeded is true even when there are skipped duplicates', () {
      const withDuplicates = ImportResult(
        imported: [],
        failures: {},
        skippedDuplicates: 2,
      );

      expect(withDuplicates.allSucceeded, isTrue);
    });

    test('skippedDuplicates defaults to 0', () {
      const result = ImportResult(imported: [], failures: {});

      expect(result.skippedDuplicates, 0);
      expect(result.totalAttempted, 0);
      expect(result.allSucceeded, isTrue);
    });
  });

  group('MediaImportService', () {
    group('importPhotosForDive - duplicate filtering', () {
      test('skips assets that are already linked to the dive', () async {
        final assets = [
          _testAsset('asset-1'),
          _testAsset('asset-2'),
          _testAsset('asset-3'),
        ];

        // asset-1 and asset-3 are already linked
        when(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).thenAnswer((_) async => {'asset-1', 'asset-3'});

        // Only asset-2 should be imported
        when(mockMediaRepository.createMedia(any)).thenAnswer(
          (invocation) async => _savedMediaItem(
            id: 'media-2',
            diveId: 'dive-1',
            platformAssetId: 'asset-2',
          ),
        );

        final result = await service.importPhotosForDive(
          selectedAssets: assets,
          dive: testDive,
        );

        expect(result.imported.length, 1);
        expect(result.skippedDuplicates, 2);
        expect(result.failures.length, 0);
        expect(result.totalAttempted, 3);

        // Verify createMedia was called exactly once (for asset-2 only)
        verify(mockMediaRepository.createMedia(any)).called(1);
      });

      test('imports all assets when none are duplicates', () async {
        final assets = [_testAsset('asset-1'), _testAsset('asset-2')];

        when(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).thenAnswer((_) async => <String>{});

        when(mockMediaRepository.createMedia(any)).thenAnswer((
          invocation,
        ) async {
          final item = invocation.positionalArguments[0] as MediaItem;
          return _savedMediaItem(
            id: 'media-${item.platformAssetId}',
            diveId: 'dive-1',
            platformAssetId: item.platformAssetId ?? '',
          );
        });

        final result = await service.importPhotosForDive(
          selectedAssets: assets,
          dive: testDive,
        );

        expect(result.imported.length, 2);
        expect(result.skippedDuplicates, 0);
        expect(result.failures.length, 0);
        expect(result.totalAttempted, 2);
        expect(result.allSucceeded, isTrue);

        verify(mockMediaRepository.createMedia(any)).called(2);
      });

      test(
        'handles mixed batch with some new and some duplicate assets',
        () async {
          final assets = [
            _testAsset('asset-1'),
            _testAsset('asset-2'),
            _testAsset('asset-3'),
            _testAsset('asset-4'),
          ];

          // asset-2 is already linked
          when(
            mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
          ).thenAnswer((_) async => {'asset-2'});

          when(mockMediaRepository.createMedia(any)).thenAnswer((
            invocation,
          ) async {
            final item = invocation.positionalArguments[0] as MediaItem;
            return _savedMediaItem(
              id: 'media-${item.platformAssetId}',
              diveId: 'dive-1',
              platformAssetId: item.platformAssetId ?? '',
            );
          });

          final result = await service.importPhotosForDive(
            selectedAssets: assets,
            dive: testDive,
          );

          expect(result.imported.length, 3);
          expect(result.skippedDuplicates, 1);
          expect(result.failures.length, 0);
          expect(result.totalAttempted, 4);
          expect(result.allSucceeded, isTrue);

          verify(mockMediaRepository.createMedia(any)).called(3);
        },
      );

      test(
        'returns 0 imported and correct skippedDuplicates when all are duplicates',
        () async {
          final assets = [_testAsset('asset-1'), _testAsset('asset-2')];

          // Both already linked
          when(
            mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
          ).thenAnswer((_) async => {'asset-1', 'asset-2'});

          final result = await service.importPhotosForDive(
            selectedAssets: assets,
            dive: testDive,
          );

          expect(result.imported.length, 0);
          expect(result.skippedDuplicates, 2);
          expect(result.failures.length, 0);
          expect(result.totalAttempted, 2);
          expect(result.allSucceeded, isTrue);

          // createMedia should never be called
          verifyNever(mockMediaRepository.createMedia(any));
        },
      );

      test('handles empty selectedAssets list', () async {
        when(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).thenAnswer((_) async => <String>{});

        final result = await service.importPhotosForDive(
          selectedAssets: const [],
          dive: testDive,
        );

        expect(result.imported.length, 0);
        expect(result.skippedDuplicates, 0);
        expect(result.failures.length, 0);
        expect(result.totalAttempted, 0);
        expect(result.allSucceeded, isTrue);

        verifyNever(mockMediaRepository.createMedia(any));
      });

      test('counts failures correctly alongside skipped duplicates', () async {
        final assets = [
          _testAsset('asset-1'),
          _testAsset('asset-2'),
          _testAsset('asset-3'),
        ];

        // asset-1 is a duplicate
        when(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).thenAnswer((_) async => {'asset-1'});

        when(mockMediaRepository.createMedia(any)).thenAnswer((
          invocation,
        ) async {
          final item = invocation.positionalArguments[0] as MediaItem;
          // Make asset-3 fail
          if (item.platformAssetId == 'asset-3') {
            throw Exception('Storage full');
          }
          return _savedMediaItem(
            id: 'media-${item.platformAssetId}',
            diveId: 'dive-1',
            platformAssetId: item.platformAssetId ?? '',
          );
        });

        final result = await service.importPhotosForDive(
          selectedAssets: assets,
          dive: testDive,
        );

        expect(result.imported.length, 1);
        expect(result.skippedDuplicates, 1);
        expect(result.failures.length, 1);
        expect(result.failures.containsKey('asset-3'), isTrue);
        expect(result.totalAttempted, 3);
        expect(result.allSucceeded, isFalse);
      });
    });

    group('importPhotosForDive - desktop file paths', () {
      // On Windows / Linux the picker has no platform gallery: it opens a
      // file dialog and hands back an AssetInfo whose id is a synthetic
      // '<mtime>_<hashCode>' key that only resolves through an in-memory map
      // on the picker service. Persisting such a row as platformGallery left
      // the path columns blank and routed display through
      // PlatformGalleryResolver -> photo_manager, which has no Windows
      // backend, so every imported photo rendered "File not found".
      // A picker-supplied filePath must therefore be persisted as a
      // localFile row so LocalFileResolver reads it straight off disk.
      test('persists a picker-supplied filePath as a localFile row', () async {
        const path = r'C:\Users\stiebs\Pictures\DIVE_0042.JPG';
        final assets = [_testAsset('42_998877', filePath: path)];

        when(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).thenAnswer((_) async => <String>{});

        MediaItem? persisted;
        when(mockMediaRepository.createMedia(any)).thenAnswer((
          invocation,
        ) async {
          persisted = invocation.positionalArguments[0] as MediaItem;
          return _savedMediaItem(
            id: 'media-1',
            diveId: 'dive-1',
            platformAssetId: persisted!.platformAssetId ?? '',
          );
        });

        await service.importPhotosForDive(
          selectedAssets: assets,
          dive: testDive,
        );

        expect(persisted, isNotNull);
        expect(persisted!.sourceType, MediaSourceType.localFile);
        expect(persisted!.localPath, path);
        // A localFile row must NOT carry a gallery asset id: several features
        // gate purely on `platformAssetId != null` (MediaItem.isGalleryPhoto,
        // PhotoViewerPage's write-metadata action, resolvedFilePathProvider's
        // gallery fast path) and would route a desktop file through
        // photo_manager, which has no Windows backend.
        expect(persisted!.platformAssetId, isNull);
      });

      test('skips a file already linked to the dive by path', () async {
        const path = r'C:\Users\stiebs\Pictures\DIVE_0042.JPG';
        final assets = [_testAsset('42_998877', filePath: path)];

        when(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).thenAnswer((_) async => <String>{});
        // Nulling platformAssetId means the asset-id filter can no longer see
        // desktop rows, so dedupe has to run off the path instead. Keying on
        // the path is also strictly better than the old synthetic id, which
        // embedded the mtime and silently changed when a file was touched.
        when(
          mockMediaRepository.getLinkedLocalPathsForDive('dive-1'),
        ).thenAnswer((_) async => {path});

        final result = await service.importPhotosForDive(
          selectedAssets: assets,
          dive: testDive,
        );

        expect(result.imported, isEmpty);
        expect(result.skippedDuplicates, 1);
        verifyNever(mockMediaRepository.createMedia(any));
      });

      // Each lookup only feeds one branch of the dedupe filter, so querying
      // both on every import does dead work: a mobile selection never has a
      // path to compare, and a desktop selection never has a gallery id.
      test('skips the path lookup when no asset carries a path', () async {
        when(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).thenAnswer((_) async => <String>{});
        when(mockMediaRepository.createMedia(any)).thenAnswer(
          (_) async =>
              _savedMediaItem(id: 'm1', diveId: 'dive-1', platformAssetId: 'a'),
        );

        await service.importPhotosForDive(
          selectedAssets: [_testAsset('asset-1')],
          dive: testDive,
        );

        verifyNever(mockMediaRepository.getLinkedLocalPathsForDive(any));
        verify(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).called(1);
      });

      test(
        'skips the asset-id lookup when every asset carries a path',
        () async {
          when(
            mockMediaRepository.getLinkedLocalPathsForDive('dive-1'),
          ).thenAnswer((_) async => <String>{});
          when(mockMediaRepository.createMedia(any)).thenAnswer(
            (_) async => _savedMediaItem(
              id: 'm1',
              diveId: 'dive-1',
              platformAssetId: '',
            ),
          );

          await service.importPhotosForDive(
            selectedAssets: [_testAsset('1_2', filePath: '/photos/a.jpg')],
            dive: testDive,
          );

          verifyNever(mockMediaRepository.getLinkedAssetIdsForDive(any));
          verify(
            mockMediaRepository.getLinkedLocalPathsForDive('dive-1'),
          ).called(1);
        },
      );

      test('queries both lookups for a mixed selection', () async {
        when(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).thenAnswer((_) async => <String>{});
        when(
          mockMediaRepository.getLinkedLocalPathsForDive('dive-1'),
        ).thenAnswer((_) async => <String>{});
        when(mockMediaRepository.createMedia(any)).thenAnswer(
          (_) async =>
              _savedMediaItem(id: 'm1', diveId: 'dive-1', platformAssetId: ''),
        );

        await service.importPhotosForDive(
          selectedAssets: [
            _testAsset('asset-1'),
            _testAsset('1_2', filePath: '/photos/a.jpg'),
          ],
          dive: testDive,
        );

        verify(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).called(1);
        verify(
          mockMediaRepository.getLinkedLocalPathsForDive('dive-1'),
        ).called(1);
      });

      test('imports a file whose path is not yet linked', () async {
        final assets = [_testAsset('1_2', filePath: '/photos/a.jpg')];

        when(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).thenAnswer((_) async => <String>{});
        when(
          mockMediaRepository.getLinkedLocalPathsForDive('dive-1'),
        ).thenAnswer((_) async => {'/photos/other.jpg'});
        when(mockMediaRepository.createMedia(any)).thenAnswer(
          (_) async =>
              _savedMediaItem(id: 'm1', diveId: 'dive-1', platformAssetId: ''),
        );

        final result = await service.importPhotosForDive(
          selectedAssets: assets,
          dive: testDive,
        );

        expect(result.imported.length, 1);
        expect(result.skippedDuplicates, 0);
      });

      test('leaves a gallery asset without a path as platformGallery', () {
        final assets = [_testAsset('asset-1')];

        when(
          mockMediaRepository.getLinkedAssetIdsForDive('dive-1'),
        ).thenAnswer((_) async => <String>{});

        MediaItem? persisted;
        when(mockMediaRepository.createMedia(any)).thenAnswer((
          invocation,
        ) async {
          persisted = invocation.positionalArguments[0] as MediaItem;
          return _savedMediaItem(
            id: 'media-1',
            diveId: 'dive-1',
            platformAssetId: persisted!.platformAssetId ?? '',
          );
        });

        return service
            .importPhotosForDive(selectedAssets: assets, dive: testDive)
            .then((_) {
              expect(persisted, isNotNull);
              expect(persisted!.sourceType, MediaSourceType.platformGallery);
              expect(persisted!.localPath, isNull);
              expect(persisted!.platformAssetId, 'asset-1');
            });
      });
    });
  });
}
