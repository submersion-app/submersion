import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/domain/services/plan_series_edits.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';

import 'series_fixtures.dart';

const _config = PlanEngineConfig();

/// A dive of a series replaced in the chain by what really happened (#3565).
void main() {
  final nine = DateTime.utc(2026, 10, 27, 9);

  PlanSeries series() {
    var s = PlanSeries.single(seriesDiveState().copyWith(startDateTime: nine));
    final ids = idSequence();
    s = appendDive(s, newId: ids);
    return appendDive(s, newId: ids);
  }

  /// The first dive dived for [minutes], starting at [start].
  SeriesFollow dived({
    DateTime? start,
    int minutes = 90,
    double otu = 77,
    double cns = 55,
    double endPressure = 60,
    double maxDepth = 42,
    GasMix gas = ean32,
  }) {
    final from = start ?? nine;
    final end = from.add(Duration(minutes: minutes));
    return SeriesFollow(
      loggedDives: [
        SeriesLoggedDive(
          id: 'logged',
          diveNumber: 214,
          start: from,
          end: end,
          endInstant: fromWallClockUtc(end),
          otu: otu,
          maxDepth: maxDepth,
        ),
      ],
      endTissues: computeOutcomeForState(
        seriesDiveState(depth: 42, bottomMinutes: 40),
        config: _config,
      ).surfacedTissue.compartments,
      endCns: cns,
      endTanks: [
        DiveTank(
          id: 'logged-back',
          volume: 12,
          startPressure: 232,
          endPressure: endPressure,
          gasMix: gas,
        ),
      ],
    );
  }

  PlanSeries withFirstDived(PlanSeries s, SeriesFollow actual) => s.copyWith(
    dives: [
      s.dives[0].copyWith(actual: actual),
      ...s.dives.skip(1),
    ],
  );

  List<SeriesDiveResult> compute(PlanSeries s) =>
      computeSeries(s.dives, config: _config);

  test('the next dive carries the real tissues and CNS', () {
    final planned = compute(series());
    final actual = dived();
    final results = compute(withFirstDived(series(), actual));

    expect(results[1].state.initialCns, 55);
    expect(results[1].state.initialTissueState, actual.endTissues);
    expect(results[1].state.initialCns, isNot(planned[1].state.initialCns));
  });

  test('the next dive starts from the real end', () {
    final results = compute(withFirstDived(series(), dived(minutes: 90)));

    expect(
      results[1].state.startDateTime,
      nine.add(const Duration(minutes: 90)).add(const Duration(hours: 1)),
    );
  });

  test('a fixed start keeps its time, and the interval gives', () {
    final start = nine.add(const Duration(hours: 5));
    final s = setDiveStart(series(), 1, start);

    final results = compute(withFirstDived(s, dived(minutes: 90)));

    expect(results[1].state.startDateTime, start);
    expect(
      results[1].state.surfaceInterval,
      const Duration(hours: 3, minutes: 30),
    );
  });

  test('the dives after that recalculate too', () {
    final plain = compute(series());
    final results = compute(withFirstDived(series(), dived()));

    expect(results[2].state.startDateTime, isNot(plain[2].state.startDateTime));
    expect(
      results[2].state.initialTissueState,
      isNot(plain[2].state.initialTissueState),
    );
  });

  test('tanks carry what was really left, by position and gas', () {
    final results = compute(withFirstDived(series(), dived(endPressure: 60)));

    expect(results[1].state.tanks[0].startPressure, 60);
  });

  test('a logged tank of another gas does not carry', () {
    final plain = compute(series());
    final results = compute(
      withFirstDived(series(), dived(endPressure: 60, gas: ean50)),
    );

    // The logged EAN50 is matched to the plan's stage, not its back gas.
    expect(results[1].state.tanks[1].startPressure, 60);
    expect(
      results[1].state.tanks[0].startPressure,
      isNot(60),
      reason: 'plain was ${plain[1].state.tanks[0].startPressure}',
    );
  });

  test('OTU counts the real dive', () {
    final results = compute(withFirstDived(series(), dived(otu: 77)));

    expect(results[1].state.initialOtu, 77);
  });

  test('a dive that has been dived starts when it really did', () {
    final start = nine.add(const Duration(minutes: 30));
    final results = compute(withFirstDived(series(), dived(start: start)));

    expect(results[0].state.startDateTime, start);
  });

  test('its plan is kept, and its own result still holds the plan', () {
    final plain = compute(series());
    final s = withFirstDived(series(), dived());
    final results = compute(s);

    expect(s.dives[0].state.startDateTime, nine);
    expect(results[0].outcome.runtimeSeconds, plain[0].outcome.runtimeSeconds);
    expect(results[0].actual, isNotNull);
  });

  test('a dive that has been dived has no warnings of its own', () {
    final start = DateTime.utc(2026, 10, 27, 8);
    final s = series();
    final later = s.copyWith(
      dives: [
        s.dives[0],
        s.dives[1].copyWith(actual: dived(start: start)),
        s.dives[2],
      ],
    );

    expect(compute(later)[1].seriesIssues, isEmpty);
  });

  test('a later dive is checked against the real depth', () {
    final results = compute(withFirstDived(series(), dived(maxDepth: 12)));

    expect(
      results[1].seriesIssues.map((i) => i.type),
      contains(PlanIssueType.reverseProfile),
    );
  });

  test('an out of order dive still carries from whichever is dived', () {
    final s = series();
    final b = dived(start: nine.add(const Duration(hours: 3)), cns: 44);
    final results = compute(
      s.copyWith(
        dives: [
          s.dives[0],
          s.dives[1].copyWith(actual: b),
          s.dives[2],
        ],
      ),
    );

    expect(results[2].state.initialCns, 44);
    expect(results[1].state.initialTissueState, isNotNull);
  });
}
