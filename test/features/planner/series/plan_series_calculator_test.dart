import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/domain/services/plan_series_edits.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';

import 'series_fixtures.dart';

const _config = PlanEngineConfig();

PlanSeries _series(List<DivePlanState> states) {
  final ids = idSequence();
  var series = PlanSeries.single(states.first);
  for (final state in states.skip(1)) {
    series = appendDive(series, newId: ids);
    final added = series.dives.last;
    // Keep the appended dive's ids and tank links, take the test's profile.
    final tanks = [
      for (var i = 0; i < added.state.tanks.length; i++)
        state.tanks[i].copyWith(id: added.state.tanks[i].id),
    ];
    series = updateDiveState(
      series,
      series.dives.length - 1,
      added.state.copyWith(
        surfaceInterval: state.surfaceInterval,
        tanks: tanks,
        segments: [
          for (final segment in state.segments)
            segment.copyWith(tankId: tanks.first.id),
        ],
      ),
      pinTypedPressures: false,
    );
  }
  return series;
}

double _ownOtu(SeriesDiveResult result) =>
    result.outcome.otuTotal - (result.state.initialOtu ?? 0);

void main() {
  group('computeSeries', () {
    test('a single dive computes exactly as the plan on its own', () {
      final state = seriesDiveState();
      final results = computeSeries(
        PlanSeries.single(state).dives,
        config: _config,
      );
      final alone = computeOutcomeForState(state, config: _config);

      expect(results, hasLength(1));
      expect(results.single.state, state);
      expect(results.single.outcome.cnsEnd, alone.cnsEnd);
      expect(results.single.outcome.runtimeSeconds, alone.runtimeSeconds);
    });

    test('the next dive starts from the previous dive\'s tissues', () {
      final results = computeSeries(
        _series([seriesDiveState(), seriesDiveState(id: 'dive-b')]).dives,
        config: _config,
      );
      final fresh = computeOutcomeForState(
        seriesDiveState(id: 'dive-b'),
        config: _config,
      );

      // As they were on surfacing, after the ascent and its stops, not as
      // they were at the end of the bottom.
      expect(results[0].outcome.stops, isNotEmpty);
      expect(
        results[1].state.initialTissueState,
        results[0].outcome.surfacedTissue.compartments,
      );
      expect(
        results[1].state.initialTissueState,
        isNot(results[0].outcome.endTissue.compartments),
      );
      expect(
        results[1].outcome.totalDecoSeconds,
        greaterThan(fresh.totalDecoSeconds),
      );
    });

    test('the next dive off-gasses the previous dive\'s tissues at the higher '
        'of the two surfaces', () {
      final atSeaLevel = _series([
        seriesDiveState(),
        seriesDiveState(
          id: 'dive-b',
          surfaceInterval: const Duration(hours: 1),
        ),
      ]);
      final upTheMountain = updateDiveState(
        atSeaLevel,
        1,
        atSeaLevel.dives[1].state.copyWith(altitude: 3000),
        pinTypedPressures: false,
      );

      final results = computeSeries(upTheMountain.dives, config: _config);

      expect(
        results[1].state.initialTissueEnvironment,
        environmentForPlan(results[0].state),
      );
      final offGassed =
          startStateForPlan(
                results[1].state.copyWith(altitude: 0),
                config: _config,
              )!
              as BuhlmannState;
      final seeded =
          startStateForPlan(results[1].state, config: _config)!
              as BuhlmannState;
      expect(
        [for (final c in seeded.compartments) c.currentPN2],
        [for (final c in offGassed.compartments) c.currentPN2],
      );
    });

    test('the next dive starts from the previous dive\'s end CNS', () {
      final results = computeSeries(
        _series([seriesDiveState(), seriesDiveState(id: 'dive-b')]).dives,
        config: _config,
      );
      final fresh = computeOutcomeForState(
        seriesDiveState(id: 'dive-b'),
        config: _config,
      );

      expect(results[1].state.initialCns, results[0].outcome.cnsEnd);
      expect(results[1].outcome.cnsEnd, greaterThan(fresh.cnsEnd));
    });

    test('OTU from dives in the last 24 hours carries to the next dive', () {
      final results = computeSeries(
        _series([seriesDiveState(), seriesDiveState(id: 'dive-b')]).dives,
        config: _config,
      );
      expect(results[1].state.initialOtu, closeTo(_ownOtu(results[0]), 1e-9));
    });

    test('a surface interval of 24 hours or more drops the OTU', () {
      final results = computeSeries(
        _series([
          seriesDiveState(),
          seriesDiveState(
            id: 'dive-b',
            surfaceInterval: const Duration(hours: 24),
          ),
        ]).dives,
        config: _config,
      );
      expect(results[1].state.initialOtu, 0);
    });

    test('OTU drops dives that ended 24 hours or more before the start', () {
      final results = computeSeries(
        _series([
          seriesDiveState(),
          seriesDiveState(
            id: 'dive-b',
            surfaceInterval: const Duration(hours: 20),
          ),
          seriesDiveState(
            id: 'dive-c',
            surfaceInterval: const Duration(hours: 5),
          ),
        ]).dives,
        config: _config,
      );
      // Dive A ended over 24 h before C starts; B ended 5 h before.
      expect(results[2].state.initialOtu, closeTo(_ownOtu(results[1]), 1e-9));
    });

    test('each tank starts at its source tank\'s end pressure', () {
      final results = computeSeries(
        _series([seriesDiveState(), seriesDiveState(id: 'dive-b')]).dives,
        config: _config,
      );
      final firstUsage = results[0].outcome.tankUsages.firstWhere(
        (u) => u.tankId == results[0].state.tanks.first.id,
      );
      expect(
        results[1].state.tanks.first.startPressure,
        closeTo(firstUsage.remainingPressure!, 1e-9),
      );
    });

    test('a pinned tank keeps the pressure the diver gave it', () {
      final series = _series([
        seriesDiveState(),
        seriesDiveState(id: 'dive-b'),
      ]);
      final filled = fillTank(series, 1, series.dives[1].state.tanks.first.id);
      final results = computeSeries(filled.dives, config: _config);
      expect(results[1].state.tanks.first.startPressure, 232);
    });

    test('editing an earlier dive changes the dives after it', () {
      final shallow = computeSeries(
        _series([seriesDiveState(), seriesDiveState(id: 'dive-b')]).dives,
        config: _config,
      );
      final deep = computeSeries(
        _series([
          seriesDiveState(depth: 40),
          seriesDiveState(id: 'dive-b'),
        ]).dives,
        config: _config,
      );
      expect(deep[1].outcome.cnsEnd, greaterThan(shallow[1].outcome.cnsEnd));
      expect(
        deep[1].outcome.totalDecoSeconds,
        greaterThan(shallow[1].outcome.totalDecoSeconds),
      );
    });

    test('a first dive keeps the followed dive\'s seed it was given', () {
      final state = seriesDiveState().copyWith(initialCns: 50);
      final results = computeSeries(
        PlanSeries.single(state).dives,
        config: _config,
      );
      expect(results.single.state.initialCns, 50);
    });
  });

  group('carriedState', () {
    test('seeds one dive from the results of the dives before it', () {
      final series = _series([
        seriesDiveState(),
        seriesDiveState(id: 'dive-b'),
      ]);
      final results = computeSeries(series.dives, config: _config);
      final seeded = carriedState(series.dives, 1, results.sublist(0, 1));
      expect(seeded, results[1].state);
    });
  });
}
