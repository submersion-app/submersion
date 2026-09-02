import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(
    String id, {
    double? lat,
    double? lng,
    String? siteId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            entryLatitude: Value(lat),
            entryLongitude: Value(lng),
            siteId: Value(siteId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<String> insertSite(String id, {double? lat, double? lng}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            name: Value('Site $id'),
            latitude: Value(lat),
            longitude: Value(lng),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<void> insertPhotoWithGps(String id, String diveId) async {
    final now = DateTime.now();
    await MediaRepository().createMedia(
      MediaItem(
        id: id,
        diveId: diveId,
        filePath: '/photos/$id.jpg',
        mediaType: MediaType.photo,
        latitude: 20.5,
        longitude: -87.25,
        takenAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('setSite assigns and clears a dive site id', () async {
    await insertDive('d1', lat: 1, lng: 2);
    final siteId = await insertSite('s1');

    await repo.setSite('d1', siteId);
    expect((await repo.getDiveById('d1'))!.site?.id, siteId);

    await repo.setSite('d1', null);
    expect((await repo.getDiveById('d1'))!.site, isNull);
  });

  test('getDivesNeedingSiteMatch returns only GPS + unsited dives', () async {
    await insertDive('withGps', lat: 1, lng: 2);
    await insertDive('noGps');
    final siteId = await insertSite('s1', lat: 3, lng: 4);
    await insertDive('sited', lat: 3, lng: 4, siteId: siteId);

    final result = await repo.getDivesNeedingSiteMatch();
    final ids = result.map((d) => d.id).toList();

    expect(ids, contains('withGps'));
    expect(ids, isNot(contains('noGps')));
    expect(ids, isNot(contains('sited')));
    expect(result.length, 1);
  });

  test('getDivesNeedingSiteMatch honours limitToIds', () async {
    await insertDive('a', lat: 1, lng: 2);
    await insertDive('b', lat: 3, lng: 4);

    final result = await repo.getDivesNeedingSiteMatch(limitToIds: ['a']);
    expect(result.map((d) => d.id), ['a']);
  });

  test(
    'getDivesNeedingSiteMatch filters by diverId and returns empty',
    () async {
      await insertDive('withGps', lat: 1, lng: 2); // no diverId on this dive

      final result = await repo.getDivesNeedingSiteMatch(diverId: 'nobody');
      expect(result, isEmpty);
    },
  );

  test(
    'getDivesNeedingSiteMatch short-circuits an empty limitToIds set',
    () async {
      await insertDive('withGps', lat: 1, lng: 2);

      final result = await repo.getDivesNeedingSiteMatch(limitToIds: const []);
      expect(result, isEmpty);
    },
  );

  test('setSiteSuggestionDismissed writes and clears the timestamp', () async {
    await insertDive('d1', lat: 1, lng: 2);

    await repo.setSiteSuggestionDismissed('d1', true);
    var row = await db
        .customSelect(
          "SELECT site_suggestion_dismissed_at AS v FROM dives WHERE id = 'd1'",
        )
        .getSingle();
    expect(row.readNullable<int>('v'), isNotNull);

    await repo.setSiteSuggestionDismissed('d1', false);
    row = await db
        .customSelect(
          "SELECT site_suggestion_dismissed_at AS v FROM dives WHERE id = 'd1'",
        )
        .getSingle();
    expect(row.readNullable<int>('v'), isNull);
  });

  test('a dismissal advances the dive HLC so it exports', () async {
    await insertDive('d1', lat: 1, lng: 2);
    final sync = SyncRepository();
    await sync.markRecordPending(
      entityType: 'dives',
      recordId: 'd1',
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final watermark =
        (await db
                .customSelect("SELECT hlc FROM dives WHERE id = 'd1'")
                .getSingle())
            .read<String>('hlc');
    final serializer = SyncDataSerializer();
    final deviceId = await sync.getDeviceId();

    final before = await serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: watermark,
      deletions: const [],
    );
    expect(before.data.dives.map((d) => d['id']), isNot(contains('d1')));

    await repo.setSiteSuggestionDismissed('d1', true);

    final after = await serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: watermark,
      deletions: const [],
    );
    final exported = after.data.dives.firstWhere((d) => d['id'] == 'd1');
    expect(
      exported['siteSuggestionDismissedAt'],
      isNotNull,
      reason: 'the dismissal must ride the dive row to other devices',
    );
  });

  group('getDivesNeedingSiteMatch (unified predicate)', () {
    test('includes a siteless dive whose only GPS is a photo', () async {
      await insertDive('photoOnly');
      await insertPhotoWithGps('p1', 'photoOnly');
      final ids = (await repo.getDivesNeedingSiteMatch()).map((d) => d.id);
      expect(ids, contains('photoOnly'));
    });

    test('includes a dive whose site lacks coordinates', () async {
      final bare = await insertSite('bare');
      await insertDive('sitedNoCoords', lat: 1, lng: 2, siteId: bare);
      final ids = (await repo.getDivesNeedingSiteMatch()).map((d) => d.id);
      expect(ids, contains('sitedNoCoords'));
    });

    test('excludes a dive whose only GPS photo has no capture time', () async {
      // getBestPhotoGpsForDives needs taken_at to pick the photo nearest
      // entry, so such a dive yields no point. Counting it here would
      // inflate the post-import offer and then show an empty review.
      await insertDive('noCaptureTime');
      await insertPhotoWithGps('p1', 'noCaptureTime');
      await db.customStatement(
        "UPDATE media SET taken_at = NULL WHERE id = 'p1'",
      );

      final ids = (await repo.getDivesNeedingSiteMatch()).map((d) => d.id);

      expect(ids, isNot(contains('noCaptureTime')));
    });

    test('still includes the dive when another GPS photo is dated', () async {
      await insertDive('mixed');
      await insertPhotoWithGps('undated', 'mixed');
      await insertPhotoWithGps('dated', 'mixed');
      await db.customStatement(
        "UPDATE media SET taken_at = NULL WHERE id = 'undated'",
      );

      final ids = (await repo.getDivesNeedingSiteMatch()).map((d) => d.id);

      expect(ids, contains('mixed'));
    });

    test('excludes a dive whose site has coordinates', () async {
      final located = await insertSite('located', lat: 5, lng: 6);
      await insertDive('sited', lat: 1, lng: 2, siteId: located);
      final ids = (await repo.getDivesNeedingSiteMatch()).map((d) => d.id);
      expect(ids, isNot(contains('sited')));
    });

    test('excludes a dismissed dive and a dive with no point at all', () async {
      await insertDive('dismissed', lat: 1, lng: 2);
      await repo.setSiteSuggestionDismissed('dismissed', true);
      await insertDive('nothing');
      final ids = (await repo.getDivesNeedingSiteMatch()).map((d) => d.id);
      expect(ids, isNot(contains('dismissed')));
      expect(ids, isNot(contains('nothing')));
    });
  });
}
