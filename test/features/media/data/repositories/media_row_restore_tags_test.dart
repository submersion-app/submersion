import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_restore.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

import '../../../../helpers/test_database.dart';

/// An undone delete puts media back with their tags (issue #1970).
void main() {
  late AppDatabase db;
  final links = TagLinkRepository(domain.TagScope.media);

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
      "VALUES ('m1', 'a', 'photo', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, applies_to_media) '
      "VALUES ('wreck', 'Wreck', 0, 0, 1), ('fish', 'Fish', 0, 0, 1)",
    );
    await links.addTags(['m1'], ['wreck', 'fish']);
  });
  tearDown(tearDownTestDatabase);

  test('restored media carry their tags, less a tag deleted since', () async {
    final snapshot = await readMediaRows(db, ['m1']);
    expect(snapshot.tags, hasLength(2));
    await MediaRepository().deleteMultipleMedia(['m1']);
    await db.customStatement("DELETE FROM tags WHERE id = 'fish'");

    await restoreMediaRows(db, SyncRepository(), snapshot, now: 10);

    expect((await links.getTagIdsByItem(['m1']))['m1'], ['wreck']);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'mediaTags'",
        )
        .get();
    expect(
      tombstones.map((r) => r.read<String>('record_id')),
      isNot(contains(snapshot.tags.firstWhere((t) => t.tagId == 'wreck').id)),
      reason: 'the restored link must not still carry its tombstone',
    );
  });
}
