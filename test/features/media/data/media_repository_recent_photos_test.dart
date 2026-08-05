import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

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

  MediaItem item(
    String name,
    DateTime takenAt, {
    String? diveId,
    MediaType mediaType = MediaType.photo,
  }) => MediaItem(
    id: '',
    mediaType: mediaType,
    sourceType: MediaSourceType.platformGallery,
    filePath: '/tmp/$name',
    localPath: '/tmp/$name',
    originalFilename: name,
    diveId: diveId,
    takenAt: takenAt,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('returns newest photos first, capped at limit, photos only', () async {
    await insertDive('d1');
    await repo.createMedia(item('jan.jpg', DateTime(2026, 1, 1), diveId: 'd1'));
    await repo.createMedia(item('mar.jpg', DateTime(2026, 3, 1), diveId: 'd1'));
    await repo.createMedia(item('feb.jpg', DateTime(2026, 2, 1), diveId: 'd1'));
    await repo.createMedia(
      item(
        'apr.mov',
        DateTime(2026, 4, 1),
        diveId: 'd1',
        mediaType: MediaType.video,
      ),
    );

    final result = await repo.getRecentPhotos(limit: 2);
    expect(result, hasLength(2));
    // takenAt hydrates as UTC; compare instants, not DateTime objects.
    expect(result[0].takenAt.toLocal(), DateTime(2026, 3, 1));
    expect(result[1].takenAt.toLocal(), DateTime(2026, 2, 1));
    expect(result.every((m) => m.mediaType == MediaType.photo), isTrue);
  });

  test('excludes photos not attached to a dive', () async {
    await insertDive('d1');
    await repo.createMedia(
      item('library.jpg', DateTime(2026, 5, 1)), // newest, but no dive
    );
    await repo.createMedia(
      item('dive.jpg', DateTime(2026, 4, 1), diveId: 'd1'),
    );

    final result = await repo.getRecentPhotos();
    expect(result.map((m) => m.originalFilename), ['dive.jpg']);
  });

  test('empty table returns empty list', () async {
    expect(await repo.getRecentPhotos(), isEmpty);
  });
}
