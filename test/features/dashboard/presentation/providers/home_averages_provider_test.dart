import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The "vs average" SAC is the average over the same twelve months as the
/// depth and runtime averages, not over the 30 dives the trend panel draws.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> dive(String id, DateTime when, int startPressure) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(
              DateTime.utc(
                when.year,
                when.month,
                when.day,
                10,
              ).millisecondsSinceEpoch,
            ),
            avgDepth: const Value(10),
            maxDepth: const Value(15),
            runtime: const Value(3000),
            bottomTime: const Value(3000),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('t-$id'),
            diveId: Value(id),
            startPressure: Value(startPressure.toDouble()),
            endPressure: const Value(50),
            volume: const Value(12),
            tankRole: const Value('backGas'),
            o2Percent: const Value(21.0),
            hePercent: const Value(0.0),
            tankOrder: const Value(0),
          ),
        );
  }

  test('averages every dive in the window, not just the newest 30', () async {
    final now = DateTime.now();
    for (var i = 0; i < 40; i++) {
      // Older ten breathe harder: they move the twelve-month average.
      await dive(
        'd$i',
        now.subtract(Duration(days: 300 - i * 5)),
        i < 10 ? 250 : 200,
      );
    }
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        homeSacLaneProvider.overrideWithValue(GasConsumptionLane.rmv),
      ],
    );
    addTearDown(container.dispose);

    final all = await InsightsRepository().getSacVolumePerDive();
    expect(all, hasLength(40));
    final expected =
        all.map((p) => p.value).reduce((a, b) => a + b) / all.length;

    final result = await container.read(homeAveragesProvider.future);
    expect(result.sac, closeTo(expected, 1e-9));
  });
}
