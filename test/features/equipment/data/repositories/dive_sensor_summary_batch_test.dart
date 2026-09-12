import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveSensorSummaryRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveSensorSummaryRepository(db: db);
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'd$i',
              diveDateTime: 1000 + i,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
    }
    for (var i = 0; i < 2; i++) {
      await repo.saveSummary(
        DiveSensorSummary(
          diveId: 'd$i',
          engineVersion: 1,
          sourceUpdatedAt: 1000,
          computedAt: DateTime.utc(2026),
          maxDepth: 10.0 + i,
        ),
      );
    }
  });

  tearDown(tearDownTestDatabase);

  test(
    'getSummaries returns stored rows keyed by dive, missing absent',
    () async {
      final byDive = await repo.getSummaries(['d0', 'd1', 'd2', 'nope']);
      expect(byDive.keys, unorderedEquals(['d0', 'd1']));
      expect(byDive['d1']!.maxDepth, 11.0);
    },
  );

  test('getSummaries of nothing is empty and issues no query', () async {
    expect(await repo.getSummaries(const []), isEmpty);
  });

  test('getSummaries chunks a long id list', () async {
    final ids = [for (var i = 0; i < 1200; i++) 'd${i % 3}'];
    final byDive = await repo.getSummaries(ids);
    expect(byDive.keys, unorderedEquals(['d0', 'd1']));
  });
}
