import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_smart_album_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

/// A tag merge carries saved smart albums with it (issue #1970): an album
/// filtered by a merged tag follows it to the survivor.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('albums naming a merged tag name the survivor', () async {
    final tags = TagRepository();
    final albums = MediaSmartAlbumRepository();
    final survivor = await tags.getOrCreateTag('Wreck', scope: TagScope.media);
    final source = await tags.getOrCreateTag('Wrecks', scope: TagScope.media);
    final other = await tags.getOrCreateTag('Fish', scope: TagScope.media);
    await albums.create(
      name: 'Wrecks',
      filter: MediaLibraryFilter(tagIds: {source.id, other.id}),
    );
    await albums.create(
      name: 'Fish',
      filter: MediaLibraryFilter(tagIds: {other.id}),
    );

    await tags.mergeTags(
      sourceTagIds: [source.id],
      survivingTagId: survivor.id,
      name: 'Wreck',
      colorHex: null,
    );

    final byName = {for (final a in await albums.getAll()) a.name: a};
    expect(byName['Wrecks']!.filter.tagIds, {survivor.id, other.id});
    expect(byName['Fish']!.filter.tagIds, {other.id});
  });
}
