import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/planner/domain/services/plan_series_edits.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';

import 'series_fixtures.dart';

const _config = PlanEngineConfig();

void main() {
  final followedEnd = DateTime(2026, 10, 25, 11);
  final endTissues = computeOutcomeForState(
    seriesDiveState(id: 'logged'),
    config: _config,
  ).endTissue.compartments;

  SeriesFollow follow({
    double followedOtu = 40,
    double earlierOtu = 30,
    Duration earlierGap = const Duration(hours: 3),
  }) {
    return SeriesFollow(
      loggedDives: [
        seriesLoggedDive(
          'earlier',
          followedEnd.subtract(earlierGap),
          otu: earlierOtu,
        ),
        seriesLoggedDive('followed', followedEnd, otu: followedOtu, number: 7),
      ],
      endTissues: endTissues,
      endCns: 18,
      endTanks: const [DiveTank(id: 'l1', endPressure: 110, gasMix: ean32)],
    );
  }

  PlanSeries followed(
    PlanSeries series, {
    SeriesFollow? using,
    Duration interval = const Duration(hours: 1),
  }) => followDive(series, using ?? follow(), surfaceInterval: interval);

  group('the first dive of a series that follows a logged dive', () {
    test('starts from its end tissues, CNS and tank pressures', () {
      final series = followed(PlanSeries.single(seriesDiveState()));
      final results = computeSeries(
        series.dives,
        config: _config,
        follow: series.follow,
      );
      final fresh = computeOutcomeForState(seriesDiveState(), config: _config);

      final first = results.first.state;
      expect(first.initialTissueState, endTissues);
      expect(first.initialCns, 18);
      expect(first.surfaceInterval, const Duration(hours: 1));
      // The back gas carries the logged EAN32's 110 bar; the stage has no
      // logged EAN50 and keeps its own fill.
      expect(first.tanks.map((t) => t.startPressure), [110, 200]);
      expect(
        results.first.outcome.totalDecoSeconds,
        greaterThan(fresh.totalDecoSeconds),
      );
    });

    test('carries the OTU of logged dives that ended in the last 24 hours', () {
      final recent = followed(PlanSeries.single(seriesDiveState()));
      final aDayOn = followed(
        PlanSeries.single(seriesDiveState()),
        using: follow(earlierGap: const Duration(hours: 23, minutes: 30)),
      );

      DivePlanState first(PlanSeries s) =>
          carriedState(s.dives, 0, const [], follow: s.follow);

      expect(first(recent).initialOtu, 70);
      // The earlier dive ended 24.5 hours before this one starts.
      expect(first(aDayOn).initialOtu, 40);
    });

    test('a later dive counts the logged OTU still within 24 hours', () {
      var series = followed(PlanSeries.single(seriesDiveState()));
      series = appendDive(series, newId: idSequence());
      final results = computeSeries(
        series.dives,
        config: _config,
        follow: series.follow,
      );
      final ownA = results[0].outcome.otuTotal - results[0].state.initialOtu!;

      expect(results[1].state.initialOtu, closeTo(70 + ownA, 1e-9));
    });
  });

  group('following and unfollowing', () {
    test('following keeps the first dive own pressures for Fill', () {
      final series = followed(PlanSeries.single(seriesDiveState()));
      // The editor stores what was carried in.
      final carried = updateDiveState(
        series,
        0,
        carriedState(series.dives, 0, const [], follow: series.follow),
        pinTypedPressures: false,
      );

      expect(series.follow!.ownStartPressures, {
        'dive-a-back': 232,
        'dive-a-stage': 200,
      });
      expect(carried.dives.first.state.tanks.first.startPressure, 110);
      expect(fullPressureFor(carried, 0, 'dive-a-back'), 232);
    });

    test('unfollowing restores the first dive', () {
      final series = followed(PlanSeries.single(seriesDiveState()));
      final carried = updateDiveState(
        series,
        0,
        carriedState(series.dives, 0, const [], follow: series.follow),
        pinTypedPressures: false,
      );

      final plain = unfollow(carried);
      final first = plain.dives.first.state;

      expect(plain.follow, isNull);
      expect(first.surfaceInterval, isNull);
      expect(first.initialTissueState, isNull);
      expect(first.initialCns, isNull);
      expect(first.tanks.map((t) => t.startPressure), [232, 200]);
    });

    test('removing the first dive leaves the next one following', () {
      var series = followed(PlanSeries.single(seriesDiveState()));
      series = appendDive(series, newId: idSequence());
      final b = series.dives[1];

      final removed = removeDive(series, 0);

      expect(removed.follow, isNotNull);
      expect(
        removed.dives.single.state.surfaceInterval,
        b.state.surfaceInterval,
      );
      expect(removed.follow!.ownStartPressures, {
        b.state.tanks[0].id: 232,
        b.state.tanks[1].id: 200,
      });
    });
  });
}
