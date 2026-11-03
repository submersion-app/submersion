import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/domain/services/plan_series_edits.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';

import 'series_fixtures.dart';

const _config = PlanEngineConfig();

PlanSeries _two({
  double firstDepth = 30,
  double secondDepth = 30,
  int firstMinutes = 25,
  Duration interval = const Duration(hours: 1),
  DateTime? start,
}) {
  var series = PlanSeries.single(
    seriesDiveState(
      depth: firstDepth,
      bottomMinutes: firstMinutes,
    ).copyWith(startDateTime: start),
  );
  series = appendDive(series, newId: idSequence());
  final b = series.dives[1].state;
  final second = seriesDiveState(depth: secondDepth);
  return updateDiveState(
    series,
    1,
    b.copyWith(
      surfaceInterval: interval,
      segments: [
        for (final (i, segment) in second.segments.indexed)
          segment.copyWith(id: b.segments[i].id, tankId: b.segments[i].tankId),
      ],
    ),
    pinTypedPressures: false,
  );
}

/// Tissues at the end of a long deep bottom time, before any ascent.
List<TissueCompartment> _heavyLoad() => computeOutcomeForState(
  seriesDiveState(depth: 50, bottomMinutes: 60),
  config: _config,
).endTissue.compartments;

/// A first dive straight after a logged dive that surfaced with that load.
PlanSeries _followingHeavyLoad() =>
    PlanSeries.single(
      seriesDiveState(surfaceInterval: const Duration(minutes: 1)),
    ).copyWith(
      follow: SeriesFollow(
        loggedDives: [seriesLoggedDive('d1', DateTime(2026, 10, 27, 8))],
        endTissues: _heavyLoad(),
      ),
    );

Iterable<PlanIssueType> _types(SeriesDiveResult result) =>
    result.seriesIssues.map((issue) => issue.type);

void main() {
  List<SeriesDiveResult> compute(PlanSeries series) =>
      computeSeries(series.dives, config: _config, follow: series.follow);

  group('series warnings', () {
    test('an ordinary follow-on dive has none', () {
      final results = compute(_two());
      expect(results[0].seriesIssues, isEmpty);
      expect(results[1].seriesIssues, isEmpty);
    });

    test('a first dive following nothing has none', () {
      final results = compute(_two(interval: Duration.zero));
      expect(results[0].seriesIssues, isEmpty);
    });

    test('a surface interval under 10 minutes warns', () {
      final results = compute(
        _two(interval: const Duration(minutes: 9), firstMinutes: 5),
      );
      final issue = results[1].seriesIssues.firstWhere(
        (i) => i.type == PlanIssueType.shortSurfaceInterval,
      );
      expect(issue.severity, PlanIssueSeverity.warning);
      expect(issue.value, 9);
    });

    test('exactly 10 minutes does not', () {
      final results = compute(
        _two(interval: const Duration(minutes: 10), firstMinutes: 5),
      );
      expect(
        _types(results[1]),
        isNot(contains(PlanIssueType.shortSurfaceInterval)),
      );
    });

    test('a start before the previous dive ends is critical', () {
      final start = DateTime.utc(2026, 10, 27, 9);
      final series = setDiveStart(
        _two(start: start),
        1,
        start.add(const Duration(minutes: 5)),
      );

      final results = compute(series);

      final issue = results[1].seriesIssues.firstWhere(
        (i) => i.type == PlanIssueType.startsBeforePreviousEnds,
      );
      expect(issue.severity, PlanIssueSeverity.critical);
      expect(issue.value, greaterThan(0));
      // Not also reported as a short interval: it has none.
      expect(
        _types(results[1]),
        isNot(contains(PlanIssueType.shortSurfaceInterval)),
      );
    });

    test('a planned dive before it cannot leave deco owed: stops clear it', () {
      final results = compute(
        _two(firstMinutes: 60, firstDepth: 50, interval: Duration.zero),
      );
      expect(
        _types(results[1]),
        isNot(contains(PlanIssueType.startsOwingDeco)),
      );
    });

    test('a followed dive that left deco owed is critical', () {
      final issue = compute(_followingHeavyLoad()).single.seriesIssues
          .firstWhere((i) => i.type == PlanIssueType.startsOwingDeco);
      expect(issue.severity, PlanIssueSeverity.critical);
    });

    test('a dive deeper than the one before warns of a reverse profile', () {
      final results = compute(_two(firstDepth: 15, secondDepth: 30));
      final issue = results[1].seriesIssues.firstWhere(
        (i) => i.type == PlanIssueType.reverseProfile,
      );
      expect(issue.severity, PlanIssueSeverity.warning);
      expect(issue.value, 30);
      expect(issue.threshold, 15);
    });

    test('up to 12 m deeper is not a reverse profile', () {
      final results = compute(_two(firstDepth: 18, secondDepth: 30));
      expect(_types(results[1]), isNot(contains(PlanIssueType.reverseProfile)));
    });

    test('shallower is not', () {
      final results = compute(_two(firstDepth: 30, secondDepth: 18));
      expect(_types(results[1]), isNot(contains(PlanIssueType.reverseProfile)));
    });

    test('a first dive is checked against the dive it follows', () {
      final end = DateTime(2026, 10, 27, 8);
      final series =
          PlanSeries.single(
            seriesDiveState(surfaceInterval: const Duration(minutes: 5)),
          ).copyWith(
            follow: SeriesFollow(
              loggedDives: [seriesLoggedDive('d1', end).copyWith(maxDepth: 12)],
            ),
          );

      final types = _types(compute(series).single);

      expect(types, contains(PlanIssueType.shortSurfaceInterval));
      expect(types, contains(PlanIssueType.reverseProfile));
    });

    test('they join the dive\'s own issues, most severe first', () {
      final result = compute(_followingHeavyLoad()).single;
      final issues = result.outcome.issues;
      expect(issues, containsAll(result.seriesIssues));
      final severities = [for (final issue in issues) issue.severity.index];
      expect(severities, [...severities]..sort((a, b) => b.compareTo(a)));
    });
  });

  test('owing deco reads the seed the engine starts from', () {
    final state = seriesDiveState().copyWith(
      initialTissueState: _heavyLoad(),
      surfaceInterval: Duration.zero,
    );
    expect(startsOwingDeco(state, config: _config), isTrue);
    expect(
      startsOwingDeco(
        state.copyWith(surfaceInterval: const Duration(hours: 24)),
        config: _config,
      ),
      isFalse,
    );
    expect(startsOwingDeco(seriesDiveState(), config: _config), isFalse);
  });
}
