import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = StatisticsRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> dive(String id, {String? visibility, double? waterTemp}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            visibility: Value(visibility),
            waterTemp: Value(waterTemp),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> tag(String id) async {
    await db
        .into(db.tags)
        .insert(
          TagsCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> link(String diveId, String tagId) async {
    await db
        .into(db.diveTags)
        .insert(
          DiveTagsCompanion(
            id: Value('$diveId-$tagId'),
            diveId: Value(diveId),
            tagId: Value(tagId),
            createdAt: Value(now),
          ),
        );
  }

  Future<void> species(String id, {String category = 'fish'}) async {
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion(
            id: Value(id),
            commonName: Value(id),
            category: Value(category),
          ),
        );
  }

  test('visibility distribution respects a tag filter', () async {
    await dive('a', visibility: 'Good');
    await dive('b', visibility: 'Poor');
    await tag('dry');
    await link('a', 'dry');

    final all = await repo.getVisibilityDistribution();
    expect(all.length, 2);

    final filtered = await repo.getVisibilityDistribution(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered.length, 1);
    expect(filtered.first.label, 'Good');
  });

  test('dive-type distribution respects a tag filter', () async {
    await dive('a');
    await dive('b');
    await db
        .into(db.diveDiveTypes)
        .insert(
          DiveDiveTypesCompanion(
            id: const Value('t-a'),
            diveId: const Value('a'),
            diveTypeId: const Value('wreck'),
            createdAt: Value(now),
          ),
        );
    await db
        .into(db.diveDiveTypes)
        .insert(
          DiveDiveTypesCompanion(
            id: const Value('t-b'),
            diveId: const Value('b'),
            diveTypeId: const Value('wreck'),
            createdAt: Value(now),
          ),
        );
    await tag('dry');
    await link('a', 'dry');

    final filtered = await repo.getDiveTypeDistribution(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered.first.count, 1); // only dive 'a'
  });

  test('gas-mix distribution respects a tag filter', () async {
    await dive('a');
    await dive('b');
    for (final id in ['a', 'b']) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value('tank-$id'),
              diveId: Value(id),
              o2Percent: const Value(32.0),
              hePercent: const Value(0.0),
              tankOrder: const Value(0),
            ),
          );
    }
    await tag('dry');
    await link('a', 'dry');

    final filtered = await repo.getGasMixDistribution(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    final total = filtered.fold<int>(0, (s, seg) => s + seg.count);
    expect(total, 1); // only dive 'a'
  });

  test('top buddies respects a tag filter (LIMIT method)', () async {
    await dive('a');
    await dive('b');
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: const Value('bud'),
            name: const Value('Sam'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final id in ['a', 'b']) {
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value('db-$id'),
              diveId: Value(id),
              buddyId: const Value('bud'),
              createdAt: Value(now),
            ),
          );
    }
    await tag('dry');
    await link('a', 'dry');

    final filtered = await repo.getTopBuddies(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered.first.count, 1); // buddy appears on 1 filtered dive
  });

  test('unique species count respects a tag filter', () async {
    await dive('a');
    await dive('b');
    await species('turtle', category: 'reptile');
    await species('shark');
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(
            id: 'sight-a',
            diveId: 'a',
            speciesId: 'turtle',
          ),
        );
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(
            id: 'sight-b',
            diveId: 'b',
            speciesId: 'shark',
          ),
        );
    await tag('dry');
    await link('a', 'dry');

    final all = await repo.getUniqueSpeciesCount();
    expect(all, 2);

    final filtered = await repo.getUniqueSpeciesCount(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered, 1); // only turtle, sighted on dive 'a'
  });

  test('temperature by month respects a tag filter', () async {
    await dive('a', waterTemp: 20.0);
    await dive('b', waterTemp: 10.0);
    await tag('dry');
    await link('a', 'dry');

    final all = await repo.getTemperatureByMonth();
    expect(all.length, 1);
    expect(all.first.minTemp, 10.0);
    expect(all.first.maxTemp, 20.0);

    final filtered = await repo.getTemperatureByMonth(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered.length, 1);
    // Only dive 'a' (20.0) survives the filter, so the range collapses -
    // this differs from the unfiltered 10.0-20.0 range above.
    expect(filtered.first.minTemp, 20.0);
    expect(filtered.first.maxTemp, 20.0);
  });

  test('dives by day-of-week respects a tag filter', () async {
    await dive('a');
    await dive('b');
    await tag('dry');
    await link('a', 'dry');

    final all = await repo.getDivesByDayOfWeek();
    final allTotal = all.fold<int>(0, (s, e) => s + e.count);
    expect(allTotal, 2);

    final filtered = await repo.getDivesByDayOfWeek(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    final total = filtered.fold<int>(0, (s, e) => s + e.count);
    expect(total, 1);
  });
}
