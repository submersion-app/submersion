import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart'
    show contingenciesExpandedProvider, planEngineConfigProvider;
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/planner_results.dart';

void main() {
  late MockSettingsNotifier settings;

  ProviderContainer makeContainer({
    PlanResultRunner? runner,
    Duration settle = Duration.zero,
  }) {
    settings = MockSettingsNotifier();
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        planResultsSettleDelayProvider.overrideWithValue(settle),
        planResultRunnerProvider.overrideWithValue(
          runner ?? const IsolatePlanResultRunner(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> wait(Duration duration) => Future<void>.delayed(duration);

  test('a blank plan runs nothing', () async {
    final runner = CountingPlanResultRunner();
    final container = makeContainer(
      runner: runner,
      settle: const Duration(hours: 1),
    );
    container.read(contingenciesExpandedProvider.notifier).state = true;
    listenToAllPlanResults(container);

    final results = (await planSlateResults(container))!;

    expect(results.rangeTable, isNull);
    expect(results.deviations, isEmpty);
    expect(results.lostGas, isEmpty);
    expect(runner.runs, isEmpty);
  });

  test('a slate starts every unwatched result at once', () async {
    final runner = HeldPlanResultRunner();
    final container = makeContainer(runner: runner);
    loadPlan(container, ccrWithBailoutPlan());
    container.read(contingenciesExpandedProvider.notifier).state = true;

    final slate = planSlateResults(container);
    await wait(Duration.zero);
    expect(runner.held.map((run) => run.computation).toSet(), {
      computeDeviations,
      computeLostGas,
      computeRangeTable,
      computeBailout,
    });

    for (final run in [...runner.held]) {
      run.finish();
    }
    await slate;
  });

  group('planSlateResults', () {
    test('a slate straight after an edit carries the new figures', () async {
      final container = makeContainer(
        runner: CountingPlanResultRunner(),
        settle: const Duration(milliseconds: 20),
      );
      loadPlan(container, ccrWithBailoutPlan());
      container.read(contingenciesExpandedProvider.notifier).state = true;
      listenToAllPlanResults(container);
      final before = (await planSlateResults(container))!;

      editBottomTime(container, 2400);
      final after = (await planSlateResults(container))!;

      final state = container.read(divePlanNotifierProvider);
      final config = container.read(planEngineConfigProvider);
      final plan = planForEngine(state);
      final table = computeRangeTable(plan, null, config)!;
      final bailout = computeBailout(plan, null, config)!;
      final deviations = computeDeviations(plan, null, config);

      int runtime(RangeTable table) => table.baseCell!.outcome.runtimeSeconds;
      expect(runtime(after.rangeTable!), runtime(table));
      expect(runtime(after.rangeTable!), isNot(runtime(before.rangeTable!)));
      expect(
        after.bailout!.worstCase.litersRequired,
        bailout.worstCase.litersRequired,
      );
      expect(
        after.deviations.first.outcome.runtimeSeconds,
        deviations.first.outcome.runtimeSeconds,
      );
    });

    test('an edit during the wait carries through every figure', () async {
      final runner = HeldPlanResultRunner();
      final container = makeContainer(runner: runner);
      loadPlan(container, ccrWithBailoutPlan());
      container.read(contingenciesExpandedProvider.notifier).state = true;
      listenToAllPlanResults(container);
      await wait(Duration.zero);

      var finished = false;
      final slate = planSlateResults(
        container,
      ).whenComplete(() => finished = true);
      // The first figure lands, then the plan changes under the others.
      final first = runner.latest(computeDeviations);
      runner.held.remove(first);
      first.finish();
      await wait(Duration.zero);
      editBottomTime(container, 2400);
      listenToAllPlanResults(container);
      await wait(Duration.zero);

      for (var i = 0; i < 20 && !finished; i++) {
        for (final run in [...runner.held]) {
          runner.held.remove(run);
          run.finish();
        }
        await wait(Duration.zero);
      }
      final results = (await slate)!;

      final state = container.read(divePlanNotifierProvider);
      final config = container.read(planEngineConfigProvider);
      final plan = planForEngine(state);
      final direct = computeDeviations(plan, null, config);
      expect(
        results.deviations.first.outcome.runtimeSeconds,
        direct.first.outcome.runtimeSeconds,
      );
      expect(results.state.segments, state.segments);
      expect(
        results.outcome.runtimeSeconds,
        computeOutcomeForState(state, config: config).runtimeSeconds,
      );
    });

    /// Finishes every held run, as they appear, until [slate] is done.
    Future<void> drain(HeldPlanResultRunner runner, Future<void> slate) async {
      var finished = false;
      unawaited(slate.whenComplete(() => finished = true));
      for (var i = 0; i < 20 && !finished; i++) {
        for (final run in [...runner.held]) {
          runner.held.remove(run);
          run.finish();
        }
        await wait(Duration.zero);
      }
    }

    test(
      'a Settings change during the wait carries through every figure',
      () async {
        final runner = HeldPlanResultRunner();
        final container = makeContainer(runner: runner);
        loadPlan(container, ccrWithBailoutPlan());
        container.read(contingenciesExpandedProvider.notifier).state = true;
        listenToAllPlanResults(container);
        await wait(Duration.zero);

        final slate = planSlateResults(container);
        final first = runner.latest(computeDeviations);
        runner.held.remove(first);
        first.finish();
        await wait(Duration.zero);
        unawaited(settings.setPpO2MaxWorking(1.2));
        container.read(planDeviationsProvider);
        await wait(Duration.zero);
        await drain(runner, slate);
        final results = (await slate)!;

        expect(
          results.deviations,
          same(container.read(planDeviationsProvider).value!.value),
        );
      },
    );

    test(
      'opening contingencies during the wait carries them through',
      () async {
        final runner = HeldPlanResultRunner();
        final container = makeContainer(runner: runner);
        loadPlan(container, multiGasDecoPlan());
        listenToAllPlanResults(container);
        await wait(Duration.zero);

        final slate = planSlateResults(container);
        await wait(Duration.zero);
        container.read(contingenciesExpandedProvider.notifier).state = true;
        container.read(planDeviationsProvider);
        container.read(planLostGasProvider);
        await wait(Duration.zero);
        await drain(runner, slate);
        final results = (await slate)!;

        expect(results.deviations, isNotEmpty);
        expect(results.lostGas, isNotEmpty);
      },
    );

    test(
      'an edit while nothing is watching still finishes the slate',
      () async {
        final runner = HeldPlanResultRunner();
        final container = makeContainer(runner: runner);
        loadPlan(container, ccrWithBailoutPlan());

        var finished = false;
        final slate = planSlateResults(
          container,
        ).whenComplete(() => finished = true);
        await wait(Duration.zero);
        expect(runner.held, isNotEmpty);

        editBottomTime(container, 2400);
        await wait(Duration.zero);
        await drain(runner, slate);

        expect(finished, isTrue);
        await slate;
      },
    );

    test('leaving a replan during the wait gives no slate', () async {
      final runner = HeldPlanResultRunner();
      final container = makeContainer(runner: runner);
      loadPlan(container, ccrWithBailoutPlan());

      final slate = planSlateResults(container);
      await wait(Duration.zero);
      expect(runner.held, isNotEmpty);

      // What the canvas does to the app-wide plan as a replan closes.
      container.read(divePlanNotifierProvider.notifier).newPlan();
      await wait(Duration.zero);
      await drain(runner, slate);

      expect(await slate, isNull);
    });

    test('opening another plan during the wait gives no slate', () async {
      final runner = HeldPlanResultRunner();
      final container = makeContainer(runner: runner);
      loadPlan(container, ordinaryOcPlan());

      final slate = planSlateResults(container);
      await wait(Duration.zero);
      expect(runner.held, isNotEmpty);

      loadPlan(container, multiGasDecoPlan());
      await wait(Duration.zero);
      await drain(runner, slate);

      expect(await slate, isNull);
    });

    test('a failed result fails the slate', () async {
      final runner = HeldPlanResultRunner();
      final container = makeContainer(runner: runner);
      loadPlan(container, ccrWithBailoutPlan());
      listenToAllPlanResults(container);
      await wait(Duration.zero);

      final slate = planSlateResults(container);
      expect(runner.held, hasLength(2));
      runner.held[0].finish();
      runner.held[1].fail(StateError('engine'));

      await expectLater(slate, throwsStateError);
    });

    test('collapsed contingencies stay out of the slate', () async {
      final container = makeContainer(runner: CountingPlanResultRunner());
      loadPlan(container, multiGasDecoPlan());
      listenToAllPlanResults(container);

      final results = (await planSlateResults(container))!;

      expect(results.deviations, isEmpty);
      expect(results.lostGas, isEmpty);
      expect(results.rangeTable, isNotNull);
      expect(results.bailout, isNull);
    });
  });
}
