import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import 'media_import_service_test.mocks.dart';

/// The gear item's photos already linked, as the import dedupe reads them.
class _FakeGearPhotos implements GearPhotoRepository {
  _FakeGearPhotos(this.linked);

  final List<MediaItem> linked;

  @override
  Future<List<MediaItem>> galleryLinksFor(String equipmentId) async => linked;

  /// One local file on the item, row 'm-label', unless ignored.
  @override
  Future<Set<String>> linkedLocalPathsFor(
    String equipmentId, {
    Set<String> ignoring = const {},
  }) async => {if (!ignoring.contains('m-label')) '/label.jpg'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AssetInfo _asset(String id) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2024, 1, 15, 10, 30),
  width: 1920,
  height: 1080,
);

MediaItem _gearRow(String platformAssetId) => MediaItem(
  id: 'media-$platformAssetId',
  equipmentId: 'g1',
  platformAssetId: platformAssetId,
  mediaType: MediaType.photo,
  takenAt: DateTime.utc(2024, 1, 15, 10, 30),
  createdAt: DateTime.utc(2024, 1, 15),
  updatedAt: DateTime.utc(2024, 1, 15),
);

/// What a gear item's sitting would write for a pick of photos (issue
/// #4527, phase 3, plan 6), held until Save.
void main() {
  late MockMediaRepository media;

  MediaImportService service(List<MediaItem> linked) => MediaImportService(
    mediaRepository: media,
    enrichmentService: MockEnrichmentService(),
    gearPhotos: _FakeGearPhotos(linked),
  );

  setUp(() => media = MockMediaRepository());

  test(
    'prepareForEquipment writes nothing and skips photos already linked',
    () async {
      final prepared = await service([_gearRow('a1')]).prepareForEquipment(
        selectedAssets: [_asset('a1'), _asset('a2')],
        equipmentId: 'g1',
      );

      expect(prepared, hasLength(1));
      final item = prepared.single.item;
      expect(item.platformAssetId, 'a2');
      expect(item.equipmentId, 'g1');
      expect(item.observationId, isNull);
      expect(item.id, isNotEmpty);
      expect(prepared.single.enrichment, isNull);
      verifyNever(media.createMedia(any));
    },
  );

  // Issue #4527, plan 6: a file the sitting unlinked may be picked again,
  // as a gallery photo may.
  test('a local file the sitting unlinked can be picked again', () async {
    final file = AssetInfo(
      id: 'f1',
      type: AssetType.image,
      createDateTime: DateTime(2024, 1, 15, 10, 30),
      width: 1920,
      height: 1080,
      filePath: '/label.jpg',
    );

    final kept = await service(
      const [],
    ).prepareForEquipment(selectedAssets: [file], equipmentId: 'g1');
    final again = await service(const []).prepareForEquipment(
      selectedAssets: [file],
      equipmentId: 'g1',
      ignoringMediaIds: {'m-label'},
    );

    expect(kept, isEmpty);
    expect(again, hasLength(1));
  });

  test('a check-in\'s photo names it', () async {
    final prepared = await service(const []).prepareForEquipment(
      selectedAssets: [_asset('a1')],
      equipmentId: 'g1',
      observationId: 'o1',
    );

    expect(prepared.single.item.observationId, 'o1');
  });

  test('a photo the sitting unlinked can be picked again', () async {
    final prepared = await service([_gearRow('a1')]).prepareForEquipment(
      selectedAssets: [_asset('a1')],
      equipmentId: 'g1',
      ignoringMediaIds: {'media-a1'},
    );

    expect(prepared.single.item.platformAssetId, 'a1');
  });
}
