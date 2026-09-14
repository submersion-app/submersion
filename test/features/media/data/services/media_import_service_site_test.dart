import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/linked_gallery_assets.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

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

/// A gallery row already attached to site-1.
MediaItem _siteRow(String platformAssetId) => MediaItem(
  id: 'media-$platformAssetId',
  siteId: 'site-1',
  platformAssetId: platformAssetId,
  mediaType: MediaType.photo,
  takenAt: DateTime.utc(2024, 1, 15, 10, 30),
  createdAt: DateTime.utc(2024, 1, 15),
  updatedAt: DateTime.utc(2024, 1, 15),
);

void main() {
  late MockMediaRepository mockMediaRepository;
  late MockEnrichmentService mockEnrichmentService;
  late MediaImportService service;
  late List<String> createdIds;

  setUp(() {
    mockMediaRepository = MockMediaRepository();
    mockEnrichmentService = MockEnrichmentService();
    createdIds = [];
    service = MediaImportService(
      mediaRepository: mockMediaRepository,
      enrichmentService: mockEnrichmentService,
      onMediaCreated: createdIds.add,
    );
    when(
      mockMediaRepository.getGalleryLinksForSite(any),
    ).thenAnswer((_) async => <MediaItem>[]);
    when(
      mockMediaRepository.getLinkedLocalPathsForSite(any),
    ).thenAnswer((_) async => <String>{});
    when(mockMediaRepository.createMedia(any)).thenAnswer((invocation) async {
      final item = invocation.positionalArguments.first as MediaItem;
      return item.copyWith(id: 'saved-${item.platformAssetId ?? "path"}');
    });
  });

  test(
    'importPhotosForSite links assets to the site without enrichment',
    () async {
      final result = await service.importPhotosForSite(
        selectedAssets: [_testAsset('a1'), _testAsset('a2')],
        siteId: 'site-1',
      );

      expect(result.imported, hasLength(2));
      expect(result.imported.every((m) => m.siteId == 'site-1'), isTrue);
      expect(result.imported.every((m) => m.diveId == null), isTrue);
      expect(result.failures, isEmpty);
      expect(createdIds, hasLength(2));
      verifyNever(
        mockEnrichmentService.calculateEnrichment(
          profile: anyNamed('profile'),
          diveStartTime: anyNamed('diveStartTime'),
          photoTime: anyNamed('photoTime'),
        ),
      );
    },
  );

  test('importPhotosForSite skips assets already linked to the site', () async {
    when(
      mockMediaRepository.getGalleryLinksForSite('site-1'),
    ).thenAnswer((_) async => [_siteRow('a1')]);

    final result = await service.importPhotosForSite(
      selectedAssets: [_testAsset('a1'), _testAsset('a2')],
      siteId: 'site-1',
    );

    expect(result.imported, hasLength(1));
    expect(result.skippedDuplicates, 1);
  });

  test('importPhotosForSite skips an asset that a row linked on another '
      'device resolves to on this one (#885)', () async {
    final crossDevice = MediaImportService(
      mediaRepository: mockMediaRepository,
      enrichmentService: mockEnrichmentService,
      linkedGalleryAssets: LinkedGalleryAssets(
        resolve: (item) async => item.platformAssetId == 'iphone-1'
            ? const ResolutionResult(
                localAssetId: 'mac-1',
                status: ResolutionStatus.resolved,
              )
            : const ResolutionResult(status: ResolutionStatus.unavailable),
      ),
    );
    when(
      mockMediaRepository.getGalleryLinksForSite('site-1'),
    ).thenAnswer((_) async => [_siteRow('iphone-1')]);

    final result = await crossDevice.importPhotosForSite(
      selectedAssets: [_testAsset('mac-1')],
      siteId: 'site-1',
    );

    expect(result.imported, isEmpty);
    expect(result.skippedDuplicates, 1);
    verifyNever(mockMediaRepository.createMedia(any));
  });

  test(
    'desktop picks with a path become localFile rows deduped by path',
    () async {
      when(
        mockMediaRepository.getLinkedLocalPathsForSite('site-1'),
      ).thenAnswer((_) async => {'/tmp/dup.jpg'});

      final result = await service.importPhotosForSite(
        selectedAssets: [
          _testAsset('d1', filePath: '/tmp/new.jpg'),
          _testAsset('d2', filePath: '/tmp/dup.jpg'),
        ],
        siteId: 'site-1',
      );

      expect(result.imported, hasLength(1));
      expect(result.imported.single.localPath, '/tmp/new.jpg');
      expect(result.imported.single.platformAssetId, isNull);
      expect(result.skippedDuplicates, 1);
    },
  );
}
