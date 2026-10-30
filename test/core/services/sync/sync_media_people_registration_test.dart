import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';

import '../../../features/media/data/repositories/species_photo_fixtures.dart';
import '../../../helpers/test_database.dart';

/// People tagged on photos and videos ride sync as `mediaPeople` (v323,
/// issue #1745): an edited child of media and buddies with its own clock.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await insertTestDiver('A');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), diverId: 'A');
    await insertTestBuddy(id: 'alex', name: 'Alex', diverId: 'A');
    await insertTestMedia(id: 'p1', diveId: 'd1');
  });

  tearDown(tearDownTestDatabase);

  test(
    'a tag written through the repository is fetchable by sync type',
    () async {
      final tag = await MediaPeopleRepository().addTag(
        mediaId: 'p1',
        buddyId: 'alex',
        box: const FaceBox(x: 0.1, y: 0.2, width: 0.3, height: 0.3),
      );

      final record = await serializer.fetchRecord('mediaPeople', tag.id);

      expect(record, isNotNull);
      expect(record!['mediaId'], 'p1');
      expect(record['buddyId'], 'alex');
      expect(record['bboxX'], 0.1);
    },
  );

  test('upsertRecord and deleteRecord round-trip a remote tag', () async {
    await serializer.upsertRecord('mediaPeople', {
      'id': 'mp-remote',
      'mediaId': 'p1',
      'diverId': 'A',
      'videoPositionMs': 42000,
      'createdAt': 1000,
      'updatedAt': 2000,
    });
    final record = await serializer.fetchRecord('mediaPeople', 'mp-remote');
    expect(record, isNotNull);
    expect(record!['videoPositionMs'], 42000);

    await serializer.deleteRecord('mediaPeople', 'mp-remote');

    expect(await serializer.fetchRecord('mediaPeople', 'mp-remote'), isNull);
  });

  test('SyncData carries mediaPeople through toJson and fromJson', () {
    const data = SyncData(
      mediaPeople: [
        {
          'id': 'mp-1',
          'mediaId': 'p1',
          'buddyId': 'alex',
          'createdAt': 1,
          'updatedAt': 1,
        },
      ],
    );

    final restored = SyncData.fromJson(data.toJson());

    expect(restored.mediaPeople.single['id'], 'mp-1');
  });

  test(
    'mediaPeople merges on its own clock as a child of media and people',
    () {
      // Like media: the row has updated_at, but it merges as a clock-guarded
      // blind upsert, so a moved box never raises a conflict card.
      expect(SyncService.entityHasUpdatedAt['mediaPeople'], isFalse);
      expect(SyncDataSerializer.clockGuardedEntities, contains('mediaPeople'));
      final refs = SyncService.parentRefs['mediaPeople']!;
      expect(refs.map((r) => (r.field, r.parent, r.nullable)).toSet(), {
        ('mediaId', 'media', false),
        ('buddyId', 'buddies', true),
      });
    },
  );

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
    final tag = await MediaPeopleRepository().addTag(
      mediaId: 'p1',
      buddyId: 'alex',
    );

    expect(await hlcOf('media_people', tag.id), isNotNull);
  });

  test('an edited tag lands in the incremental changeset', () async {
    final tag = await MediaPeopleRepository().addTag(
      mediaId: 'p1',
      buddyId: 'alex',
    );
    final watermark = await hlcOf('media_people', tag.id);
    expect(watermark, isNotNull);

    await MediaPeopleRepository().updateTag(
      tag.copyWith(box: const FaceBox(x: 0.5, y: 0.5, width: 0.1, height: 0.1)),
    );
    final payload = await serializer.exportChangeset(
      deviceId: 'device-1',
      hlcWatermark: watermark,
      deletions: const [],
    );

    expect(
      payload.data.mediaPeople.map((r) => r['id']),
      contains(tag.id),
      reason: 'the edit is newer than the watermark and must publish',
    );
  });
}
