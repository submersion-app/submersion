import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Coverage for [MediaRepository.getLinkedLocalPathsForDive], the desktop
/// counterpart to `getLinkedAssetIdsForDive`.
///
/// Windows and Linux imports are `localFile` rows whose `platform_asset_id`
/// is deliberately null (carrying the picker's synthetic id would route them
/// through photo_manager, which has no desktop backend), so the asset-id
/// query cannot see them and duplicate detection keys on the path instead.
/// This is hand-written SQL, so a column-name typo would only surface at
/// runtime.
void main() {
  late AppDatabase db;
  late MediaRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(epoch),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem localFile(String path, {required String diveId}) => MediaItem(
    id: '',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    localPath: path,
    originalFilename: path.split('/').last,
    diveId: diveId,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  MediaItem galleryPhoto(String assetId, {required String diveId}) => MediaItem(
    id: '',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: assetId,
    diveId: diveId,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('returns the local paths linked to the dive', () async {
    await insertDive('d1');
    await repo.createMedia(localFile('/photos/a.jpg', diveId: 'd1'));
    await repo.createMedia(localFile('/photos/b.jpg', diveId: 'd1'));

    expect(await repo.getLinkedLocalPathsForDive('d1'), {
      '/photos/a.jpg',
      '/photos/b.jpg',
    });
  });

  test('scopes results to the requested dive', () async {
    await insertDive('d1');
    await insertDive('d2');
    await repo.createMedia(localFile('/photos/a.jpg', diveId: 'd1'));
    await repo.createMedia(localFile('/photos/b.jpg', diveId: 'd2'));

    expect(await repo.getLinkedLocalPathsForDive('d1'), {'/photos/a.jpg'});
  });

  test('omits rows with no local path', () async {
    await insertDive('d1');
    await repo.createMedia(galleryPhoto('asset-1', diveId: 'd1'));
    await repo.createMedia(localFile('/photos/a.jpg', diveId: 'd1'));

    expect(await repo.getLinkedLocalPathsForDive('d1'), {'/photos/a.jpg'});
  });

  test('returns empty for a dive with no media', () async {
    await insertDive('d1');

    expect(await repo.getLinkedLocalPathsForDive('d1'), isEmpty);
  });

  test('collapses duplicate paths into a single entry', () async {
    await insertDive('d1');
    await repo.createMedia(localFile('/photos/a.jpg', diveId: 'd1'));
    await repo.createMedia(localFile('/photos/a.jpg', diveId: 'd1'));

    expect(await repo.getLinkedLocalPathsForDive('d1'), {'/photos/a.jpg'});
  });
}
