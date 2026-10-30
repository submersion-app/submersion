import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

import '../../../../helpers/test_database.dart';

/// Deleting a photo or video tombstones its tag links (issue #1970). The FK
/// cascade would remove them too, but writes no tombstone, so a peer would
/// keep links to a photo that no longer exists.
void main() {
  late AppDatabase db;
  final links = TagLinkRepository(domain.TagScope.media);

  Future<int> tombstones() async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM deletion_log '
                "WHERE entity_type = 'mediaTags'",
              )
              .getSingle())
          .read<int>('n');

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
      "VALUES ('m1', '', 'photo', 1, 1), ('m2', '', 'photo', 1, 1), "
      "('m3', '', 'photo', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, applies_to_media) '
      "VALUES ('wreck', 'Wreck', 0, 0, 1), ('fish', 'Fish', 0, 0, 1)",
    );
    await links.addTags(['m1', 'm2', 'm3'], ['wreck', 'fish']);
  });
  tearDown(tearDownTestDatabase);

  test('deleteMedia tombstones the item\'s links', () async {
    await MediaRepository().deleteMedia('m1');

    expect(await links.getTagIdsByItem(['m1']), isEmpty);
    expect(await tombstones(), 2);
  });

  test(
    'deleteMultipleMedia tombstones only the deleted items\' links',
    () async {
      await MediaRepository().deleteMultipleMedia([
        'm1',
        'm2',
      ], keepIf: (row) => row.id == 'm2');

      expect(await links.getTagIdsByItem(['m1']), isEmpty);
      expect((await links.getTagIdsByItem(['m2']))['m2'], hasLength(2));
      expect(await tombstones(), 2);
    },
  );
}
