import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

@GenerateMocks([MediaRepository, EnrichmentService])
import 'media_import_service_test.mocks.dart';

/// Helper to create an AssetInfo for testing.
AssetInfo _testAsset(String id) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2024, 1, 15, 10, 30),
  width: 1920,
  height: 1080,
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
  });
}
