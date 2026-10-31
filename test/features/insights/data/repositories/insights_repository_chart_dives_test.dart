import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/insights_dive_filters.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3805: a chart link opens the dives its number counted, so the ids
/// here must follow the statistics scope and the Insights filter.
void main() {
  late AppDatabase db;
  late InsightsRepository repository;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(
    String id, {
    bool excluded = false,
    bool gasExcluded = false,
    bool planned = false,
    String diveMode = 'oc',
    double? maxDepth,
    String? diverId,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
          excludedFromStats: Value(excluded),
          excludedFromGasStats: Value(gasExcluded),
          isPlanned: Value(planned),
          diveMode: Value(diveMode),
          maxDepth: Value(maxDepth),
          diverId: Value(diverId),
        ),
      );

  group('getCountedDiveIds', () {
    test('leaves out excluded and planned dives', () async {
      await insertDive('kept');
      await insertDive('excluded', excluded: true);
      await insertDive('planned', planned: true);

      expect(await repository.getCountedDiveIds(), ['kept']);
    });

    test('holds only the current diver\'s dives', () async {
      await db
          .into(db.divers)
          .insert(
            const DiversCompanion(
              id: Value('diver-a'),
              name: Value('A'),
              medicalNotes: Value(''),
              notes: Value(''),
              isDefault: Value(false),
              createdAt: Value(0),
              updatedAt: Value(0),
            ),
          );
      await insertDive('mine', diverId: 'diver-a');
      await insertDive('theirs');

      expect(await repository.getCountedDiveIds(diverId: 'diver-a'), ['mine']);
    });

    test('follows the Insights filter', () async {
      await insertDive('deep', maxDepth: 40);
      await insertDive('shallow', maxDepth: 10);

      expect(
        await repository.getCountedDiveIds(
          filter: const DiveFilterState(minDepth: 20),
        ),
        ['deep'],
      );
    });

    test('a gas count also leaves out gauge and gas-excluded dives', () async {
      await insertDive('kept');
      await insertDive('gauge', diveMode: 'gauge');
      await insertDive('gas-excluded', gasExcluded: true);

      expect(await repository.getCountedDiveIds(gas: true), ['kept']);
      expect(await repository.getCountedDiveIds(), hasLength(3));
    });
  });

  /// Every row of a chart opens exactly the dives it counted.
  Future<void> expectEveryRowOpensItsDives<K>(
    List<({K key, int count})> rows,
    DiveFilterState Function(DiveFilterState scope, K key) filterFor,
  ) async {
    expect(rows, isNotEmpty);
    for (final row in rows) {
      final ids = await repository.getCountedDiveIds(
        filter: filterFor(const DiveFilterState(), row.key),
      );
      expect(ids, hasLength(row.count), reason: '${row.key}');
    }
  }

  group('charts a filter can state', () {
    Future<void> dive(
      String id, {
      required DateTime at,
      String? siteId,
      String? waterType,
      String? entryMethod,
      bool excluded = false,
      bool planned = false,
    }) => db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            siteId: Value(siteId),
            waterType: Value(waterType),
            entryMethod: Value(entryMethod),
            excludedFromStats: Value(excluded),
            isPlanned: Value(planned),
            diveDateTime: Value(at.millisecondsSinceEpoch),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );

    Future<void> site(String id, {String? waterType, String? entryMethod}) => db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: 'Site $id',
            waterType: Value(waterType),
            entryMethod: Value(entryMethod),
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    Future<void> uncountedDives(DateTime at, {String? siteId}) async {
      await dive('excluded-$at', at: at, siteId: siteId, excluded: true);
      await dive('planned-$at', at: at, siteId: siteId, planned: true);
    }

    final monday = DateTime.utc(2026, 6, 1, 9);
    final saturday = DateTime.utc(2025, 3, 8, 23, 30);
    final sunday = DateTime.utc(2025, 3, 9, 0, 30);

    Future<void> datedDives() async {
      await dive('a', at: monday);
      await dive('b', at: monday);
      await dive('c', at: saturday);
      await dive('d', at: sunday);
      await uncountedDives(saturday);
    }

    test('day of week', () async {
      await datedDives();
      final rows = await repository.getDivesByDayOfWeek();
      await expectEveryRowOpensItsDives([
        for (final r in rows) (key: r.dayOfWeek, count: r.count),
      ], weekdayDivesFilter);
    });

    test('month', () async {
      await datedDives();
      final rows = await repository.getDivesBySeason();
      await expectEveryRowOpensItsDives([
        for (final r in rows) (key: r.month, count: r.count),
      ], monthDivesFilter);
    });

    test('year', () async {
      await datedDives();
      final rows = await repository.getDivesPerYear();
      await expectEveryRowOpensItsDives([
        for (final r in rows) (key: r.year, count: r.count),
      ], yearDivesFilter);
    });

    test('water type, from the dive, its site, or nowhere', () async {
      await site('reef', waterType: 'salt');
      await dive('own', at: monday, waterType: 'fresh');
      await dive('inherited', at: monday, siteId: 'reef');
      await dive('unknown', at: monday);
      await uncountedDives(monday, siteId: 'reef');

      final rows = await repository.getWaterTypeDistribution();

      expect(rows, hasLength(3));
      await expectEveryRowOpensItsDives([
        for (final r in rows) (key: r.label, count: r.count),
      ], waterTypeDivesFilter);
    });

    test('entry method, from the dive, its site, or nowhere', () async {
      await site('pier', entryMethod: 'shore');
      await dive('own', at: monday, entryMethod: 'boat');
      await dive('inherited', at: monday, siteId: 'pier');
      await dive('unknown', at: monday);
      await uncountedDives(monday, siteId: 'pier');

      final rows = await repository.getEntryMethodDistribution();

      expect(rows, hasLength(3));
      await expectEveryRowOpensItsDives([
        for (final r in rows) (key: r.label, count: r.count),
      ], entryMethodDivesFilter);
    });

    group('dive type', () {
      Future<void> typedDives() async {
        final dives = DiveRepository();
        Future<void> create(String id, List<String> types) => dives.createDive(
          domain.Dive(
            id: id,
            dateTime: DateTime(2026, 1, 1),
            diveTypeIds: types,
          ),
        );
        await create('both', const ['night', 'wreck']);
        await create('night-only', const ['night']);
        await create('wreck-only', const ['wreck']);
      }

      test('counts a dive under each of its types', () async {
        await typedDives();
        final rows = await repository.getDiveTypeDistribution();
        await expectEveryRowOpensItsDives([
          for (final r in rows) (key: r.label, count: r.count),
        ], diveTypeDivesFilter);
      });

      test('a type tapped under another type keeps both', () async {
        await typedDives();
        final ids = await repository.getCountedDiveIds(
          filter: diveTypeDivesFilter(
            const DiveFilterState(diveTypeId: 'night'),
            'wreck',
          ),
        );
        expect(ids, ['both']);
      });
    });
  });
}
