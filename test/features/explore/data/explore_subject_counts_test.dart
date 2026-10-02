import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/data/explore_repository.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ExploreRepository repo;
  final now = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ExploreRepository(db: db);
  });
  tearDown(tearDownTestDatabase);

  Future<void> diver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(
          id: id,
          name: id,
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<void> site(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> dive(
    String id, {
    String? siteId,
    String diverId = 'me',
    double depth = 10,
    bool excluded = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
          siteId: Value(siteId),
          maxDepth: Value(depth),
          excludedFromStats: Value(excluded),
        ),
      );

  final deep = ConditionNode(
    FieldPath(const ['depth']),
    QueryOp.gte,
    const NumberValue(20, null),
  );

  setUp(() async {
    await diver('me');
    await diver('other');
  });

  test('counts the diver\'s counted dives per site in the scope', () async {
    await site('a');
    await site('b');
    await dive('1', siteId: 'a', depth: 30);
    await dive('2', siteId: 'a', depth: 25);
    await dive('3', siteId: 'a', depth: 5);
    await dive('4', siteId: 'b', depth: 40);
    // Excluded from statistics, and another diver's: neither counts.
    await dive('5', siteId: 'b', depth: 40, excluded: true);
    await dive('6', siteId: 'b', depth: 40, diverId: 'other');

    expect(
      await repo.diveCountsBySubject(ParsedSubject.sites, deep, diverId: 'me'),
      {'a': 2, 'b': 1},
    );
    expect(
      await repo.diveCountsBySubject(ParsedSubject.sites, null, diverId: 'me'),
      {'a': 3, 'b': 1},
    );
  });

  test('a buddy counts the dives they were on', () async {
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: const Value('ana'),
            name: const Value('Ana'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await dive('1', depth: 30);
    await dive('2', depth: 5);
    for (final d in ['1', '2']) {
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value('j$d'),
              diveId: Value(d),
              buddyId: const Value('ana'),
              createdAt: Value(now),
            ),
          );
    }
    expect(
      await repo.diveCountsBySubject(
        ParsedSubject.buddies,
        deep,
        diverId: 'me',
      ),
      {'ana': 1},
    );
  });

  test('an item linked twice on one dive counts that dive once', () async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'cyl',
            name: 'Cylinder',
            type: 'tank',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dive('1');
    await db
        .into(db.diveEquipment)
        .insert(DiveEquipmentCompanion.insert(diveId: '1', equipmentId: 'cyl'));
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't',
            diveId: '1',
          ).copyWith(equipmentId: const Value('cyl')),
        );
    expect(
      await repo.diveCountsBySubject(
        ParsedSubject.equipment,
        null,
        diverId: 'me',
      ),
      {'cyl': 1},
    );
  });

  test('the tick tables name every table a count reads', () {
    expect(ExploreRepository.subjectCountTables(ParsedSubject.sites), isEmpty);
    expect(ExploreRepository.subjectCountTables(ParsedSubject.buddies), {
      'dive_buddies',
    });
    expect(ExploreRepository.subjectCountTables(ParsedSubject.equipment), {
      'dive_equipment',
      'dive_tanks',
    });
    expect(ExploreRepository.subjectCountTables(ParsedSubject.species), {
      'sightings',
    });
  });
}
