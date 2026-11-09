import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import 'media_import_service_test.mocks.dart';

AssetInfo _asset(String id, {String? filePath}) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2026, 11, 3, 10, 30),
  width: 1920,
  height: 1080,
  filePath: filePath,
);

/// Answers the import dedupe from fixed lists instead of a database.
class _FakeGearPhotos extends GearPhotoRepository {
  _FakeGearPhotos({this.links = const [], this.paths = const {}});

  final List<MediaItem> links;
  final Set<String> paths;

  @override
  Future<List<MediaItem>> galleryLinksFor(String equipmentId) async => links;

  @override
  Future<Set<String>> linkedLocalPathsFor(String equipmentId) async => paths;
}

/// Gear photos (issue #3355) link to an item, and to a check-in when added
/// from one, the way site photos link to a site.
void main() {
  late MockMediaRepository mediaRepository;
  late List<String> created;

  setUp(() {
    mediaRepository = MockMediaRepository();
    created = [];
    when(mediaRepository.createMedia(any)).thenAnswer((invocation) async {
      final item = invocation.positionalArguments.first as MediaItem;
      return item.copyWith(id: 'saved-${item.platformAssetId ?? "path"}');
    });
  });

  MediaImportService service(GearPhotoRepository gearPhotos) =>
      MediaImportService(
        mediaRepository: mediaRepository,
        enrichmentService: MockEnrichmentService(),
        onMediaCreated: created.add,
        gearPhotos: gearPhotos,
      );

  test(
    'importPhotosForEquipment links rows with equipmentId and observationId',
    () async {
      final result = await service(_FakeGearPhotos()).importPhotosForEquipment(
        selectedAssets: [_asset('a1'), _asset('a2')],
        equipmentId: 'reg-1',
        observationId: 'obs-1',
      );

      expect(result.imported, hasLength(2));
      for (final m in result.imported) {
        expect(m.equipmentId, 'reg-1');
        expect(m.observationId, 'obs-1');
        expect(m.diveId, isNull);
        expect(m.siteId, isNull);
      }
      expect(created, hasLength(2));
    },
  );

  test(
    'importPhotosForEquipment skips an asset already linked to the item',
    () async {
      final linked = MediaItem(
        id: 'm1',
        equipmentId: 'reg-1',
        platformAssetId: 'a1',
        mediaType: MediaType.photo,
        takenAt: DateTime.utc(2026),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final result =
          await service(
            _FakeGearPhotos(links: [linked], paths: {'/x/b.jpg'}),
          ).importPhotosForEquipment(
            selectedAssets: [
              _asset('a1'),
              _asset('b', filePath: '/x/b.jpg'),
              _asset('c'),
            ],
            equipmentId: 'reg-1',
          );

      expect(result.imported.map((m) => m.platformAssetId), ['c']);
      expect(result.skippedDuplicates, 2);
      expect(result.imported.single.observationId, isNull);
    },
  );
}
