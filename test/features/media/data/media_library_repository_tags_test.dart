import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../helpers/test_database.dart';

/// The library's tag facet (issue #1970): any of the selected tags, ANDed
/// with the other facets, each photo once.
void main() {
  late AppDatabase db;
  final repo = MediaLibraryRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, taken_at, created_at, '
      "updated_at) VALUES ('wreck-photo', 'a', 'photo', 3, 1, 1), "
      "('fish-video', 'b', 'video', 2, 1, 1), "
      "('both-photo', 'c', 'photo', 1, 1, 1), "
      "('plain-photo', 'd', 'photo', 0, 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, applies_to_media) '
      "VALUES ('wreck', 'Wreck', 0, 0, 1), ('fish', 'Fish', 0, 0, 1)",
    );
    final links = TagLinkRepository(TagScope.media);
    await links.replaceTags('wreck-photo', ['wreck']);
    await links.replaceTags('fish-video', ['fish']);
    await links.replaceTags('both-photo', ['wreck', 'fish']);
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> ids(MediaLibraryFilter filter) async => [
    for (final e in (await repo.getPage(diverId: null, filter: filter)).entries)
      e.item.id,
  ];

  test('one tag selects the media carrying it', () async {
    expect(await ids(const MediaLibraryFilter(tagIds: {'wreck'})), [
      'wreck-photo',
      'both-photo',
    ]);
  });

  test('several tags match any of them, each photo once', () async {
    expect(await ids(const MediaLibraryFilter(tagIds: {'wreck', 'fish'})), [
      'wreck-photo',
      'fish-video',
      'both-photo',
    ]);
    expect(
      await repo.countInScope(
        diverId: null,
        filter: const MediaLibraryFilter(tagIds: {'wreck', 'fish'}),
      ),
      3,
    );
  });

  test('the tag facet ANDs with the others', () async {
    expect(
      await ids(
        const MediaLibraryFilter(tagIds: {'fish'}, mediaType: MediaType.photo),
      ),
      ['both-photo'],
    );
  });

  test('no tags selected leaves the library unfiltered', () async {
    expect(await ids(MediaLibraryFilter.none), hasLength(4));
  });

  test('a tag that no longer exists is ignored, not matched', () async {
    // With a live tag beside it, only the live tag filters.
    expect(await ids(const MediaLibraryFilter(tagIds: {'gone', 'fish'})), [
      'fish-video',
      'both-photo',
    ]);
    // Alone, it leaves the library unfiltered rather than empty.
    expect(await ids(const MediaLibraryFilter(tagIds: {'gone'})), hasLength(4));
  });
}
