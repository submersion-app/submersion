import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_worst_case_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';

BailoutOutcome _outcome({
  double litersRequired = 1500,
  double availableLiters = 2000,
  BailoutGasGap? gasGap,
}) {
  final worst = BailoutPoint(
    runtimeSeconds: 1320,
    depthMeters: 45,
    ttsSeconds: 900,
    litersRequired: litersRequired,
    schedule: const DecoSchedule(stops: [], ttsSeconds: 900),
  );
  return BailoutOutcome(
    points: [worst],
    worstCase: worst,
    availableLiters: availableLiters,
    worstCaseRows: const [],
    ccrRows: const [],
    bailoutTanks: const [],
    bailoutTankUsages: const [],
    ceilingTrace: const [],
    ocStops: const [],
    gasGap: gasGap,
  );
}

PlanResultView<BailoutOutcome?> _view(
  BailoutOutcome? value, [
  PlanResultStatus status = PlanResultStatus.current,
]) => PlanResultView(value: value, status: status);

void main() {
  group('chartWorstCaseFrom', () {
    test('a current result marks its worst-case point', () {
      final worstCase = chartWorstCaseFrom(_view(_outcome()))!;

      expect(worstCase.runtimeSeconds, 1320);
      expect(worstCase.depthMeters, 45);
      expect(worstCase.ttsSeconds, 900);
      expect(worstCase.litersRequired, 1500);
      expect(worstCase.availableLiters, 2000);
      expect(worstCase.sufficient, isTrue);
      expect(worstCase.stale, isFalse);
    });

    test('a short bailout is marked as not sufficient', () {
      final worstCase = chartWorstCaseFrom(
        _view(_outcome(litersRequired: 2500, availableLiters: 2000)),
      )!;

      expect(worstCase.sufficient, isFalse);
    });

    test('a result for an earlier revision stays, marked stale', () {
      final worstCase = chartWorstCaseFrom(
        _view(_outcome(), PlanResultStatus.updating),
      )!;

      expect(worstCase.stale, isTrue);
      expect(worstCase.runtimeSeconds, 1320);
    });

    test('a failed run marks nothing, even with an older value held', () {
      expect(
        chartWorstCaseFrom(_view(_outcome(), PlanResultStatus.failed)),
        isNull,
      );
    });

    test('no value marks nothing', () {
      expect(chartWorstCaseFrom(_view(null)), isNull);
      expect(
        chartWorstCaseFrom(_view(null, PlanResultStatus.calculating)),
        isNull,
      );
    });

    test('a gas gap marks nothing: its figures are no bailout plan', () {
      expect(
        chartWorstCaseFrom(
          _view(
            _outcome(
              gasGap: const BailoutGasGap(
                depthMeters: 70,
                deepestModMeters: 56,
              ),
            ),
          ),
        ),
        isNull,
      );
    });
  });

  group('planChartWorstCaseProvider', () {
    ProviderContainer containerWith({
      required bool mayHaveBailout,
      BailoutOutcome? outcome,
    }) {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          planMayHaveBailoutProvider.overrideWithValue(mayHaveBailout),
          planBailoutProvider.overrideWith(
            (ref) async => PlanBackgroundResult(
              planId: ref.watch(divePlanNotifierProvider.select((s) => s.id)),
              value: outcome,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('marks the bailout result of the open plan', () async {
      final container = containerWith(
        mayHaveBailout: true,
        outcome: _outcome(),
      );
      container.listen(planChartWorstCaseProvider, (_, _) {});
      await container.read(planBailoutProvider.future);

      final worstCase = container.read(planChartWorstCaseProvider);
      expect(worstCase, isNotNull);
      expect(worstCase!.runtimeSeconds, 1320);
      expect(worstCase.stale, isFalse);
    });

    test('marks nothing for a plan with nothing to bail out to', () async {
      final container = containerWith(
        mayHaveBailout: false,
        outcome: _outcome(),
      );
      container.listen(planChartWorstCaseProvider, (_, _) {});
      await container.read(planBailoutProvider.future);

      expect(container.read(planChartWorstCaseProvider), isNull);
    });
  });
}
