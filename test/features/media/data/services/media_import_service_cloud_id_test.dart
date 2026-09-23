import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/data/services/cloud_identifier_source.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/fake_photo_picker_service.dart';
import 'media_import_service_test.mocks.dart';

final _taken = DateTime(2026, 7, 1, 10, 30);

FakeGalleryAsset _asset(String id, {String? cloudId}) => FakeGalleryAsset(
  id: id,
  bytes: Uint8List.fromList([1, 2, 3]),
  takenAt: _taken,
  cloudId: cloudId,
);

void main() {
  late MockMediaRepository repo;
  late FakePhotoPickerService library;

  setUp(() {
    repo = MockMediaRepository();
    library = FakePhotoPickerService(
      assets: [
        _asset('a1', cloudId: 'C-1'),
        _asset('a2'),
      ],
    );
    when(
      repo.getGalleryLinksForSite(any),
    ).thenAnswer((_) async => <MediaItem>[]);
    when(
      repo.getLinkedLocalPathsForSite(any),
    ).thenAnswer((_) async => <String>{});
    when(repo.createMedia(any)).thenAnswer((invocation) async {
      final item = invocation.positionalArguments.first as MediaItem;
      return item.copyWith(id: 'saved-${item.platformAssetId}');
    });
  });

  MediaImportService service({CloudIdentifierSource? cloudIdentifiers}) =>
      MediaImportService(
        mediaRepository: repo,
        enrichmentService: MockEnrichmentService(),
        cloudIdentifiers: cloudIdentifiers,
      );

  test('a gallery link records its cloud id, in one lookup', () async {
    final result = await service(cloudIdentifiers: library).importPhotosForSite(
      selectedAssets: [_asset('a1').info, _asset('a2').info],
      siteId: 'site-1',
    );

    final byAsset = {for (final m in result.imported) m.platformAssetId: m};
    expect(byAsset['a1']!.cloudAssetId, 'C-1');
    expect(byAsset['a2']!.cloudAssetId, isNull, reason: 'no iCloud copy');
    expect(library.cloudIdCalls, 1);
  });

  // The cloud id is a hint for other devices; a lookup that fails must not
  // cost the user the import.
  test('a failed lookup still links, with no cloud id', () async {
    library.cloudIdError = StateError('channel');

    final result = await service(cloudIdentifiers: library).importPhotosForSite(
      selectedAssets: [_asset('a1').info],
      siteId: 'site-1',
    );

    expect(result.imported, hasLength(1));
    expect(result.imported.single.cloudAssetId, isNull);
  });

  test('a desktop file pick is never looked up', () async {
    await service(cloudIdentifiers: library).importPhotosForSite(
      selectedAssets: [
        AssetInfo(
          id: 'f1',
          type: AssetType.image,
          createDateTime: _taken,
          width: 10,
          height: 10,
          filePath: 'photo.jpg',
        ),
      ],
      siteId: 'site-1',
    );

    expect(library.cloudIdCalls, 0);
  });
}
