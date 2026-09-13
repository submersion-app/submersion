import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Sync of dive site types and the two site classification junctions
/// (issue #1765).
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Site', 0, 0)",
    );
  });

  tearDown(tearDownTestDatabase);

  test('custom site types export; built-ins never do', () async {
    await db.customStatement(
      "INSERT INTO site_types (id, name, is_built_in, sort_order, "
      "created_at, updated_at) VALUES ('mine', 'Mine', 0, 100, 1, 1)",
    );

    final changeset = await serializer.exportData(
      deviceId: 'dev-a',
      deletions: const [],
    );
    final exported = changeset.data.siteTypes.map((r) => r['id']).toList();
    expect(exported, ['mine']);
  });

  test('a site junction row round-trips through fetch and upsert', () async {
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('j1', 's1', 'wreck', 5)",
    );
    final json = await serializer.fetchRecord('siteSiteTypes', 'j1');
    expect(json, isNotNull);
    expect(await serializer.recordIdsFor('siteSiteTypes'), contains('j1'));

    await serializer.deleteRecord('siteSiteTypes', 'j1');
    expect(await serializer.fetchRecord('siteSiteTypes', 'j1'), isNull);
    await serializer.upsertRecord('siteSiteTypes', json!);

    final rows = await db.select(db.siteSiteTypes).get();
    expect(rows.single.siteTypeId, 'wreck');
  });

  test(
    'a duplicate junction pair from a peer applies without throwing',
    () async {
      await db.customStatement(
        "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
        "VALUES ('local', 's1', 'lake', 1)",
      );

      await serializer.upsertRecords('siteSiteTypes', [
        {
          'id': 'peer',
          'siteId': 's1',
          'siteTypeId': 'lake',
          'createdAt': 2,
          'hlc': null,
        },
      ]);
      await serializer.upsertRecord('siteSiteTypes', {
        'id': 'peer2',
        'siteId': 's1',
        'siteTypeId': 'lake',
        'createdAt': 3,
        'hlc': null,
      });

      final rows = await db.select(db.siteSiteTypes).get();
      expect(rows.map((r) => r.id), ['local']);
    },
  );

  test(
    'a site tag row round-trips and dedupes like the dive junction',
    () async {
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at) "
        "VALUES ('t1', 'To try', 1, 1)",
      );
      await serializer.upsertRecords('siteTags', [
        {'id': 'a', 'siteId': 's1', 'tagId': 't1', 'createdAt': 1, 'hlc': null},
        {'id': 'b', 'siteId': 's1', 'tagId': 't1', 'createdAt': 2, 'hlc': null},
      ]);

      final links = await db.select(db.siteTags).get();
      expect(links.map((r) => r.id), ['a']);
      expect(await serializer.fetchRecord('siteTags', 'a'), isNotNull);
    },
  );

  test('site tag rows follow a tag folded into a same-name rival', () async {
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) "
      "VALUES ('aaa', 'To try', 1, 1, 1, 0)",
    );
    // A peer's tag of the same name folds into the local survivor 'aaa'.
    await serializer.upsertRecord('tags', {
      'id': 'zzz',
      'diverId': null,
      'name': 'to try',
      'color': null,
      'createdAt': 2,
      'updatedAt': 2,
      'hlc': null,
      'appliesToDives': false,
      'appliesToSites': true,
    });
    await serializer.upsertRecord('siteTags', {
      'id': 'st1',
      'siteId': 's1',
      'tagId': 'zzz',
      'createdAt': 3,
      'hlc': null,
    });

    final links = await db.select(db.siteTags).get();
    expect(links.single.tagId, 'aaa');
    final tag = await (db.select(
      db.tags,
    )..where((t) => t.id.equals('aaa'))).getSingle();
    expect(tag.appliesToSites, isTrue, reason: 'the fold keeps both scopes');
    expect(tag.appliesToDives, isTrue);
  });

  test(
    'a local site tag on a folded tag is repointed to the survivor',
    () async {
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at, "
        "applies_to_dives, applies_to_sites) "
        "VALUES ('zzz', 'Avoid', 1, 1, 0, 1)",
      );
      await db.customStatement(
        "INSERT INTO site_tags (id, site_id, tag_id, created_at) "
        "VALUES ('st1', 's1', 'zzz', 1)",
      );
      // A peer's same-name tag with a lower id wins the fold. The fold repoints
      // the link before the survivor row is written, so this runs inside the
      // deferred-FK transaction every real merge uses.
      await serializer.applyInDeferredFkTransaction(
        () => serializer.upsertRecord('tags', {
          'id': 'aaa',
          'diverId': null,
          'name': 'avoid',
          'color': null,
          'createdAt': 2,
          'updatedAt': 2,
          'hlc': null,
          'appliesToDives': true,
          'appliesToSites': false,
        }),
      );

      final links = await db.select(db.siteTags).get();
      expect(links.single.tagId, 'aaa');
      final tag = await (db.select(
        db.tags,
      )..where((t) => t.id.equals('aaa'))).getSingle();
      expect(tag.appliesToSites, isTrue);
    },
  );

  group('older peers', () {
    late FakeCloudStorageProvider cloud;

    setUp(() => cloud = FakeCloudStorageProvider());

    SyncPayload payloadOf(SyncData data) {
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString();
      return SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-dev',
        checksum: checksum,
        data: data,
        deletions: const {},
      );
    }

    test(
      'a tag row from an older peer (no scope keys) keeps the local scope',
      () async {
        await db.customStatement(
          "INSERT INTO tags (id, name, created_at, updated_at, "
          "applies_to_dives, applies_to_sites, hlc) "
          "VALUES ('t1', 'To try', 1, 1, 0, 1, "
          "'2026-01-01T00:00:00.000Z-0000-deva')",
        );

        // The peer renamed the tag on a v211 build: its row has no
        // appliesTo* keys and a newer clock, so it wins the merge.
        final olderPeerRow = <String, dynamic>{
          'id': 't1',
          'diverId': null,
          'name': 'To try soon',
          'color': null,
          'createdAt': 1,
          'updatedAt': 9,
          'hlc': '2026-09-01T00:00:00.000Z-0000-devb',
        };
        await seedPeerBaseFromPayload(
          cloud,
          'peer-dev',
          payloadOf(SyncData(tags: [olderPeerRow])),
        );

        final result = await SyncService(
          syncRepository: SyncRepository(),
          serializer: SyncDataSerializer(),
          cloudProvider: cloud,
        ).performSync();
        expect(result.status, isNot(SyncResultStatus.error));

        final tag = await (db.select(
          db.tags,
        )..where((t) => t.id.equals('t1'))).getSingle();
        expect(tag.name, 'To try soon');
        expect(tag.appliesToSites, isTrue);
        expect(tag.appliesToDives, isFalse);
      },
    );
  });
}
