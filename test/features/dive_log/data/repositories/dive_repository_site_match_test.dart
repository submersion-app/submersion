import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

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

  Future<String> insertSite(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            name: Value('Site $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
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
    final siteId = await insertSite('s1');
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
}
