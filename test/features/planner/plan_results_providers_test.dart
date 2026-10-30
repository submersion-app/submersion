import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart'
    show
        ChartDisplayMode,
        chartDisplayModeProvider,
        contingenciesExpandedProvider,
        planEngineConfigProvider;
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/planner_results.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  void replace(AppSettings settings) => state = settings;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _air = GasMix(o2: 21);
const _ean50 = GasMix(o2: 50);
const _o2 = GasMix(o2: 100);
const _trimix = GasMix(o2: 18, he: 45);

List<PlanSegment> _profile(double depth, int minutes, String tank, GasMix mix) {
  return [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: depth,
      tankId: tank,
      gasMix: mix,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: minutes,
      tankId: tank,
      gasMix: mix,
      order: 1,
    ),
  ];
}

domain.DivePlan _plan({
  required String id,
  required List<DiveTank> tanks,
  required List<PlanSegment> segments,
  domain.PlanMode mode = domain.PlanMode.oc,
}) => domain.DivePlan(
  id: id,
  name: id,
  mode: mode,
  gfLow: 40,
  gfHigh: 80,
  tanks: tanks,
  segments: segments,
  createdAt: DateTime(2026, 10, 30),
  updatedAt: DateTime(2026, 10, 30),
);

domain.DivePlan _ordinaryOc({String id = 'oc'}) => _plan(
  id: id,
  tanks: const [
    DiveTank(id: 'back', volume: 24, startPressure: 232, gasMix: _air),
  ],
  segments: _profile(40, 20, 'back', _air),
);

domain.DivePlan _multiGasDeco() => _plan(
  id: 'deco',
  tanks: const [
    DiveTank(id: 'back', volume: 24, startPressure: 232, gasMix: _trimix),
    DiveTank(
      id: 'stage',
      volume: 11.1,
      startPressure: 207,
      gasMix: _ean50,
      role: TankRole.deco,
    ),
    DiveTank(
      id: 'oxygen',
      volume: 7,
      startPressure: 207,
      gasMix: _o2,
      role: TankRole.deco,
    ),
  ],
  segments: _profile(60, 25, 'back', _trimix),
);

domain.DivePlan _ccrWithBailout() => _plan(
  id: 'ccr',
  mode: domain.PlanMode.ccr,
  tanks: const [
    DiveTank(
      id: 'dil',
      volume: 3,
      startPressure: 200,
      gasMix: _trimix,
      role: TankRole.diluent,
    ),
    DiveTank(
      id: 'o2',
      volume: 3,
      startPressure: 200,
      gasMix: _o2,
      role: TankRole.oxygenSupply,
    ),
    DiveTank(
      id: 'bo',
      volume: 11.1,
      startPressure: 207,
      gasMix: _ean50,
      role: TankRole.bailout,
    ),
  ],
  segments: _profile(60, 25, 'dil', _trimix),
);

/// Counts each computation's runs, on the calling isolate.
class _CountingRunner extends InlinePlanResultRunner {
  final runs = <Object>[];

  int runsOf(Object computation) =>
      runs.where((run) => run == computation).length;

