import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late MediaRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = MediaRepository();
  });

  tearDown(tearDownTestDatabase);

  MediaItem galleryRow({String? cloudAssetId}) => MediaItem(
    id: '',
    platformAssetId: 'A-1',
    cloudAssetId: cloudAssetId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    takenAt: DateTime.utc(2026, 7, 1, 10, 30),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  test('a cloud id written at link time reads back', () async {
    final created = await repo.createMedia(galleryRow(cloudAssetId: 'C-1'));
    expect((await repo.getMediaById(created.id))!.cloudAssetId, 'C-1');
  });

  test('a link with no cloud id reads back null', () async {
    final created = await repo.createMedia(galleryRow());
    expect((await repo.getMediaById(created.id))!.cloudAssetId, isNull);
  });

  test('copyWith can set and clear the cloud id', () {
    final row = galleryRow(cloudAssetId: 'C-1');
    expect(row.copyWith(cloudAssetId: 'C-2').cloudAssetId, 'C-2');
    expect(row.copyWith(cloudAssetId: null).cloudAssetId, isNull);
    expect(row.copyWith().cloudAssetId, 'C-1');
  });

  // A snapshot write must not roll back a stamp that landed after the
  // snapshot was read, as for the upload facts.
  test('updateMedia leaves the cloud id alone', () async {
    final created = await repo.createMedia(galleryRow(cloudAssetId: 'C-1'));
    await repo.updateMedia(created.copyWith(cloudAssetId: null, caption: 'x'));
    expect((await repo.getMediaById(created.id))!.cloudAssetId, 'C-1');
  });
}
