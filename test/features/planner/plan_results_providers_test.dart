import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart'
    show
        ChartDisplayMode,
        chartDisplayModeProvider,
        contingenciesExpandedProvider,
        planEngineConfigProvider,
        planLiveCanvasSeriesProvider;
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/planner_results.dart';

/// What must match between two outcomes for them to be the same answer.
List<Object?> _fingerprint(PlanOutcome outcome) => [
  outcome.runtimeSeconds,
  outcome.ttsAtBottom,
  outcome.ndlAtBottom,
  outcome.cnsEnd,
  outcome.otuTotal,
  for (final stop in outcome.stops) ...[stop.depthMeters, stop.durationSeconds],
  for (final usage in outcome.tankUsages) ...[usage.tankId, usage.litersUsed],
];

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

  group('results equal a direct call across a real isolate', () {
    Future<void> expectEqual(
      domain.DivePlan plan, {
      bool seeded = false,
    }) async {
      final container = makeContainer();
      loadPlan(container, plan);
      if (seeded) {
        final prior = BuhlmannAlgorithm(gfLow: 0.40, gfHigh: 0.80)
          ..calculateSegment(depthMeters: 40.0, durationSeconds: 40 * 60);
        container
            .read(divePlanNotifierProvider.notifier)
            .setFollowedDive(
              diveId: 'prior',
              compartments: prior.compartments,
              surfaceInterval: const Duration(minutes: 30),
            );
      }
      container.read(contingenciesExpandedProvider.notifier).state = true;
      listenToAllPlanResults(container);

      final state = container.read(divePlanNotifierProvider);
      final config = container.read(planEngineConfigProvider);
      final input = planForEngine(state);
      final start = startStateForPlan(state, config: config);
      expect(start != null, seeded);

      final rangeTable = await container.read(planRangeTableProvider.future);
      final directTable = computeRangeTable(input, start, config)!;
      expect(rangeTable.planId, plan.id);
      final cells = rangeTable.value!.cells;
      expect(cells.length, directTable.cells.length);
      for (var row = 0; row < cells.length; row++) {
        for (var column = 0; column < cells[row].length; column++) {
          final cell = cells[row][column];
          final direct = directTable.cells[row][column];
          expect(cell == null, direct == null);
          if (cell == null) continue;
          expect(_fingerprint(cell.outcome), _fingerprint(direct!.outcome));
        }
      }

      final bailout = await container.read(planBailoutProvider.future);
      final directBailout = computeBailout(input, start, config);
      expect(bailout.value == null, directBailout == null);
      if (directBailout != null) {
        final worst = bailout.value!.worstCase;
        expect(worst.runtimeSeconds, directBailout.worstCase.runtimeSeconds);
        expect(worst.depthMeters, directBailout.worstCase.depthMeters);
        expect(worst.ttsSeconds, directBailout.worstCase.ttsSeconds);
        expect(worst.litersRequired, directBailout.worstCase.litersRequired);
        expect(bailout.value!.availableLiters, directBailout.availableLiters);
        expect(bailout.value!.sufficient, directBailout.sufficient);
      }

      final deviations = await container.read(planDeviationsProvider.future);
      final directDeviations = computeDeviations(input, start, config);
      expect(deviations.value.length, directDeviations.length);
      expect(deviations.value, isNotEmpty);
      for (var i = 0; i < directDeviations.length; i++) {
        expect(deviations.value[i].key, directDeviations[i].key);
        expect(
          _fingerprint(deviations.value[i].outcome),
          _fingerprint(directDeviations[i].outcome),
        );
      }

      final lostGas = await container.read(planLostGasProvider.future);
      final directLostGas = computeLostGas(input, start, config);
      expect(lostGas.value.length, directLostGas.length);
      for (var i = 0; i < directLostGas.length; i++) {
        expect(lostGas.value[i].tank.id, directLostGas[i].tank.id);
        expect(
          _fingerprint(lostGas.value[i].outcome),
          _fingerprint(directLostGas[i].outcome),
        );
      }
    }

    test('ordinary open circuit', () => expectEqual(ordinaryOcPlan()));
    test('multi-gas deco', () => expectEqual(multiGasDecoPlan()));
    test('CCR with bailout', () => expectEqual(ccrWithBailoutPlan()));
    test(
      'a repetitive dive keeps its tissue seed',
      () => expectEqual(multiGasDecoPlan(), seeded: true),
    );
    test(
      'a repetitive CCR dive keeps its tissue seed',
      () => expectEqual(ccrWithBailoutPlan(), seeded: true),
    );
  });

  test('a burst of edits runs each service once, after the settle', () {
    fakeAsync((async) {
      final runner = CountingPlanResultRunner();
      final container = makeContainer(
        runner: runner,
        settle: const Duration(milliseconds: 150),
      );
      loadPlan(container, ccrWithBailoutPlan());
      container.read(contingenciesExpandedProvider.notifier).state = true;
      listenToAllPlanResults(container);

      for (var i = 1; i <= 30; i++) {
        editBottomTime(container, 1500 + i * 15);
        container.read(planRangeTableProvider);
        container.read(planBailoutProvider);
        container.read(planDeviationsProvider);
        container.read(planLostGasProvider);
        async.elapse(const Duration(milliseconds: 16));
      }
      expect(runner.runs, isEmpty);
      // Superseded edits leave nothing behind to fire.
      expect(async.pendingTimers, hasLength(4));

      async.elapse(const Duration(milliseconds: 150));
      expect(runner.runsOf(computeRangeTable), 1);
      expect(runner.runsOf(computeBailout), 1);
      expect(runner.runsOf(computeDeviations), 1);
      expect(runner.runsOf(computeLostGas), 1);
    });
  });

  test('by default results settle for 150 ms and run on an isolate', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    loadPlan(container, ordinaryOcPlan());
    container.listen(planRangeTableProvider, (_, _) {});

    expect(
      container.read(planResultsSettleDelayProvider),
      const Duration(milliseconds: 150),
    );
    expect(
      container.read(planResultRunnerProvider),
      isA<IsolatePlanResultRunner>(),
    );
    final table = await container.read(planRangeTableProvider.future);
    expect(table.value, isNotNull);
  });

  test('a superseded run never delivers', () async {
    final runner = HeldPlanResultRunner();
    final container = makeContainer(runner: runner);
    loadPlan(container, ordinaryOcPlan());
    container.listen(planRangeTableProvider, (_, _) {});
    await wait(Duration.zero);
    expect(runner.held, hasLength(1));

    editBottomTime(container, 1800);
    container.read(planRangeTableProvider);
    await wait(Duration.zero);
    expect(runner.held, hasLength(2));

    // The newer run lands first, then the older one tries to.
    runner.held[1].finish();
    await wait(Duration.zero);
    final newer = container.read(planRangeTableProvider).value;
    runner.held[0].finish();
    await wait(Duration.zero);

    expect(container.read(planRangeTableProvider).value, same(newer));
  });

  test('a rename runs nothing', () async {
    final runner = CountingPlanResultRunner();
    final container = makeContainer(runner: runner);
    loadPlan(container, ordinaryOcPlan());
    container.listen(planRangeTableProvider, (_, _) {});
    await container.read(planRangeTableProvider.future);
    expect(runner.runs, hasLength(1));

    container.read(divePlanNotifierProvider.notifier).updateName('Renamed');
    container.read(planRangeTableProvider);
    await wait(Duration.zero);

    expect(runner.runs, hasLength(1));
  });

  test('a failed run recovers on the next edit', () async {
    final runner = HeldPlanResultRunner();
    final container = makeContainer(runner: runner);
    loadPlan(container, ordinaryOcPlan());
    container.listen(planRangeTableProvider, (_, _) {});
    await wait(Duration.zero);

    runner.held.single.fail(StateError('engine'));
    await wait(Duration.zero);
    expect(
      planResultView(container.read(planRangeTableProvider), 'oc').status,
      PlanResultStatus.failed,
    );

    editBottomTime(container, 1800);
    expect(
      planResultView(container.read(planRangeTableProvider), 'oc').status,
      PlanResultStatus.calculating,
    );
    await wait(Duration.zero);
    runner.held.last.finish();
    await wait(Duration.zero);

    final view = planResultView(container.read(planRangeTableProvider), 'oc');
    expect(view.status, PlanResultStatus.current);
    expect(view.value, isNotNull);
  });

  test('a Settings change recomputes, as an edit does', () async {
    final runner = CountingPlanResultRunner();
    final container = makeContainer(runner: runner);
    loadPlan(container, ordinaryOcPlan());
    container.listen(planRangeTableProvider, (_, _) {});
    await container.read(planRangeTableProvider.future);
    expect(runner.runs, hasLength(1));

    unawaited(settings.setPpO2MaxWorking(1.2));
    final view = planResultView(container.read(planRangeTableProvider), 'oc');
    expect(view.status, PlanResultStatus.updating);
    await container.read(planRangeTableProvider.future);

    expect(runner.runs, hasLength(2));
  });

  test('a surface interval change recomputes, as an edit does', () async {
    final runner = CountingPlanResultRunner();
    final container = makeContainer(runner: runner);
    loadPlan(container, ordinaryOcPlan());
    container.listen(planRangeTableProvider, (_, _) {});
    await container.read(planRangeTableProvider.future);
    expect(runner.runs, hasLength(1));

    container
        .read(divePlanNotifierProvider.notifier)
        .setSurfaceInterval(const Duration(hours: 2));
    await container.read(planRangeTableProvider.future);

    expect(runner.runs, hasLength(2));
  });

  test('another plan never shows the previous plan\'s value', () async {
    final runner = HeldPlanResultRunner();
    final container = makeContainer(runner: runner);
    loadPlan(container, ordinaryOcPlan());
    container.listen(planRangeTableProvider, (_, _) {});
    await wait(Duration.zero);
    runner.held.single.finish();
    await wait(Duration.zero);
    expect(
      planResultView(container.read(planRangeTableProvider), 'oc').value,
      isNotNull,
    );

    loadPlan(container, multiGasDecoPlan());
    final view = planResultView(container.read(planRangeTableProvider), 'deco');

    expect(view.value, isNull);
    expect(view.status, PlanResultStatus.calculating);
  });

  test('a plan the gate rejects runs no bailout', () async {
    final runner = CountingPlanResultRunner();
    final container = makeContainer(runner: runner);
    loadPlan(container, ordinaryOcPlan());
    container.listen(planBailoutProvider, (_, _) {});

    final bailout = await container.read(planBailoutProvider.future);

    expect(bailout.value, isNull);
    expect(runner.runs, isEmpty);
  });

  test('collapsed contingencies run nothing', () async {
    final runner = CountingPlanResultRunner();
    final container = makeContainer(runner: runner);
    loadPlan(container, multiGasDecoPlan());
    container.listen(planDeviationsProvider, (_, _) {});
    container.listen(planLostGasProvider, (_, _) {});

    final deviations = await container.read(planDeviationsProvider.future);
    final lostGas = await container.read(planLostGasProvider.future);

    expect(deviations.value, isEmpty);
    expect(lostGas.value, isEmpty);
    expect(runner.runs, isEmpty);
  });

  group('planChartBailoutProvider', () {
    late HeldPlanResultRunner runner;
    late ProviderContainer container;

    /// A CCR plan in Bailout view, with the chart's provider being listened
    /// to as a mounted chart does. One run is held, for the first result.
    Future<void> openInBailoutView() async {
      runner = HeldPlanResultRunner();
      container = makeContainer(runner: runner);
      loadPlan(container, ccrWithBailoutPlan());
      container.read(chartDisplayModeProvider.notifier).state =
          ChartDisplayMode.bailout;
      container.listen(planChartBailoutProvider, (_, _) {});
      await wait(Duration.zero);
    }

    Future<void> landFirstResult() async {
      runner.held.single.finish();
      await wait(Duration.zero);
    }

    test('nothing outside Bailout view', () async {
      await openInBailoutView();
      container.read(chartDisplayModeProvider.notifier).state =
          ChartDisplayMode.ccr;

      final chart = container.read(planChartBailoutProvider);
      expect(chart.picture, isNull);
      expect(chart.status, isNull);
    });

    test('a current result draws with no status', () async {
      await openInBailoutView();
      await landFirstResult();

      final chart = container.read(planChartBailoutProvider);
      expect(chart.picture, isNotNull);
      expect(chart.status, isNull);
    });

    test('a newer result pending keeps the last picture', () async {
      await openInBailoutView();
      await landFirstResult();
      final picture = container.read(planChartBailoutProvider).picture;

      editBottomTime(container, 1800);

      final chart = container.read(planChartBailoutProvider);
      expect(chart.picture, same(picture));
      expect(chart.status, PlanResultStatus.updating);
    });

    test('a status change alone keeps the series', () async {
      await openInBailoutView();
      await landFirstResult();
      container.listen(planCanvasSeriesProvider, (_, _) {});
      final series = container.read(planCanvasSeriesProvider);

      editBottomTime(container, 1800);

      expect(
        container.read(planChartBailoutProvider).status,
        PlanResultStatus.updating,
      );
      expect(container.read(planCanvasSeriesProvider), same(series));
    });

    test('the live series follows an edit made in Bailout view', () async {
      await openInBailoutView();
      await landFirstResult();
      final series = container.read(planLiveCanvasSeriesProvider);

      editBottomTime(container, 3600);

      expect(
        container.read(planLiveCanvasSeriesProvider).maxTimeSeconds,
        greaterThan(series.maxTimeSeconds),
      );
    });

    test('a first result pending draws the live plan', () async {
      await openInBailoutView();

      final chart = container.read(planChartBailoutProvider);
      expect(chart.picture, isNull);
      expect(chart.status, PlanResultStatus.calculating);
    });

    test('a failure with no older value draws the live plan', () async {
      await openInBailoutView();
      runner.held.single.fail(StateError('engine'));
      await wait(Duration.zero);

      final chart = container.read(planChartBailoutProvider);
      expect(chart.picture, isNull);
      expect(chart.status, PlanResultStatus.failed);
    });

    test('a failure drops an older picture too', () async {
      await openInBailoutView();
      await landFirstResult();
      editBottomTime(container, 1800);
      container.read(planChartBailoutProvider);
      await wait(Duration.zero);
      runner.held.last.fail(StateError('engine'));
      await wait(Duration.zero);

      final chart = container.read(planChartBailoutProvider);
      expect(chart.picture, isNull);
      expect(chart.status, PlanResultStatus.failed);
    });

    test('a finished null result draws the live plan, unlabelled', () async {
      await openInBailoutView();
      loadPlan(
        container,
        ccrWithBailoutPlan().copyWith(
          id: 'surface',
          segments: [
            PlanSegment.hold(
              id: 'bottom',
              depth: 0,
              durationMinutes: 10,
              tankId: 'dil',
              gasMix: plannerTrimix,
              order: 0,
            ),
          ],
        ),
      );
      container.read(chartDisplayModeProvider.notifier).state =
          ChartDisplayMode.bailout;
      container.read(planChartBailoutProvider);
      await wait(Duration.zero);
      runner.held.last.finish();
      await wait(Duration.zero);

      final chart = container.read(planChartBailoutProvider);
      expect(chart.picture, isNull);
      expect(chart.status, isNull);
    });

    test('removing the last bailout tank drops the picture at once', () async {
      await openInBailoutView();
      await landFirstResult();
      expect(container.read(planChartBailoutProvider).picture, isNotNull);

      container.read(divePlanNotifierProvider.notifier).removeTank('bo');

      final chart = container.read(planChartBailoutProvider);
      expect(chart.picture, isNull);
      expect(chart.status, isNull);
    });
  });

  test('planMayHaveBailoutProvider follows the plan', () {
    final container = makeContainer();
    loadPlan(container, ordinaryOcPlan());
    expect(container.read(planMayHaveBailoutProvider), isFalse);

    loadPlan(container, ccrWithBailoutPlan());
    expect(container.read(planMayHaveBailoutProvider), isTrue);
  });
}
