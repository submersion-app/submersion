// The ceiling and the schedule are computed from the same tissues, so they
// must agree: the schedule may never route the diver shallower than the
// ceiling standing at the moment it starts, and a stop the tissues require
// may never be dropped.
//
// Regression cover for the plan a diver reported (21 m for 30 min, then an
// hour at 10 m on air): the profile chart drew a ceiling from runtime 23 where
// other planners showed 37, and at runtime 110 the plan showed a 4.17 m
// ceiling whose only stop was at 3 m.
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

const _air = OpenCircuit(fO2: 0.21);

AscentGasPlan _airAscent() => FixedAscentGas(fN2: 0.79);

/// The reported profile, leg by leg: `[startDepth, endDepth, minutes]`.
const _reportedProfile = <List<double>>[
  [0, 21, 20],
  [21, 21, 30],
  [21, 10, 30],
  [10, 10, 30],
];

/// Tissue state after the first [legs] legs of [profile].
({TissueState state, double depth}) _run(
  BuhlmannGf model,
  List<List<double>> profile, {
  required int legs,
}) {
  var state = model.initial();
  var depth = 0.0;
  for (final leg in profile.take(legs)) {
    state = model.applySegment(
      state,
      DecoSegment(
        startDepth: leg[0],
        endDepth: leg[1],
        durationSeconds: (leg[2] * 60).round(),
      ),
      _air,
    );
    depth = leg[1];
  }
  return (state: state, depth: depth);
}

BuhlmannGf _model({double gfLow = 0.30, double gfHigh = 0.70}) => BuhlmannGf(
  gfLow: gfLow,
  gfHigh: gfHigh,
  environment: DiveEnvironment.standard,
);

/// [state] advanced by the ascent from [from] to [to] at 9 m/min, the way the
/// schedule travels to its first stop.
TissueState _ascendTo(
  BuhlmannGf model,
  TissueState state,
  double from,
  double to,
) => model.applySegment(
  state,
  DecoSegment(
    startDepth: from,
    endDepth: to,
    durationSeconds: ((from - to) / 9.0 * 60).round(),
  ),
  _air,
);

/// The schedule loads a travel leg as one step at its mean depth where
/// [BuhlmannGf.applySegment] slices it, so reconstructing an ascent here lands
/// a few centimetres away from what the scheduler saw. Well below the 3 m grid.
const _ascentReconstructionSlackM = 0.1;

