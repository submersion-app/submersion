import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media/data/repositories/media_smart_album_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Sync of media and document tag links (issue #1970): the `mediaTags` and
/// `documentTags` entities, the twins of `equipmentTags`.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  Future<void> seed(AppDatabase target) async {
    await target.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'Ana', 1, 1)",
    );
    await target.customStatement(
      'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
      "VALUES ('i1', '', 'photo', 1, 1), ('i2', '', 'photo', 1, 1)",
    );
    await target.customStatement(
      'INSERT INTO documents (id, diver_id, type, created_at, updated_at) '
      "VALUES ('i1', 'd1', 'other', 1, 1), ('i2', 'd1', 'other', 1, 1)",
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await seed(db);
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_media, applies_to_documents) "
      "VALUES ('t1', 'Wreck', 1, 1, 0, 1, 1)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<int> pending(String entityType) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM sync_records '
          "WHERE entity_type = '$entityType'",
        )
        .getSingle();
    return row.read<int>('n');
  }

  Future<Tag> tagRow(String id) =>
      (db.select(db.tags)..where((t) => t.id.equals(id))).getSingle();

  for (final scope in const [
    domain.TagScope.media,
    domain.TagScope.documents,
  ]) {
    final entity = scope.table.syncEntity;
    final junction = scope.table.junctionTable;
    final parentColumn = scope.table.parentColumn;
    final parentTable = scope == domain.TagScope.media ? 'media' : 'documents';
    final parentEntity = parentTable;
    final itemKey = scope == domain.TagScope.media ? 'mediaId' : 'documentId';

    Future<void> link(String id, String itemId, String tagId) =>
        db.customStatement(
          'INSERT INTO $junction (id, $parentColumn, tag_id, created_at) '
          "VALUES ('$id', '$itemId', '$tagId', 1)",
        );

    Future<List<(String, String, String)>> links(AppDatabase target) async {
      final rows = await target
          .customSelect(
            'SELECT id, $parentColumn AS item, tag_id FROM $junction '
            'ORDER BY id',
          )
          .get();
      return [
        for (final r in rows)
          (
            r.read<String>('id'),
            r.read<String>('item'),
            r.read<String>('tag_id'),
          ),
      ];
    }

    List<Map<String, dynamic>> rowsOf(SyncData data) =>
        (data.toJson()[entity] as List).cast<Map<String, dynamic>>();

    Map<String, dynamic> peerLink(String id, String tagId) => {
      'id': id,
      itemKey: 'i1',
      'tagId': tagId,
      'createdAt': 2,
      'hlc': null,
    };

    group(entity, () {
      test('a link round-trips through fetch, delete and upsert', () async {
        await link('l1', 'i1', 't1');
        final json = await serializer.fetchRecord(entity, 'l1');
        expect(json, isNotNull);
        expect(await serializer.recordIdsFor(entity), contains('l1'));
        expect((await serializer.fetchRecords(entity, ['l1', 'x'])).keys, [
          'l1',
        ]);

        await serializer.deleteRecord(entity, 'l1');
        expect(await serializer.fetchRecord(entity, 'l1'), isNull);
        await serializer.upsertRecord(entity, json!);

        expect(await links(db), [('l1', 'i1', 't1')]);
      });

      test('links round-trip between two databases', () async {
        await link('l1', 'i1', 't1');
        final payload = await serializer.exportData(
          deviceId: 'dev-a',
          deletions: const [],
        );
        final decoded = SyncData.fromJson(
          jsonDecode(jsonEncode(payload.data.toJson())) as Map<String, dynamic>,
        );
        expect(rowsOf(decoded).map((r) => r['id']), ['l1']);

        addTearDown(db.close);
        final receiver = AppDatabase(
          NativeDatabase.memory(setup: registerAppSqlFunctions),
        );
        DatabaseService.instance.resetForTesting();
        DatabaseService.instance.setTestDatabase(receiver);
        final applier = SyncDataSerializer();
        await applier.applyInDeferredFkTransaction(() async {
          await applier.upsertRecords('divers', decoded.divers);
          await applier.upsertRecords(
            parentEntity,
            (decoded.toJson()[parentEntity] as List)
                .cast<Map<String, dynamic>>(),
          );
          await applier.upsertRecords('tags', decoded.tags);
          await applier.upsertRecords(entity, rowsOf(decoded));
        });

        expect(await links(receiver), [('l1', 'i1', 't1')]);
      });

      test('a duplicate pair from a peer applies without throwing', () async {
        await link('local', 'i1', 't1');

        await serializer.upsertRecords(entity, [peerLink('peer', 't1')]);
        await serializer.upsertRecord(entity, peerLink('peer2', 't1'));

        expect((await links(db)).map((l) => l.$1), ['local']);
      });

      test(
        'a peer copy of a pair settles on the lower id everywhere',
        () async {
          await link('m-local', 'i1', 't1');

          await serializer.upsertRecord(entity, peerLink('a-peer', 't1'));
          expect((await links(db)).map((l) => l.$1), ['a-peer']);

          // The batch path reaches the same survivor.
          await serializer.upsertRecords(entity, [peerLink('0-peer', 't1')]);
          expect((await links(db)).map((l) => l.$1), ['0-peer']);
        },
      );

      test('a link to a tag not offered in the scope is refused', () async {
        await db.customStatement(
          "INSERT INTO tags (id, name, created_at, updated_at) "
          "VALUES ('dive-only', 'Night', 1, 1)",
        );

        await serializer.upsertRecord(entity, peerLink('l1', 'dive-only'));
        await serializer.upsertRecords(entity, [peerLink('l2', 'dive-only')]);

        expect(await links(db), isEmpty);
      });

      test("applying a peer's link never marks the item pending", () async {
        await serializer.upsertRecord(entity, peerLink('l1', 't1'));

        expect(await pending(parentEntity), 0);
        final row = await db
            .customSelect(
              "SELECT hlc, updated_at FROM $parentTable WHERE id = 'i1'",
            )
            .getSingle();
        expect(row.read<String?>('hlc'), isNull);
        expect(row.read<int>('updated_at'), 1);
      });

      test('a pending link travels without its item', () async {
        const itemHlc = '2026-08-01T00:00:00.000Z-0000-peer';
        await db.customStatement(
          "UPDATE $parentTable SET hlc = '$itemHlc' WHERE id = 'i1'",
        );
        await TagLinkRepository(scope).addTags(['i1'], ['t1']);

        final changeset = await serializer.exportChangeset(
          deviceId: 'dev-a',
          hlcWatermark: itemHlc,
          deletions: const [],
        );

        expect(
          changeset.data.toJson()[parentEntity],
          isEmpty,
          reason: 'the item did not change',
        );
        expect(rowsOf(changeset.data).map((r) => r['tagId']), ['t1']);
      });

      test(
        "an incremental changeset carries only changed items' links",
        () async {
          const oldHlc = '2026-07-01T00:00:00.000Z-0000-peer';
          const newHlc = '2026-08-01T00:00:00.000Z-0000-peer';
          await db.customStatement(
            "UPDATE $parentTable SET hlc = '$oldHlc' WHERE id = 'i1'",
          );
          await db.customStatement(
            "UPDATE $parentTable SET hlc = '$newHlc' WHERE id = 'i2'",
          );
          await link('tag-i1', 'i1', 't1');
          await link('tag-i2', 'i2', 't1');

          final changeset = await serializer.exportChangeset(
            deviceId: 'dev-a',
            hlcWatermark: oldHlc,
            deletions: const [],
          );

          expect(rowsOf(changeset.data).map((r) => r['id']), ['tag-i2']);
        },
      );

      test('links follow a tag folded into a same-name rival', () async {
        await db.customStatement(
          "INSERT INTO tags (id, name, created_at, updated_at, "
          "applies_to_dives) VALUES ('aaa', 'Funny', 1, 1, 1)",
        );
        await serializer.upsertRecord('tags', {
          'id': 'zzz',
          'diverId': null,
          'name': 'funny',
          'color': null,
          'createdAt': 2,
          'updatedAt': 2,
          'hlc': null,
          'appliesToDives': false,
          'appliesToSites': false,
          'appliesToEquipment': false,
          'appliesToMedia': scope == domain.TagScope.media,
          'appliesToDocuments': scope == domain.TagScope.documents,
        });
        await serializer.upsertRecord(entity, peerLink('l1', 'zzz'));

        expect((await links(db)).single.$3, 'aaa');
        final tag = await tagRow('aaa');
        expect(
          scope == domain.TagScope.media
              ? tag.appliesToMedia
              : tag.appliesToDocuments,
          isTrue,
          reason: 'the fold keeps every scope',
        );
        expect(tag.appliesToDives, isTrue);
      });
    });
  }

  test('a new tag from an older peer applies with both scopes off', () async {
    await serializer.upsertRecord('tags', {
      'id': 't9',
      'diverId': null,
      'name': 'Night',
      'color': null,
      'createdAt': 1,
      'updatedAt': 1,
      'hlc': null,
      'appliesToDives': true,
      'appliesToSites': false,
      'appliesToEquipment': false,
    });

    final tag = await tagRow('t9');
    expect(tag.appliesToMedia, isFalse);
    expect(tag.appliesToDocuments, isFalse);
    expect(tag.appliesToDives, isTrue);
  });

  test('a tag row from an older peer keeps the local media and document '
      'scopes', () async {
    final cloud = FakeCloudStorageProvider();
    await db.customStatement(
      "UPDATE tags SET hlc = '2026-01-01T00:00:00.000Z-0000-deva' "
      "WHERE id = 't1'",
    );

    // The peer renamed the tag on a v308 build: its row has no media or
    // document flag, and a newer clock, so it wins.
    const data = SyncData(
      tags: [
        <String, dynamic>{
          'id': 't1',
          'diverId': null,
          'name': 'Wrecks',
          'color': null,
          'createdAt': 1,
          'updatedAt': 9,
          'hlc': '2026-09-01T00:00:00.000Z-0000-devb',
          'appliesToDives': false,
          'appliesToSites': false,
          'appliesToEquipment': false,
        },
      ],
    );
    await seedPeerBaseFromPayload(
      cloud,
      'peer-dev',
      SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-dev',
        checksum: sha256
            .convert(utf8.encode(jsonEncode(data.toJson())))
            .toString(),
        data: data,
        deletions: const {},
      ),
    );

    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(result.status, isNot(SyncResultStatus.error));

    final tag = await tagRow('t1');
    expect(tag.name, 'Wrecks');
    expect(tag.appliesToMedia, isTrue);
    expect(tag.appliesToDocuments, isTrue);
  });

  test('a smart album on a folded tag follows it to the survivor', () async {
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, applies_to_media) '
      "VALUES ('zzz', 'Funny', 1, 1, 1)",
    );
    await MediaSmartAlbumRepository().create(
      name: 'Funny',
      filter: const MediaLibraryFilter(tagIds: {'zzz'}),
    );

    // A peer's same-name tag with a lower id wins the fold.
    await serializer.applyInDeferredFkTransaction(
      () => serializer.upsertRecord('tags', {
        'id': 'aaa',
        'diverId': null,
        'name': 'funny',
        'color': null,
        'createdAt': 2,
        'updatedAt': 2,
        'hlc': null,
        'appliesToDives': false,
        'appliesToSites': false,
        'appliesToEquipment': false,
        'appliesToMedia': true,
        'appliesToDocuments': false,
      }),
    );

    final albums = await MediaSmartAlbumRepository().getAll();
    expect(albums.single.filter.tagIds, {'aaa'});
  });
}
