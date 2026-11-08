import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #3374: the planner's "from your log" rate is the diver's backmount
/// rate, so a twin set counts with back gas rather than leaving the figure
/// to whatever role group happens to come first. Issue #771: it is the bottom
/// gas line of the consumption by cylinder role card, each dive's rate over
/// the time that gas was breathed, averaged over dives.
void main() {
  late AppDatabase db;
  const now = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
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

  Future<void> insertTank(
    String diveId,
    String id,
    String role, {
    double end = 100,
    double volume = 12,
    double o2 = 21,
    int order = 1,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: Value(diveId),
          startPressure: const Value(200),
          endPressure: Value(end),
          volume: Value(volume),
          tankRole: Value(role),
          o2Percent: Value(o2),
          hePercent: const Value(0),
          tankOrder: Value(order),
        ),
      );

  Future<void> insertSwitch(String diveId, String tankId, int timestamp) => db
      .into(db.gasSwitches)
      .insert(
        GasSwitchesCompanion(
          id: Value('$tankId-$timestamp'),
          diveId: Value(diveId),
          tankId: Value(tankId),
          timestamp: Value(timestamp),
          createdAt: const Value(0),
        ),
      );

  /// The dive detail's RMV for [tankId] on [diveId].
  Future<double> detailRmv(String diveId, String tankId) async {
    final dives = DiveRepository();
    final dive = (await dives.getDiveById(diveId))!;
    final rows = const GasAnalysisService(gasModel: GasModel.real)
        .calculateCylinderSac(
          dive: dive,
          profile: dive.profile,
          gasSwitches: await dives.getGasSwitchesForDive(diveId),
        );
    return rows.singleWhere((r) => r.tankId == tankId).rmv!;
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

    expect(await logged(), closeTo(await detailRmv('twin', 'twin-0'), 1e-9));
  });

  test('back gas and twin set dives average together by dive', () async {
    await insertDive('single', 'backGas', end: 137);
    await insertDive('twin-a', 'twinSet');
    await insertDive('twin-b', 'twinSet');
    final expected =
        (await detailRmv('single', 'single-0') +
            await detailRmv('twin-a', 'twin-a-0') +
            await detailRmv('twin-b', 'twin-b-0')) /
        3;

    expect(await logged(), closeTo(expected, 1e-9));
  });

  test("another diver's dives are left out", () async {
    await insertDiver('me');
    await insertDiver('other');
    await insertDive('mine', 'twinSet', diverId: 'me');
    await insertDive('theirs', 'backGas', end: 137, diverId: 'other');

    expect(
      await logged(diverId: 'me'),
      closeTo(await detailRmv('mine', 'mine-0'), 1e-9),
    );
  });

  test('a stage alone is not a backmount rate', () async {
    await insertDive('stage', 'stage');

    expect(await logged(), isNull);
  });

  test(
    'a deco dive with switches gives the back gas rate over its own window',
    () async {
      await insertDive('tech', 'backGas');
      await insertTank('tech', 'tech-deco', 'deco', volume: 7, o2: 50);
      await insertSwitch('tech', 'tech-deco', 32 * 60);
      final back = await detailRmv('tech', 'tech-0');

      expect(await logged(), closeTo(back, 1e-9));
    },
  );

  test('a deco dive without switches is not in the default', () async {
    await insertDive('hand', 'backGas');
    await insertTank('hand', 'hand-deco', 'deco', volume: 7, o2: 50);

    expect(await logged(), isNull);
  });

  test('sidemount counts as bottom gas', () async {
    await insertDive('side', 'sidemountLeft');
    await insertTank('side', 'side-right', 'sidemountRight', volume: 24);

    expect(
      await logged(),
      closeTo(
        await detailRmv('side', 'side-0') +
            await detailRmv('side', 'side-right'),
        1e-9,
      ),
    );
  });
}
