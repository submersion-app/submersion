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

  Future<void> insertDiveWithTank({
    required String id,
    required String diveMode,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            diveMode: Value(diveMode),
            avgDepth: const Value(20.0),
            maxDepth: const Value(25.0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('tank-$id'),
            diveId: Value(id),
            startPressure: const Value(200.0),
            endPressure: const Value(50.0),
            o2Percent: const Value(21.0), // air
            hePercent: const Value(0.0),
            tankOrder: const Value(0),
          ),
        );
  }

  test('getGasMixDistribution excludes gauge dives', () async {
    await insertDiveWithTank(id: 'oc-1', diveMode: 'oc');
    await insertDiveWithTank(id: 'gauge-1', diveMode: 'gauge');

    final dist = await repository.getGasMixDistribution();
    final total = dist.fold<int>(0, (sum, s) => sum + s.count);

    expect(
      total,
      1,
      reason: 'only the OC dive should be counted; the gauge dive is excluded',
    );
    // The single counted dive is the OC air dive.
    expect(dist.single.label, 'Air');
  });
}
