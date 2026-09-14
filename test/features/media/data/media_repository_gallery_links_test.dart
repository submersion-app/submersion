import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Coverage for [MediaRepository.getGalleryLinksForDive] and
/// [MediaRepository.getGalleryLinksForSite], the rows gallery dedupe checks
/// candidates against.
///
/// They run before every gallery import and picker open, so they read only
/// what `LinkedGalleryAssets` and the asset resolver use. A full row would
/// drag in `image_data`, which holds whole signature images.
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

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: const Value('Reef'),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem gallery(
    String assetId, {
    String? diveId,
    String? siteId,
    Uint8List? imageData,
  }) => MediaItem(
    id: '',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: assetId,
    originalFilename: 'IMG_$assetId.HEIC',
    diveId: diveId,
    siteId: siteId,
    takenAt: DateTime.utc(2026, 7, 18, 10, 0, 5),
    width: 4032,
    height: 3024,
    imageData: imageData,
    createdAt: DateTime.utc(2026, 7, 18),
    updatedAt: DateTime.utc(2026, 7, 18),
  );

  test('returns the fields gallery matching reads', () async {
    await insertDive('d1');
    final saved = await repo.createMedia(gallery('iphone-1', diveId: 'd1'));

    final links = await repo.getGalleryLinksForDive('d1');

    expect(links, hasLength(1));
    final link = links.single;
    expect(link.id, saved.id);
    expect(link.diveId, 'd1');
    expect(link.platformAssetId, 'iphone-1');
    expect(link.originalFilename, 'IMG_iphone-1.HEIC');
    expect(link.width, 4032);
    expect(link.height, 3024);
    // Wall-clock-as-UTC, hydrated as UTC like every other media read, or the
    // matcher's two readings of the capture time shift by the host offset.
    expect(link.takenAt, DateTime.utc(2026, 7, 18, 10, 0, 5));
    expect(link.takenAt.isUtc, isTrue);
  });

  test('leaves image data behind', () async {
    await insertDive('d1');
    await repo.createMedia(
      gallery(
        'iphone-1',
        diveId: 'd1',
        imageData: Uint8List.fromList([1, 2, 3]),
      ),
    );

    final link = (await repo.getGalleryLinksForDive('d1')).single;

    expect(link.imageData, isNull);
  });

  test('skips rows with no gallery asset id and other dives', () async {
    await insertDive('d1');
    await insertDive('d2');
    await repo.createMedia(gallery('iphone-1', diveId: 'd1'));
    await repo.createMedia(gallery('iphone-2', diveId: 'd2'));
    await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        localPath: '/photos/a.jpg',
        diveId: 'd1',
        takenAt: DateTime.utc(2026, 7, 18),
        createdAt: DateTime.utc(2026, 7, 18),
        updatedAt: DateTime.utc(2026, 7, 18),
      ),
    );

    final links = await repo.getGalleryLinksForDive('d1');

    expect(links.map((m) => m.platformAssetId), ['iphone-1']);
  });

  test('returns the gallery rows attached to a site', () async {
    await insertSite('s1');
    await insertSite('s2');
    await repo.createMedia(gallery('iphone-1', siteId: 's1'));
    await repo.createMedia(gallery('iphone-2', siteId: 's2'));

    final links = await repo.getGalleryLinksForSite('s1');

    expect(links.map((m) => m.platformAssetId), ['iphone-1']);
    expect(links.single.siteId, 's1');
  });
}
