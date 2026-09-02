import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// The Transfers page names every queued row through this one projection
/// instead of hydrating a full MediaItem (imageData BLOB included) per row.
void main() {
  late MediaRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<String> insert({String? originalFilename, String? caption}) async {
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: '/tmp/x.jpg',
        localPath: '/tmp/x.jpg',
        originalFilename: originalFilename,
        caption: caption,
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    return created.id;
  }

  test('prefers the file name, falls back to the caption, and omits rows '
      'with neither', () async {
    final named = await insert(originalFilename: 'IMG_0042.HEIC');
    final captioned = await insert(originalFilename: '', caption: 'Turtle');
    final bare = await insert();

    final labels = await repo.getDisplayLabels([
      named,
      captioned,
      bare,
      'no-such-row',
    ]);

    expect(labels, {named: 'IMG_0042.HEIC', captioned: 'Turtle'});
  });

  test('an empty id list makes no query and returns no labels', () async {
    expect(await repo.getDisplayLabels(const []), isEmpty);
  });

  // The queue can hold thousands of rows during a library backfill, well
  // past SQLite's bound-parameter limit, so the lookup has to chunk.
  test('finds ids on both sides of a chunk boundary', () async {
    final first = await insert(originalFilename: 'first.jpg');
    final last = await insert(originalFilename: 'last.jpg');
    final ids = [first, ...List.generate(1500, (i) => 'missing-$i'), last];

    final labels = await repo.getDisplayLabels(ids);

    expect(labels, {first: 'first.jpg', last: 'last.jpg'});
  });
}
