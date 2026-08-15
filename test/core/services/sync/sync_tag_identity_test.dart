import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    as tag_domain;

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Cross-device tag identity (issue #1032).
///
/// After a second device pulled the shared library, dives showed the same
/// auto-generated import tag several times: each device had minted its own
/// uuid for a tag of the same name, and the merge upserted by primary key
/// only, so the peer's row landed beside the local one instead of merging
/// with it. Both devices must converge on ONE tag row and ONE junction row.
void main() {
  group('tag identity across devices', () {
    late FakeCloudStorageProvider cloud;

    const importTag = 'Perdix Import 2026-08-13';

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
    });

    tearDown(tearDownTestDatabase);

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );

    Future<void> createDive(String id) => DiveRepository().createDive(
      domain.Dive(id: id, dateTime: DateTime(2026, 8, 13)),
    );

    Future<void> createTaggedDive(
      String diveId,
      String tagId, {
      String name = importTag,
    }) async {
      await createDive(diveId);
      await TagRepository().createTag(
        tag_domain.Tag(
          id: tagId,
          name: name,
          createdAt: DateTime(2026, 8, 13),
          updatedAt: DateTime(2026, 8, 13),
        ),
      );
      await TagRepository().addTagToDive(diveId, tagId);
    }

    Future<List<String>> tagIds() async {
      final db = DatabaseService.instance.database;
      final rows = await db
          .customSelect('SELECT id FROM tags ORDER BY id')
          .get();
      return rows.map((r) => r.read<String>('id')).toList();
    }

    Future<List<String>> junctionPairs() async {
      final db = DatabaseService.instance.database;
      final rows = await db
          .customSelect(
            'SELECT dive_id, tag_id FROM dive_tags '
            'ORDER BY dive_id, tag_id',
          )
          .get();
      return rows
          .map(
            (r) => '${r.read<String>('dive_id')}|${r.read<String>('tag_id')}',
          )
          .toList();
    }

    test('a peer tag that sorts lower absorbs the local one', () async {
      // Peer device: same dive, its own uuid for the import tag.
      await createTaggedDive('dive-1', 'tag-aaa');
      await seedPeerLog(cloud, 'device-a');

      // This device: the same dive and the same tag NAME, own uuid.
      await createTaggedDive('dive-1', 'tag-zzz');

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      expect(await tagIds(), ['tag-aaa']);
      expect(await junctionPairs(), ['dive-1|tag-aaa']);
      expect(
        (await TagRepository().getTagsForDive('dive-1')).length,
        1,
        reason: 'the dive must show the import tag exactly once',
      );
    });

    test('a peer tag that sorts higher folds into the local one', () async {
      // Peer device: its uuid sorts ABOVE ours, and it tags a dive we have
      // never seen -- that dive's junction must still land on our tag.
      await createTaggedDive('dive-2', 'tag-zzz');
      await seedPeerLog(cloud, 'device-a');

      await createTaggedDive('dive-1', 'tag-aaa');

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      expect(await tagIds(), ['tag-aaa']);
      expect(await junctionPairs(), ['dive-1|tag-aaa', 'dive-2|tag-aaa']);
      expect((await TagRepository().getTagsForDive('dive-2')).length, 1);
    });

    test('a padded local name still folds with a peer’s bare one', () async {
      // The comparison used to trim only the INCOMING name, so convergence
      // depended on which device happened to hold the padded spelling. Rows
      // predating v149 (and legacy peers) can carry one, so the local side is
      // inserted raw here rather than through the now-trimming repository.
      await createTaggedDive('dive-1', 'tag-aaa');
      await seedPeerLog(cloud, 'device-a');

      final db = DatabaseService.instance.database;
      await createDive('dive-9');
      final now = DateTime(2026, 8, 13).millisecondsSinceEpoch;
      await db
          .into(db.tags)
          .insert(
            TagsCompanion(
              id: const Value('tag-zzz'),
              name: const Value('  $importTag  '),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await TagRepository().addTagToDive('dive-9', 'tag-zzz');

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      expect(await tagIds(), [
        'tag-aaa',
      ], reason: 'whitespace is not what makes two tags different');
      expect((await TagRepository().getTagsForDive('dive-9')).length, 1);
    });

    test('a peer junction for a pair we already have is a no-op', () async {
      // Same tag id on both sides (the ordinary case) but a different
      // junction uuid: the surrogate key made this a second row.
      await createTaggedDive('dive-1', 'tag-aaa');
      await seedPeerLog(cloud, 'device-a');

      await createTaggedDive('dive-1', 'tag-aaa');

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      expect(await junctionPairs(), ['dive-1|tag-aaa']);
    });

    test('a padded name from a peer is stored trimmed', () async {
      // v149 trims every stored name so a row reads back as what lookups
      // compare against. A device predating that change can still publish a
      // padded one, and writing it verbatim would undo the migration on the
      // very first sync (PR #1033 review).
      //
      // The peer's tag row is inserted RAW: createTag trims now, so going
      // through the repository would never put a padded name on the wire and
      // this test would pass against the unfixed code.
      await createDive('dive-1');
      final now = DateTime(2026, 8, 13).millisecondsSinceEpoch;
      await DatabaseService.instance.database
          .into(DatabaseService.instance.database.tags)
          .insert(
            TagsCompanion(
              id: const Value('tag-aaa'),
              name: const Value('  $importTag  '),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await TagRepository().addTagToDive('dive-1', 'tag-aaa');
      // Publishes the above as a peer AND resets this device's database.
      await seedPeerLog(cloud, 'device-a');

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final db = DatabaseService.instance.database;
      final rows = await db.select(db.tags).get();
      expect(rows, hasLength(1));
      expect(
        rows.single.name,
        importTag,
        reason:
            'the stored value must match the normalization the index and '
            'every lookup key on',
      );
    });

    test('an ordinary peer tag still replicates untouched', () async {
      await createTaggedDive('dive-1', 'tag-aaa', name: 'Wreck');
      await seedPeerLog(cloud, 'device-a');

      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      expect(await tagIds(), ['tag-aaa']);
      expect(await junctionPairs(), ['dive-1|tag-aaa']);
    });
  });
}
