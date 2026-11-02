import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #3374: the planner's "from your log" rate is the diver's backmount
/// rate, so a twin set counts with back gas rather than leaving the figure
/// to whatever role group happens to come first.
void main() {
  late AppDatabase db;
  late InsightsRepository repository;
  const now = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });

  tearDown(tearDownTestDatabase);

  /// A 42 minute dive at 20 m with one sized cylinder in [role] that fell
  /// from 200 to [end] bar.
  Future<void> insertDive(
    String id,
    String role, {
    double end = 74,
    String? diverId,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: const Value(now),
            runtime: const Value(42 * 60),
            avgDepth: const Value(20.0),
            maxDepth: const Value(25.0),
            createdAt: const Value(now),
            updatedAt: const Value(now),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('$id-0'),
            diveId: Value(id),
            startPressure: const Value(200),
            endPressure: Value(end),
            volume: const Value(24),
            tankRole: Value(role),
            o2Percent: const Value(21),
            hePercent: const Value(0),
            tankOrder: const Value(0),
          ),
        );
  }

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<double?> logged({String? diverId}) async {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith((ref) {
          final notifier = MockCurrentDiverIdNotifier();
          if (diverId != null) notifier.setCurrentDiver(diverId);
          return notifier;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container.read(loggedAverageSacProvider.future);
  }

  test('a twin set only logbook gives the twin set rate', () async {
    await insertDive('twin', 'twinSet');
    final byRole = await repository.getSacVolumeByTankRole();

    expect(await logged(), closeTo(byRole['twinSet']!, 1e-9));
  });

  test('back gas and twin set dives average together by dive', () async {
    await insertDive('single', 'backGas', end: 137);
    await insertDive('twin-a', 'twinSet');
    await insertDive('twin-b', 'twinSet');
    final byRole = await repository.getSacVolumeByTankRole();
    final expected = (byRole['backGas']! + 2 * byRole['twinSet']!) / 3;

    expect(await logged(), closeTo(expected, 1e-9));
  });

  test("another diver's dives are left out", () async {
    await insertDiver('me');
    await insertDiver('other');
    await insertDive('mine', 'twinSet', diverId: 'me');
    await insertDive('theirs', 'backGas', end: 137, diverId: 'other');
    final byRole = await repository.getSacVolumeByTankRole(diverId: 'me');

    expect(await logged(diverId: 'me'), closeTo(byRole['twinSet']!, 1e-9));
  });

  test('a stage alone is not a backmount rate', () async {
    await insertDive('stage', 'stage');

    expect(await logged(), isNull);
  });
}
