import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

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
}
