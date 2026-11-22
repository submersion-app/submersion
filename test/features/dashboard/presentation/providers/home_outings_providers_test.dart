import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_outings_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> dive(String id, DateTime at, {String? tripId}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(at.millisecondsSinceEpoch),
          tripId: Value(tripId),
          maxDepth: const Value(20),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> photo(String id, String diveId, {bool favorite = false}) => db
      .into(db.media)
      .insert(
        MediaCompanion.insert(
          id: id,
          diveId: Value(diveId),
          filePath: '/$id.jpg',
          isFavorite: Value(favorite),
          takenAt: const Value(1000),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await setUpTestDatabase();
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Bonaire',
            startDate: 0,
            endDate: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await dive('b1', DateTime.utc(2026, 5, 3, 9), tripId: 't1');
    await dive('b2', DateTime.utc(2026, 5, 4, 9), tripId: 't1');
    await dive('pool', DateTime.utc(2025, 10, 26, 9));
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test(
    'pairs each outing with its cover and leaves coverless ones null',
    () async {
      await photo('p1', 'b1');
      await photo('p2', 'b2', favorite: true);

      final outings = await container.read(homeRecentOutingsProvider.future);
      expect(outings, hasLength(2));
      expect(outings.first.outing.tripId, 't1');
      expect(outings.first.cover?.id, 'p2');
      expect(outings.last.outing.diveIds, ['pool']);
      expect(outings.last.cover, isNull);
    },
  );

  test('a new photo rebuilds the outings', () async {
    final sub = container.listen(homeRecentOutingsProvider, (_, _) {});
    addTearDown(sub.close);
    final before = await container.read(homeRecentOutingsProvider.future);
    expect(before.last.cover, isNull);

    await photo('p3', 'pool');
    // The media tick is debounced; wait for the rebuild to land.
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final now = container.read(homeRecentOutingsProvider).value;
      if (now != null && now.last.cover != null) break;
    }
    final after = await container.read(homeRecentOutingsProvider.future);
    expect(after.last.cover?.id, 'p3');
  });

  test('no dives give no outings', () async {
    await db.delete(db.dives).go();
    expect(await container.read(homeRecentOutingsProvider.future), isEmpty);
  });

  test(
    'a failed cover read still shows every outing, without covers',
    () async {
      await photo('p1', 'b1', favorite: true);
      // Any failure in the cover reads; the dives read is unaffected.
      await db.customStatement('DROP TABLE media_species');
      final outings = await container.read(homeRecentOutingsProvider.future);
      expect(outings, hasLength(2));
      expect(outings.every((o) => o.cover == null), isTrue);
    },
  );

  group('the 300-dive read', () {
    Future<void> seed({required bool older}) async {
      await db.delete(db.dives).go();
      // 299 dives on one trip, and one far older trip-less dive: 300 in all.
      await db.batch((b) {
        for (var i = 0; i < 299; i++) {
          b.insert(
            db.dives,
            DivesCompanion(
              id: Value('t$i'),
              diveDateTime: Value(
                DateTime.utc(2026, 5, 3, 0, i).millisecondsSinceEpoch,
              ),
              tripId: const Value('t1'),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
        }
      });
      await dive('old', DateTime.utc(2020, 1, 1, 9));
      if (older) await dive('older', DateTime.utc(2019, 1, 1, 9));
    }

    test('exactly 300 dives keep the oldest outing', () async {
      await seed(older: false);
      final outings = await container.read(homeRecentOutingsProvider.future);
      expect(outings.map((o) => o.outing.diveIds.first), ['t0', 'old']);
    });

    test('a 301st dive drops the outing the read may have cut', () async {
      await seed(older: true);
      final outings = await container.read(homeRecentOutingsProvider.future);
      expect(outings.map((o) => o.outing.tripId), ['t1']);
    });
  });

  test('a trip cut by the read is completed from the log', () async {
    await db.delete(db.dives).go();
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't2',
            name: 'Older trip',
            startDate: 0,
            endDate: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db.batch((b) {
      for (var i = 0; i < 299; i++) {
        b.insert(
          db.dives,
          DivesCompanion(
            id: Value('t$i'),
            diveDateTime: Value(
              DateTime.utc(2026, 6, 3, 0, i).millisecondsSinceEpoch,
            ),
            tripId: const Value('t1'),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
      }
    });
    // The 300th newest dive is on t2; a trip-less dive and t2's first dive
    // lie past the read.
    await dive('t2-late', DateTime.utc(2025, 5, 3, 9), tripId: 't2');
    await dive('pool', DateTime.utc(2025, 5, 2, 9));
    await dive('t2-early', DateTime.utc(2025, 5, 1, 9), tripId: 't2');

    final outings = await container.read(homeRecentOutingsProvider.future);
    final t2 = outings.singleWhere((o) => o.outing.tripId == 't2').outing;
    expect(t2.diveIds, ['t2-early', 't2-late']);
    expect(t2.firstDay, DateTime(2025, 5, 1));
  });

  group('what rebuilds the outings', () {
    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }

    test('a trip rename rebuilds them', () async {
      final sub = container.listen(homeRecentOutingsProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(homeRecentOutingsProvider.future);
      await (db.update(db.trips)..where((t) => t.id.equals('t1'))).write(
        const TripsCompanion(name: Value('Bonaire again')),
      );
      await settle();
      final after = await container.read(homeRecentOutingsProvider.future);
      expect(after.first.outing.name, 'Bonaire again');
    });

    test('a cylinder write does not', () async {
      var builds = 0;
      final sub = container.listen(homeRecentOutingsProvider, (_, next) {
        if (next.hasValue && !next.isLoading) builds++;
      }, fireImmediately: true);
      addTearDown(sub.close);
      await container.read(homeRecentOutingsProvider.future);
      await settle();
      final before = builds;
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('tank'),
              diveId: Value('b1'),
              tankOrder: Value(0),
            ),
          );
      await settle();
      expect(builds, before);
    });
  });
}
