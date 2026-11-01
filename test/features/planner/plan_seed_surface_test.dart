import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';
import 'package:submersion/features/planner/domain/services/tissue_seed.dart';

import 'series/series_fixtures.dart';

const _gfLow = 0.40;
const _gfHigh = 0.80;
const _interval = Duration(hours: 1);

const _seaLevel = DiveEnvironment.standard;

/// Roughly the barometric pressure at 3,000 m.
const _altitude = DiveEnvironment(surfacePressureBar: 0.7);

List<TissueCompartment> _priorDive() {
  final algorithm = BuhlmannAlgorithm()
    ..calculateSegment(
      depthMeters: 40,
      durationSeconds: 25 * 60,
      fN2: airN2Fraction,
      fHe: 0.0,
    );
  return algorithm.compartments;
}

/// [compartments] after [_interval] breathing air at [surface].
List<TissueCompartment> _offGassed(
  List<TissueCompartment> compartments,
  DiveEnvironment surface,
) {
  final algorithm = BuhlmannAlgorithm(environment: surface)
    ..restoreState(compartments)
    ..calculateSegment(
      depthMeters: 0,
      durationSeconds: _interval.inSeconds,
      fN2: airN2Fraction,
      fHe: 0.0,
    );
  return algorithm.compartments;
}

BuhlmannState _seed({
  required DiveEnvironment plan,
  DiveEnvironment? followed,
}) {
  return seededTissueState(
        compartments: _priorDive(),
        surfaceInterval: _interval,
        gfLow: _gfLow,
        gfHigh: _gfHigh,
        environment: plan,
        followedEnvironment: followed,
      )!
      as BuhlmannState;
}

List<double> _tensions(List<TissueCompartment> compartments) => [
  for (final c in compartments) c.currentPN2,
];

void _expectTissues(
  List<TissueCompartment> actual,
  List<TissueCompartment> expected,
) {
  expect(
    _tensions(actual),
    pairwiseCompare<double, double>(
      _tensions(expected),
      (a, b) => (a - b).abs() < 1e-9,
      'within 1e-9 of',
    ),
  );
}

void main() {
  group('the surface a plan seed off-gasses at (#3925)', () {
    test('a plan at altitude after a dive at sea level waits at sea level', () {
      final seed = _seed(plan: _altitude, followed: _seaLevel);

      _expectTissues(seed.compartments, _offGassed(_priorDive(), _seaLevel));
    });

    test('a plan at sea level after a dive at altitude waits at sea level', () {
      final seed = _seed(plan: _seaLevel, followed: _altitude);

      _expectTissues(seed.compartments, _offGassed(_priorDive(), _seaLevel));
    });

    test('a plan at the followed dive\'s altitude waits at that altitude', () {
      final seed = _seed(plan: _altitude, followed: _altitude);

      _expectTissues(seed.compartments, _offGassed(_priorDive(), _altitude));
    });

    test('with no followed environment the plan\'s own surface stands', () {
      final seed = _seed(plan: _altitude);

      _expectTissues(seed.compartments, _offGassed(_priorDive(), _altitude));
    });

    test('the anchor is a depth in the plan\'s own environment, whichever '
        'surface the tissues waited at', () {
      final seed = _seed(plan: _altitude, followed: _seaLevel);

      final inPlan =
          BuhlmannAlgorithm(
              gfLow: _gfLow,
              gfHigh: _gfHigh,
              environment: _altitude,
            )
            ..restoreState(seed.compartments)
            ..deriveGfAnchorFromLoading();
      final atSeaLevel = BuhlmannAlgorithm(gfLow: _gfLow, gfHigh: _gfHigh)
        ..restoreState(seed.compartments)
        ..deriveGfAnchorFromLoading();

      expect(seed.gfLowCeilingAnchor, inPlan.gfLowCeilingAnchor);
      expect(
        seed.gfLowCeilingAnchor,
        greaterThan(atSeaLevel.gfLowCeilingAnchor),
      );
    });
  });

  group('startStateForPlan', () {
    const config = PlanEngineConfig();

    test('uses the environment the plan\'s tissues ended in', () {
      final start =
          startStateForPlan(
                seriesDiveState().copyWith(
                  altitude: 3000,
                  initialTissueState: _priorDive(),
                  initialTissueEnvironment: _seaLevel,
                  surfaceInterval: _interval,
                ),
                config: config,
              )!
              as BuhlmannState;

      _expectTissues(start.compartments, _offGassed(_priorDive(), _seaLevel));
    });

    test('off-gasses at the plan\'s surface when none was recorded', () {
      final state = seriesDiveState().copyWith(
        altitude: 3000,
        initialTissueState: _priorDive(),
        surfaceInterval: _interval,
      );
      final start = startStateForPlan(state, config: config)! as BuhlmannState;

      _expectTissues(
        start.compartments,
        _offGassed(_priorDive(), environmentForPlan(state)),
      );
    });
  });

  group('initialTissueEnvironment', () {
    test('goes with the tissues', () {
      final state = seriesDiveState().copyWith(
        initialTissueState: _priorDive(),
        initialTissueEnvironment: _altitude,
      );
      expect(state.initialTissueEnvironment, _altitude);

      final cleared = state.copyWith(clearInitialTissueState: true);

      expect(cleared.initialTissueState, isNull);
      expect(cleared.initialTissueEnvironment, isNull);
    });

    test('tells two plans apart', () {
      final state = seriesDiveState();

      expect(
        state.copyWith(initialTissueEnvironment: _altitude),
        isNot(state.copyWith(initialTissueEnvironment: _seaLevel)),
      );
    });
  });
}
