import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1028: the Statistics tab's personal records ignored the active
/// Statistics filter while every other panel on the page honoured it.
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> insertSite(String id) async {
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
  }

  Future<void> insertDiver(String id) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive(
    String id, {
    required DateTime date,
    String? diverId,
    String? siteId,
    double? maxDepth,
    double? waterTemp,
    int? bottomTimeSeconds,
    bool favorite = false,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(date.millisecondsSinceEpoch),
            siteId: Value(siteId),
            maxDepth: Value(maxDepth),
            waterTemp: Value(waterTemp),
            bottomTime: Value(bottomTimeSeconds),
            isFavorite: Value(favorite),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  group('getRecords with a filter', () {
    test('an empty filter still considers every dive', () async {
      await insertDive(
        'shallow',
        date: DateTime(2024, 1, 10),
        maxDepth: 12,
        waterTemp: 26,
        bottomTimeSeconds: 1800,
      );
      await insertDive(
        'deep',
        date: DateTime(2026, 5, 10),
        maxDepth: 44,
        waterTemp: 9,
        bottomTimeSeconds: 3600,
      );

      final records = await repository.getRecords();

      expect(records.deepestDive!.diveId, 'deep');
      expect(records.shallowestDive!.diveId, 'shallow');
      expect(records.longestDive!.diveId, 'deep');
      expect(records.coldestDive!.diveId, 'deep');
      expect(records.warmestDive!.diveId, 'shallow');
      expect(records.firstDive!.diveId, 'shallow');
      expect(records.lastDive!.diveId, 'deep');
    });

    test('a date-range filter narrows every superlative', () async {
      await insertDive(
        'old',
        date: DateTime(2024, 1, 10),
        maxDepth: 60,
        waterTemp: 4,
        bottomTimeSeconds: 7200,
      );
      await insertDive(
        'inRange',
        date: DateTime(2026, 6, 15),
        maxDepth: 30,
        waterTemp: 20,
        bottomTimeSeconds: 2400,
      );
      await insertDive(
        'newer',
        date: DateTime(2026, 9, 1),
        maxDepth: 50,
        waterTemp: 8,
        bottomTimeSeconds: 5400,
      );

      final records = await repository.getRecords(
        filter: DiveFilterState(
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 30),
        ),
      );

      expect(records.deepestDive!.diveId, 'inRange');
      expect(records.shallowestDive!.diveId, 'inRange');
      expect(records.longestDive!.diveId, 'inRange');
      expect(records.coldestDive!.diveId, 'inRange');
      expect(records.warmestDive!.diveId, 'inRange');
      expect(records.firstDive!.diveId, 'inRange');
      expect(records.lastDive!.diveId, 'inRange');
    });

    test('a site filter narrows the records to that site', () async {
      await insertSite('reef');
      await insertSite('wreck');
      await insertDive(
        'atReef',
        date: DateTime(2026, 3, 1),
        siteId: 'reef',
        maxDepth: 18,
        waterTemp: 24,
      );
      await insertDive(
        'atWreck',
        date: DateTime(2026, 4, 1),
        siteId: 'wreck',
        maxDepth: 42,
        waterTemp: 12,
      );

      final records = await repository.getRecords(
        filter: const DiveFilterState(siteId: 'wreck'),
      );

      expect(records.deepestDive!.diveId, 'atWreck');
      expect(records.warmestDive!.diveId, 'atWreck');
      expect(records.firstDive!.diveId, 'atWreck');
      expect(records.lastDive!.diveId, 'atWreck');
    });

    test('a filter that matches nothing yields no records', () async {
      await insertDive(
        'only',
        date: DateTime(2026, 3, 1),
        maxDepth: 18,
        waterTemp: 24,
        bottomTimeSeconds: 1800,
      );

      final records = await repository.getRecords(
        filter: const DiveFilterState(favoritesOnly: true),
      );

      expect(records.deepestDive, isNull);
      expect(records.shallowestDive, isNull);
      expect(records.longestDive, isNull);
      expect(records.coldestDive, isNull);
      expect(records.warmestDive, isNull);
      expect(records.firstDive, isNull);
      expect(records.lastDive, isNull);
    });

    test('the diver scope and the filter compose', () async {
      await insertDiver('me');
      await insertDiver('other');
      await insertDive(
        'mineFavorite',
        date: DateTime(2026, 3, 1),
        diverId: 'me',
        maxDepth: 20,
        waterTemp: 22,
        bottomTimeSeconds: 1800,
        favorite: true,
      );
      await insertDive(
        'minePlain',
        date: DateTime(2026, 3, 2),
        diverId: 'me',
        maxDepth: 55,
        waterTemp: 6,
        bottomTimeSeconds: 3600,
      );
      await insertDive(
        'theirsFavorite',
        date: DateTime(2026, 3, 3),
        diverId: 'other',
        maxDepth: 70,
        waterTemp: 3,
        bottomTimeSeconds: 5400,
        favorite: true,
      );

      final records = await repository.getRecords(
        diverId: 'me',
        filter: const DiveFilterState(favoritesOnly: true),
      );

      expect(records.deepestDive!.diveId, 'mineFavorite');
      expect(records.shallowestDive!.diveId, 'mineFavorite');
      expect(records.longestDive!.diveId, 'mineFavorite');
      expect(records.coldestDive!.diveId, 'mineFavorite');
      expect(records.warmestDive!.diveId, 'mineFavorite');
      expect(records.firstDive!.diveId, 'mineFavorite');
      expect(records.lastDive!.diveId, 'mineFavorite');
    });

    // The no-buddy axis is the one clause that names `dives` explicitly inside
    // its own correlated subquery; getRecords aliases the outer table as `d`,
    // so this guards against the alias resolving the wrong way.
    test(
      'a no-buddy filter resolves inside the aliased records query',
      () async {
        await insertDive(
          'solo',
          date: DateTime(2026, 3, 1),
          maxDepth: 20,
          waterTemp: 22,
          bottomTimeSeconds: 1800,
        );
        await insertDive(
          'paired',
          date: DateTime(2026, 3, 2),
          maxDepth: 40,
          waterTemp: 10,
          bottomTimeSeconds: 3600,
        );
        await db
            .into(db.buddies)
            .insert(
              BuddiesCompanion(
                id: const Value('b1'),
                name: const Value('Buddy One'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await db
            .into(db.diveBuddies)
            .insert(
              DiveBuddiesCompanion(
                id: const Value('paired-b1'),
                diveId: const Value('paired'),
                buddyId: const Value('b1'),
                createdAt: Value(now),
              ),
            );

        final records = await repository.getRecords(
          filter: const DiveFilterState(noBuddyOnly: true),
        );

        expect(records.deepestDive!.diveId, 'solo');
        expect(records.lastDive!.diveId, 'solo');
      },
    );
  });
}
