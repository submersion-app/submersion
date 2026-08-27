import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late StatisticsRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = StatisticsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver({required String id}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            medicalNotes: const Value(''),
            notes: const Value(''),
            isDefault: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertSite({required String id, required String name}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            name: Value(name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDiveAtSite({
    required String id,
    required String siteId,
    String? diverId,
    double? waterTemp,
    double? maxDepth,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            siteId: Value(siteId),
            waterTemp: Value(waterTemp),
            maxDepth: Value(maxDepth),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  test(
    'aggregates only the requested diver history, case-insensitive',
    () async {
      await insertDiver(id: 'diver-1');
      await insertDiver(id: 'diver-2');
      await insertSite(id: 'site-a', name: 'Blue Corner');
      await insertDiveAtSite(
        id: 'd1',
        siteId: 'site-a',
        diverId: 'diver-1',
        waterTemp: 26,
        maxDepth: 20,
      );
      await insertDiveAtSite(
        id: 'd2',
        siteId: 'site-a',
        diverId: 'diver-1',
        waterTemp: 28,
        maxDepth: 30,
      );
      await insertDiveAtSite(
        id: 'd3',
        siteId: 'site-a',
        diverId: 'diver-2',
        waterTemp: 10,
        maxDepth: 10,
      );

      final history = await repository.getSiteHistoryByName(
        'blue corner',
        diverId: 'diver-1',
      );

      expect(history.diveCount, 2);
      expect(history.avgWaterTemp, closeTo(27.0, 0.001));
      expect(history.avgMaxDepth, closeTo(25.0, 0.001));
    },
  );

  test('unknown site returns zero count and null averages', () async {
    final history = await repository.getSiteHistoryByName(
      'Nowhere',
      diverId: 'diver-1',
    );
    expect(history.diveCount, 0);
    expect(history.avgWaterTemp, isNull);
    expect(history.avgMaxDepth, isNull);
  });
}