  @override
  Future<T> run<T>(
    PlanComputation<T> computation,
    domain.DivePlan plan,
    TissueState? startState,
    PlanEngineConfig config,
  ) {
    runs.add(computation);
    return super.run(computation, plan, startState, config);
  }
}

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
  late _TestSettingsNotifier settings;

  ProviderContainer makeContainer({
    PlanResultRunner? runner,
    Duration settle = Duration.zero,
  }) {
    settings = _TestSettingsNotifier();
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

  void load(ProviderContainer container, domain.DivePlan plan) {
    container
        .read(divePlanNotifierProvider.notifier)
        .loadPlan(stateFromDivePlan(plan));
  }

  /// Keeps all four providers alive, as a mounted sheet does.
  void listenToAll(ProviderContainer container) {
    container.listen(planRangeTableProvider, (_, _) {});
    container.listen(planBailoutProvider, (_, _) {});
    container.listen(planDeviationsProvider, (_, _) {});
    container.listen(planLostGasProvider, (_, _) {});
  }

  void editBottomTime(ProviderContainer container, int seconds) {
    final state = container.read(divePlanNotifierProvider);
    final bottom = state.segments.firstWhere((s) => s.id == 'bottom');
    container
        .read(divePlanNotifierProvider.notifier)
        .updateSegment(bottom.id, bottom.copyWith(durationSeconds: seconds));
  }

  Future<void> wait(Duration duration) => Future<void>.delayed(duration);

  group('results equal a direct call across a real isolate', () {
    Future<void> expectEqual(
      domain.DivePlan plan, {
      bool seeded = false,
    }) async {
      final container = makeContainer();
      load(container, plan);
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
      listenToAll(container);

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

    test('ordinary open circuit', () => expectEqual(_ordinaryOc()));
    test('multi-gas deco', () => expectEqual(_multiGasDeco()));
    test('CCR with bailout', () => expectEqual(_ccrWithBailout()));
    test(
      'a repetitive dive keeps its tissue seed',
      () => expectEqual(_multiGasDeco(), seeded: true),
    );
    test(
      'a repetitive CCR dive keeps its tissue seed',
      () => expectEqual(_ccrWithBailout(), seeded: true),
    );
  });

  test('a burst of edits runs each service once, after the settle', () {
    fakeAsync((async) {
      final runner = _CountingRunner();
      final container = makeContainer(
        runner: runner,
        settle: const Duration(milliseconds: 150),
      );
      load(container, _ccrWithBailout());
      container.read(contingenciesExpandedProvider.notifier).state = true;
      listenToAll(container);

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
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    load(container, _ordinaryOc());
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
    load(container, _ordinaryOc());
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
    final runner = _CountingRunner();
    final container = makeContainer(runner: runner);
    load(container, _ordinaryOc());
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
    load(container, _ordinaryOc());
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
    final runner = _CountingRunner();
    final container = makeContainer(runner: runner);
    load(container, _ordinaryOc());
    container.listen(planRangeTableProvider, (_, _) {});
    await container.read(planRangeTableProvider.future);
    expect(runner.runs, hasLength(1));

    settings.replace(settings.state.copyWith(ppO2MaxWorking: 1.2));
    final view = planResultView(container.read(planRangeTableProvider), 'oc');
    expect(view.status, PlanResultStatus.updating);
    await container.read(planRangeTableProvider.future);

    expect(runner.runs, hasLength(2));
  });

  test('another plan never shows the previous plan\'s value', () async {
    final runner = HeldPlanResultRunner();
    final container = makeContainer(runner: runner);
    load(container, _ordinaryOc());
    container.listen(planRangeTableProvider, (_, _) {});
    await wait(Duration.zero);
    runner.held.single.finish();
    await wait(Duration.zero);
    expect(
      planResultView(container.read(planRangeTableProvider), 'oc').value,
      isNotNull,
    );

    load(container, _multiGasDeco());
    final view = planResultView(container.read(planRangeTableProvider), 'deco');

    expect(view.value, isNull);
    expect(view.status, PlanResultStatus.calculating);
  });

  test('a blank plan runs nothing', () async {
    final runner = _CountingRunner();
    final container = makeContainer(
      runner: runner,
      settle: const Duration(hours: 1),
    );
    container.read(contingenciesExpandedProvider.notifier).state = true;
    listenToAll(container);

    final results = await planSlateResults(container);

    expect(results.rangeTable, isNull);
    expect(results.deviations, isEmpty);
    expect(results.lostGas, isEmpty);
    expect(runner.runs, isEmpty);
  });

  test('a plan the gate rejects runs no bailout', () async {
    final runner = _CountingRunner();
    final container = makeContainer(runner: runner);
    load(container, _ordinaryOc());
    container.listen(planBailoutProvider, (_, _) {});

    final bailout = await container.read(planBailoutProvider.future);

    expect(bailout.value, isNull);
    expect(runner.runs, isEmpty);
  });

  test('a slate starts every unwatched result at once', () async {
    final runner = HeldPlanResultRunner();
    final container = makeContainer(runner: runner);
    load(container, _ccrWithBailout());
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

  test('collapsed contingencies run nothing', () async {
    final runner = _CountingRunner();
    final container = makeContainer(runner: runner);
    load(container, _multiGasDeco());
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
      load(container, _ccrWithBailout());
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
      load(
        container,
        _ccrWithBailout().copyWith(
          id: 'surface',
          segments: [
            PlanSegment.hold(
              id: 'bottom',
              depth: 0,
              durationMinutes: 10,
              tankId: 'dil',
              gasMix: _trimix,
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

  group('planSlateResults', () {
    test('a slate straight after an edit carries the new figures', () async {
      final container = makeContainer(
        runner: _CountingRunner(),
        settle: const Duration(milliseconds: 20),
      );
      load(container, _ccrWithBailout());
      container.read(contingenciesExpandedProvider.notifier).state = true;
      listenToAll(container);
      final before = await planSlateResults(container);

      editBottomTime(container, 2400);
      final after = await planSlateResults(container);

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
      load(container, _ccrWithBailout());
      container.read(contingenciesExpandedProvider.notifier).state = true;
      listenToAll(container);
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
      listenToAll(container);
      await wait(Duration.zero);

      for (var i = 0; i < 20 && !finished; i++) {
        for (final run in [...runner.held]) {
          runner.held.remove(run);
          run.finish();
        }
        await wait(Duration.zero);
      }
      final results = await slate;

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
        load(container, _ccrWithBailout());
        container.read(contingenciesExpandedProvider.notifier).state = true;
        listenToAll(container);
        await wait(Duration.zero);

        final slate = planSlateResults(container);
        final first = runner.latest(computeDeviations);
        runner.held.remove(first);
        first.finish();
        await wait(Duration.zero);
        settings.replace(settings.state.copyWith(ppO2MaxWorking: 1.2));
        container.read(planDeviationsProvider);
        await wait(Duration.zero);
        await drain(runner, slate);
        final results = await slate;

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
        load(container, _multiGasDeco());
        listenToAll(container);
        await wait(Duration.zero);

        final slate = planSlateResults(container);
        await wait(Duration.zero);
        container.read(contingenciesExpandedProvider.notifier).state = true;
        container.read(planDeviationsProvider);
        container.read(planLostGasProvider);
        await wait(Duration.zero);
        await drain(runner, slate);
        final results = await slate;

        expect(results.deviations, isNotEmpty);
        expect(results.lostGas, isNotEmpty);
      },
    );

    test(
      'an edit while nothing is watching still finishes the slate',
      () async {
        final runner = HeldPlanResultRunner();
        final container = makeContainer(runner: runner);
        load(container, _ccrWithBailout());

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

    test('a failed result fails the slate', () async {
      final runner = HeldPlanResultRunner();
      final container = makeContainer(runner: runner);
      load(container, _ccrWithBailout());
      listenToAll(container);
      await wait(Duration.zero);

      final slate = planSlateResults(container);
      expect(runner.held, hasLength(2));
      runner.held[0].finish();
      runner.held[1].fail(StateError('engine'));

      await expectLater(slate, throwsStateError);
    });

    test('collapsed contingencies stay out of the slate', () async {
      final container = makeContainer(runner: _CountingRunner());
      load(container, _multiGasDeco());
      listenToAll(container);

      final results = await planSlateResults(container);

      expect(results.deviations, isEmpty);
      expect(results.lostGas, isEmpty);
      expect(results.rangeTable, isNotNull);
      expect(results.bailout, isNull);
    });
  });

  test('planMayHaveBailoutProvider follows the plan', () {
    final container = makeContainer();
    load(container, _ordinaryOc());
    expect(container.read(planMayHaveBailoutProvider), isFalse);

    load(container, _ccrWithBailout());
    expect(container.read(planMayHaveBailoutProvider), isTrue);
  });
}
