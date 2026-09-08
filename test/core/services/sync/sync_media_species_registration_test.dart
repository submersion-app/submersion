import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../features/media/data/repositories/species_photo_fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestMedia(id: 'p1', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'a tag written through the repository is fetchable by sync type',
    () async {
      final tag = await MediaSpeciesRepository().addTag(
        mediaId: 'p1',
        speciesId: 'c1',
      );

      final record = await serializer.fetchRecord('mediaSpecies', tag.id);

      expect(record, isNotNull);
      expect(record!['mediaId'], 'p1');
      expect(record['speciesId'], 'c1');
    },
  );

  test('upsertRecord and deleteRecord round-trip a remote tag', () async {
    await serializer.upsertRecord('mediaSpecies', {
      'id': 'mst-remote',
      'mediaId': 'p1',
      'speciesId': 'c1',
      'createdAt': 1000,
    });
    expect(
      await serializer.fetchRecord('mediaSpecies', 'mst-remote'),
      isNotNull,
    );

    await serializer.deleteRecord('mediaSpecies', 'mst-remote');

    expect(await serializer.fetchRecord('mediaSpecies', 'mst-remote'), isNull);
  });

  test('SyncData carries mediaSpecies through toJson and fromJson', () {
    const data = SyncData(
      mediaSpecies: [
        {'id': 'mst-1', 'mediaId': 'p1', 'speciesId': 'c1', 'createdAt': 1},
      ],
    );

    final restored = SyncData.fromJson(data.toJson());

    expect(restored.mediaSpecies.single['id'], 'mst-1');
  });

  test('mediaSpecies merges as a clockless child of media and species', () {
    expect(SyncService.entityHasUpdatedAt['mediaSpecies'], isFalse);
    final refs = SyncService.parentRefs['mediaSpecies']!;
    expect(refs.map((r) => (r.field, r.parent, r.nullable)).toSet(), {
      ('mediaId', 'media', false),
      ('speciesId', 'species', false),
    });
  });

  Future<String?> hlcOf(String table, String id) async {
    final row = await db
        .customSelect(
          'SELECT hlc FROM "$table" WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row?.read<String?>('hlc');
  }

  test('a tag written through the repository is stamped with an hlc', () async {
    final tag = await MediaSpeciesRepository().addTag(
      mediaId: 'p1',
      speciesId: 'c1',
    );

    // A null hlc is invisible to the incremental export forever: the filter
    // is `hlc > watermark` and SQL `NULL > x` is not true. Writing through
    // the repository is the only way to catch it -- the remote apply path
    // carries the peer's hlc in the payload and would mask the gap.
    expect(await hlcOf('media_species', tag.id), isNotNull);
  });

  test(
    'an incremental changeset carries a tag on an untouched photo',
    () async {
      // The photo was published on an earlier sync and tagging does not edit
      // it, so its own clock never advances past the watermark (issue #1638).
      await SyncRepository().markRecordPending(
        entityType: 'media',
        recordId: 'p1',
        localUpdatedAt: 1000,
      );
      final watermark = await hlcOf('media', 'p1');
      expect(watermark, isNotNull);

      final tag = await MediaSpeciesRepository().addTag(
        mediaId: 'p1',
        speciesId: 'c1',
      );
      final payload = await serializer.exportChangeset(
        deviceId: 'device-1',
        hlcWatermark: watermark,
        deletions: const [],
      );

      expect(
        payload.data.mediaSpecies.map((r) => r['id']),
        contains(tag.id),
        reason: 'the tag is newer than the watermark and must publish',
      );
    },
  );
}
