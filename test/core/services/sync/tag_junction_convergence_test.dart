import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    as tag_domain;

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Two-device convergence of the tag and type junctions (issue #2003).
///
/// `dive_tags`, `dive_dive_types`, `site_site_types` and `site_tags` carry a
/// surrogate uuid primary key (#347), so each device mints its own id for a
/// pair it adds. A peer's copy of a pair this device already holds used to be
/// dropped with DO NOTHING, which forgot the peer's id -- and `deleteRecord`
/// removes a junction row BY ID, so a delete on one device matched nothing on
/// the other and the link came back.
///
/// Separately, `_applyTagRecord` wrote a peer's scope flags in without
/// touching the links of a scope switched OFF, so a link the narrowing device
/// never saw outlived the scope that justified it.
///
/// Both devices are real: one in-memory database each, swapped through the
/// DatabaseService singleton, sharing one fake cloud and the real merge.
void main() {
  late FakeCloudStorageProvider cloud;
  late AppDatabase dbA;
  late AppDatabase dbB;

  setUp(() async {
    cloud = FakeCloudStorageProvider();
    dbA = createTestDatabase();
    dbB = createTestDatabase();
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    await dbA.close();
    await dbB.close();
  });

  /// Makes [db] the device the next calls run against.
  void on(AppDatabase db) => DatabaseService.instance.setTestDatabase(db);

  Future<void> sync() async {
    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(result.status, isNot(SyncResultStatus.error));
  }

  /// Every `<table>` row as "<parent>|<child>", on the device now installed.
  Future<List<String>> pairsIn(
    String table,
    String parentColumn,
    String childColumn,
  ) async {
    final rows = await DatabaseService.instance.database
        .customSelect(
          'SELECT $parentColumn AS p, $childColumn AS c FROM $table '
          'ORDER BY p, c',
        )
        .get();
    return [
      for (final row in rows)
        '${row.read<String>('p')}|${row.read<String>('c')}',
    ];
  }

  Future<List<String>> idsIn(String table) async {
    final rows = await DatabaseService.instance.database
        .customSelect('SELECT id FROM $table ORDER BY id')
        .get();
    return [for (final row in rows) row.read<String>('id')];
  }

  tag_domain.Tag wreck({
    Set<tag_domain.TagScope> scopes = const {
      tag_domain.TagScope.dives,
      tag_domain.TagScope.sites,
    },
  }) => tag_domain.Tag(
    id: 'tag-1',
    name: 'Wreck',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
    scopes: scopes,
  );

  Future<void> createSite(String id) async {
    await SyncDataSerializer().upsertRecord('diveSites', {
      'id': id,
      'name': 'Manta Point',
      'description': '',
      'notes': '',
      'isShared': false,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
  }

  /// Device A seeds the shared library and device B adopts it, so both sides
  /// start from the same dive, site and tag under the same ids.
  Future<void> seedSharedLibrary() async {
    on(dbA);
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await createSite('s1');
    await TagRepository().createTag(wreck());
    await sync();

    on(dbB);
    await sync();
  }

  group('a pair minted on both devices (issue #2003, part 1)', () {
    test(
      'both devices settle on one id for a pair each of them minted',
      () async {
        await seedSharedLibrary();

        on(dbA);
        await TagRepository().addTagToDive('d1', 'tag-1');
        on(dbB);
        await TagRepository().addTagToDive('d1', 'tag-1');

        on(dbA);
        await sync();
        on(dbB);
        await sync();
        on(dbA);
        await sync();

        final idsOnA = await idsIn('dive_tags');
        expect(idsOnA, hasLength(1));
        on(dbB);
        expect(
          await idsIn('dive_tags'),
          idsOnA,
          reason:
              'the surviving id has to be a property of the rows, not of the '
              'device, or a tombstone naming one of them misses the other',
        );
      },
    );

    test('a batch carrying two ids for one pair keeps the lower', () async {
      // One payload CAN hold two links that mean the same pair: a peer's rows
      // for two same-name tags both rewrite to the surviving tag id through
      // _withTagAlias. Resolving those by arrival order would leave a device
      // with no local copy on a different survivor from one that had a rival
      // row, and nothing republishes to heal it (PR #2004 review).
      //
      // The ids arrive HIGH first, so first-row-wins is not the answer.
      on(dbA);
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await TagRepository().createTag(wreck());

      await SyncDataSerializer().upsertRecords('diveTags', [
        {'id': 'zzz', 'diveId': 'd1', 'tagId': 'tag-1', 'createdAt': 2},
        {'id': 'aaa', 'diveId': 'd1', 'tagId': 'tag-1', 'createdAt': 1},
      ]);

      expect(
        await idsIn('dive_tags'),
        ['aaa'],
        reason:
            'the survivor must be the lowest id, the same answer a device '
            'holding one of them already would reach',
      );
    });

    test('a dive tag deleted on one device is gone on the other', () async {
      await seedSharedLibrary();

      // Offline on both: the same tag on the same dive, each device minting
      // its own junction uuid.
      on(dbA);
      await TagRepository().addTagToDive('d1', 'tag-1');
      on(dbB);
      await TagRepository().addTagToDive('d1', 'tag-1');

      // They exchange the two rows and must settle on ONE id.
      on(dbA);
      await sync();
      on(dbB);
      await sync();
      on(dbA);
      await sync();

      // A removes the tag and publishes the tombstone.
      on(dbA);
      await TagRepository().removeTagFromDive('d1', 'tag-1');
      await sync();

      on(dbB);
      await sync();
      expect(
        await pairsIn('dive_tags', 'dive_id', 'tag_id'),
        isEmpty,
        reason: "device B must honour device A's delete of the pair",
      );

      // ...and the link must not come back on A from B's copy.
      on(dbA);
      await sync();
      expect(await pairsIn('dive_tags', 'dive_id', 'tag_id'), isEmpty);
    });

    test('a site tag deleted on one device is gone on the other', () async {
      await seedSharedLibrary();

      on(dbA);
      await SiteClassificationRepository().addTags('s1', ['tag-1']);
      on(dbB);
      await SiteClassificationRepository().addTags('s1', ['tag-1']);

      on(dbA);
      await sync();
      on(dbB);
      await sync();
      on(dbA);
      await sync();

      on(dbA);
      await SiteClassificationRepository().replaceTags('s1', const []);
      await sync();

      on(dbB);
      await sync();
      expect(
        await pairsIn('site_tags', 'site_id', 'tag_id'),
        isEmpty,
        reason: "device B must honour device A's delete of the pair",
      );

      on(dbA);
      await sync();
      expect(await pairsIn('site_tags', 'site_id', 'tag_id'), isEmpty);
    });

    test('a site type deleted on one device is gone on the other', () async {
      await seedSharedLibrary();

      on(dbA);
      await SiteClassificationRepository().addTypes('s1', ['wreck']);
      on(dbB);
      await SiteClassificationRepository().addTypes('s1', ['wreck']);

      on(dbA);
      await sync();
      on(dbB);
      await sync();
      on(dbA);
      await sync();

      on(dbA);
      await SiteClassificationRepository().replaceTypes('s1', const []);
      await sync();

      on(dbB);
      await sync();
      expect(
        await pairsIn('site_site_types', 'site_id', 'site_type_id'),
        isEmpty,
        reason: "device B must honour device A's delete of the pair",
      );
    });

    test('a dive type deleted on one device is gone on the other', () async {
      await seedSharedLibrary();

      on(dbA);
      await DiveRepository().bulkAddDiveTypes(['d1'], ['wreck']);
      on(dbB);
      await DiveRepository().bulkAddDiveTypes(['d1'], ['wreck']);

      on(dbA);
      await sync();
      on(dbB);
      await sync();
      on(dbA);
      await sync();

      on(dbA);
      await DiveRepository().bulkRemoveDiveTypes(['d1'], ['wreck']);
      await sync();

      on(dbB);
      await sync();
      expect(
        await pairsIn('dive_dive_types', 'dive_id', 'dive_type_id'),
        isNot(contains('d1|wreck')),
        reason: "device B must honour device A's delete of the pair",
      );
    });
  });

  group('a scope narrowed remotely (issue #2003, part 2)', () {
    test('drops the site links the narrowing device never saw', () async {
      await seedSharedLibrary();

      // B links the tag to a site and publishes the link.
      on(dbB);
      await SiteClassificationRepository().addTags('s1', ['tag-1']);
      await sync();

      // A narrows the tag to dives only WITHOUT having pulled, so it never
      // sees B's link and has none of its own to unlink.
      on(dbA);
      await TagRepository().updateTag(
        wreck(scopes: const {tag_domain.TagScope.dives}),
      );

      // This sync both publishes the narrowed tag and pulls B's link in.
      await sync();
      expect(
        await pairsIn('site_tags', 'site_id', 'tag_id'),
        isEmpty,
        reason:
            'a link for a scope the tag no longer covers must not apply: links '
            'apply after their parent tag, so nothing else would catch it',
      );

      on(dbB);
      await sync();
      expect(
        await pairsIn('site_tags', 'site_id', 'tag_id'),
        isEmpty,
        reason:
            'applying a tag row whose site scope is off must unlink it from '
            'every site here, link or no link on the narrowing device',
      );

      on(dbA);
      await sync();
      expect(await pairsIn('site_tags', 'site_id', 'tag_id'), isEmpty);
    });

    test('drops the dive links the narrowing device never saw', () async {
      await seedSharedLibrary();

      on(dbB);
      await TagRepository().addTagToDive('d1', 'tag-1');
      await sync();

      on(dbA);
      await TagRepository().updateTag(
        wreck(scopes: const {tag_domain.TagScope.sites}),
      );

      await sync();
      expect(
        await pairsIn('dive_tags', 'dive_id', 'tag_id'),
        isEmpty,
        reason: 'a link for a scope the tag no longer covers must not apply',
      );

      on(dbB);
      await sync();
      expect(
        await pairsIn('dive_tags', 'dive_id', 'tag_id'),
        isEmpty,
        reason:
            'the repair runs through tagScopeTables, so the dive scope is '
            'covered by the same code as the site scope',
      );

      on(dbA);
      await sync();
      expect(await pairsIn('dive_tags', 'dive_id', 'tag_id'), isEmpty);
    });
  });
}
