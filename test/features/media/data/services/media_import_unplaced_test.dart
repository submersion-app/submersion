import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

AssetInfo _asset(String id) => AssetInfo(
  id: id,
  type: AssetType.video,
  createDateTime: DateTime(2024, 1, 15, 10, 30),
  width: 3840,
  height: 2160,
);

/// Media kept in the library with no dive, site or gear (issue #5122).
void main() {
  late MediaRepository repo;
  late MediaImportService service;

  setUp(() async {
    await setUpTestDatabase();
    repo = MediaRepository();
    service = MediaImportService(
      mediaRepository: repo,
      enrichmentService: const EnrichmentService(),
    );
  });
  tearDown(tearDownTestDatabase);

  test('keeps the picks with no dive, site or gear, retained', () async {
    final result = await service.importPhotosUnplaced(
      selectedAssets: [_asset('gopro-1'), _asset('gopro-2')],
    );

    expect(result.imported, hasLength(2));
    expect(result.failures, isEmpty);
    for (final item in result.imported) {
      final row = await repo.getMediaById(item.id);
      expect(row!.diveId, isNull);
      expect(row.siteId, isNull);
      expect(row.equipmentId, isNull);
      expect(row.retainInLibrary, isTrue);
    }
  });

  test('skips a pick already kept with no place', () async {
    await service.importPhotosUnplaced(selectedAssets: [_asset('gopro-1')]);

    final again = await service.importPhotosUnplaced(
      selectedAssets: [_asset('gopro-1'), _asset('gopro-2')],
    );

    expect(again.imported.map((m) => m.platformAssetId), ['gopro-2']);
  });

  test('a stray unlinked row is not a keep: the pick is still kept', () async {
    // A row with no links and no retain flag, which the sweep has not
    // reached yet.
    await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.video,
        platformAssetId: 'gopro-1',
        takenAt: DateTime.utc(2024),
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
    );

    final result = await service.importPhotosUnplaced(
      selectedAssets: [_asset('gopro-1')],
    );

    expect(result.imported, hasLength(1));
    expect(result.imported.single.retainInLibrary, isTrue);
  });
}