void main() {
  group('the schedule respects the ceiling it reports', () {
    // The defect: the first stop is rounded up from the ceiling, but the
    // trial ascent then re-evaluated the gradient factor at the shallower
    // target depth, which cleared stops the ceiling said were needed. The
    // diver could be routed to a level above their own ceiling.
    //
    // Note the invariant is about ARRIVAL, not about the ceiling standing
    // when the schedule is computed. The ceiling is a "right now" number and
    // the ascent to the first stop takes real minutes of off-gassing, so a
    // first stop shallower than the current ceiling is legitimate; arriving
    // somewhere shallower than the ceiling is not.
    for (final gfHigh in const [0.70, 0.80, 0.85]) {
      test('the diver never arrives above the ceiling (GF 30/'
          '${(gfHigh * 100).round()})', () {
        final model = _model(gfHigh: gfHigh);

        for (var legs = 1; legs <= _reportedProfile.length; legs++) {
          final at = _run(model, _reportedProfile, legs: legs);
          final stops = model
              .schedule(at.state, currentDepth: at.depth, gases: _airAscent())
              .stops;
          if (stops.isEmpty) continue;

          final firstStop = stops.first.depthMeters;
          final arrival = _ascendTo(model, at.state, at.depth, firstStop);
          expect(
            model.ceilingMeters(arrival),
            lessThanOrEqualTo(firstStop + _ascentReconstructionSlackM),
            reason:
                'after $legs leg(s) the schedule sends the diver from '
                '${at.depth} m to $firstStop m, arriving with a ceiling of '
                '${model.ceilingMeters(arrival).toStringAsFixed(2)} m',
          );
        }
      });
    }

    test('a stop that clears inside its first minute is still recorded', () {
      // At runtime 50 the diver arrives at 9 m with a ceiling of ~6.6 m, so
      // 9 m is required -- but it clears in about a minute. The old loop
      // loaded a trial minute, tested after it, then reported zero minutes
      // and discarded the minute, deleting the stop outright.
      final model = _model();
      final at = _run(model, _reportedProfile, legs: 2);

      final stops = model
          .schedule(at.state, currentDepth: at.depth, gases: _airAscent())
          .stops;

      expect(stops.first.depthMeters, 9.0);
      expect(stops.first.durationSeconds, greaterThan(0));
    });

    test('the reported plan no longer contradicts itself at runtime 110', () {
      // The exact symptom: a 4.17 m ceiling whose only stop was 3 m. The
      // ascent from 10 m to 3 m is 47 seconds, nowhere near enough
      // off-gassing to justify it.
      final model = _model();
      final at = _run(model, _reportedProfile, legs: 4);
      final stops = model
          .schedule(at.state, currentDepth: at.depth, gases: _airAscent())
          .stops;

      expect(stops.map((s) => s.depthMeters), [3.0]);
      expect(model.ceilingMeters(at.state), lessThanOrEqualTo(3.0));
    });
  });

  group('the ceiling is a property of the tissues', () {
    test('scheduling from any depth honours the same ceiling', () {
      // The point of solving the gradient factor at the ceiling's own depth:
      // the ceiling is one number for a given set of tissues, and a schedule
      // started from any depth has to route around it.
      final model = _model();
      final at = _run(model, _reportedProfile, legs: 4);

      for (final from in const [10.0, 21.0, 40.0]) {
        final stops = model
            .schedule(at.state, currentDepth: from, gases: _airAscent())
            .stops;
        final firstStop = stops.first.depthMeters;
        final arrival = _ascendTo(model, at.state, from, firstStop);
        expect(
          model.ceilingMeters(arrival),
          lessThanOrEqualTo(firstStop + _ascentReconstructionSlackM),
          reason: 'scheduled from $from m to $firstStop m',
        );
      }
    });

    test('it is never shallower than the surface target', () {
      // GF-high is the most permissive gradient factor in the range, so the
      // interpolated ceiling can only ever sit at or below it.
      final model = _model();
      for (var legs = 1; legs <= _reportedProfile.length; legs++) {
        final at = _run(model, _reportedProfile, legs: legs);
        expect(
          model.ceilingMeters(at.state),
          greaterThanOrEqualTo(model.surfaceCeilingMeters(at.state)),
          reason: 'after $legs leg(s)',
        );
      }
    });
  });

  group('the surface target gates the planner chart', () {
    test('a GF ceiling exists before any deco is owed', () {
      // Runtime 20 on this profile: supersaturation has crossed the GF-low
      // line, so there is a gradient-factor ceiling, but a direct ascent is
      // still allowed. Drawing the former is what put a ceiling on the chart
      // 14 minutes early, so the two must stay distinguishable.
      final model = _model();
      final at = _run(model, _reportedProfile, legs: 1);

      expect(model.surfaceCeilingMeters(at.state), 0.0);
      expect(model.ceilingMeters(at.state), greaterThan(0));
    });

    test('once deco is owed, both are positive', () {
      final model = _model();
      final at = _run(model, _reportedProfile, legs: 2);

      expect(model.surfaceCeilingMeters(at.state), greaterThan(0));
      expect(model.ceilingMeters(at.state), greaterThan(0));
    });
  });

  group('deco onset matches the obligation', () {
    // The reported symptom. Walking the profile minute by minute, the first
    // minute that owes deco is the first minute a ceiling may be drawn. The
    // diver's other planner put that at 37 on GF-high 80.
    int onsetMinute({required double gfHigh}) {
      final model = _model(gfHigh: gfHigh);
      var state = model.initial();
      var minute = 0;
      for (final leg in _reportedProfile) {
        final total = (leg[2] * 60).round();
        final span = leg[1] - leg[0];
        for (var elapsed = 0; elapsed < total; elapsed += 60) {
          final from = leg[0] + span * (elapsed / total);
          final to = leg[0] + span * ((elapsed + 60) / total);
          state = model.applySegment(
            state,
            DecoSegment(startDepth: from, endDepth: to, durationSeconds: 60),
            _air,
          );
          minute++;
          if (model.surfaceCeilingMeters(state) > 0) return minute;
        }
      }
      return -1;
    }

    test('GF-high 80 puts onset at runtime 37', () {
      expect(onsetMinute(gfHigh: 0.80), 37);
    });

    test('a stricter GF-high brings onset earlier', () {
      expect(onsetMinute(gfHigh: 0.70), lessThan(onsetMinute(gfHigh: 0.80)));
      expect(onsetMinute(gfHigh: 0.85), greaterThan(onsetMinute(gfHigh: 0.80)));
    });
  });
}
