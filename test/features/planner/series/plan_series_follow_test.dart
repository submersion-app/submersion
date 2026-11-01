import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
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
      endTanks: const [
        DiveTank(
          id: 'l2',
          volume: 7,
          startPressure: 200,
          endPressure: 150,
          gasMix: ean50,
          role: TankRole.deco,
          order: 1,
        ),
        DiveTank(
          id: 'l1',
          name: 'Twin 12',
          volume: 24,
          workingPressure: 232,
          startPressure: 220,
          endPressure: 110,
          gasMix: ean32,
        ),
      ],
    );
  }

  PlanSeries followed(
    PlanSeries series, {
    SeriesFollow? using,
    Duration interval = const Duration(hours: 1),
  }) => followDive(
    series,
    using ?? follow(),
    surfaceInterval: interval,
    newId: idSequence('t'),
  );

  group('the surface a followed dive\'s tissues off-gas at (#3925)', () {
    /// The first dive's seed in a series following a dive in [followedIn],
    /// when that first dive is planned at [altitude].
    BuhlmannState seedFor(DiveEnvironment followedIn, {double? altitude}) {
      final series = followed(
        PlanSeries.single(seriesDiveState().copyWith(altitude: altitude)),
        using: follow().copyWith(endEnvironment: followedIn),
      );
      final state = carriedState(
        series.dives,
        0,
        const [],
        follow: series.follow,
      );
      return startStateForPlan(state, config: _config)! as BuhlmannState;
    }

    List<double> tensions(BuhlmannState state) => [
      for (final c in state.compartments) c.currentPN2,
    ];

    test('a plan at altitude after a dive at sea level waits at sea level', () {
      expect(
        tensions(seedFor(DiveEnvironment.standard, altitude: 3000)),
        tensions(seedFor(DiveEnvironment.standard)),
      );
    });

    test('a plan at the followed dive\'s altitude waits at that altitude', () {
      final atAltitude = DiveEnvironment.forConditions(
        altitudeMeters: 3000,
        waterType: WaterType.salt,
      );

      expect(
        tensions(seedFor(atAltitude, altitude: 3000)),
        isNot(tensions(seedFor(DiveEnvironment.standard, altitude: 3000))),
      );
    });

    test('the environment is carried with a copy', () {
      const altitude = DiveEnvironment(surfacePressureBar: 0.7);
      final copy = follow().copyWith(endEnvironment: altitude);

      expect(copy.endEnvironment, altitude);
      expect(copy.copyWith(endCns: 5).endEnvironment, altitude);
      expect(copy, isNot(follow()));
    });
  });

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
      // Each tank is the followed dive's own, in its order, at the pressure
      // it ended with.
      expect(first.tanks.map((t) => t.startPressure), [110, 150]);
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

  group('the follow entities', () {
    test('copyWith replaces only what it is given', () {
      final dive = seriesLoggedDive('logged', followedEnd, otu: 40, number: 7);
      expect(dive.copyWith(otu: 12).otu, 12);
      expect(dive.copyWith(otu: 12).diveNumber, 7);

      final follow = SeriesFollow(
        loggedDives: [dive],
        endTissues: endTissues,
        endCns: 20,
      );
      expect(follow.copyWith(endCns: 5).endCns, 5);
      expect(follow.copyWith(endCns: 5).endTissues, endTissues);
      expect(follow.copyWith(clearEndTissues: true).endTissues, isNull);
    });
  });

  group('following and unfollowing', () {
    test('the first dive takes the followed dive tanks and breathes them', () {
      final first = followed(
        PlanSeries.single(seriesDiveState()),
      ).dives.first.state;

      expect(first.tanks.map((t) => t.id), ['t-0', 't-1']);
      expect(first.tanks.first.name, 'Twin 12');
      expect(first.tanks.first.volume, 24);
      expect(first.tanks.last.role, TankRole.deco);
      // The profile moves to the new tank of the same gas.
      expect(first.segments.map((s) => s.tankId).toSet(), {'t-0'});
    });

    test('a followed dive with no tanks leaves the plan tanks', () {
      final series = followed(
        PlanSeries.single(seriesDiveState()),
        using: SeriesFollow(
          loggedDives: [seriesLoggedDive('followed', followedEnd)],
        ),
      );

      expect(series.dives.first.state.tanks.map((t) => t.id), [
        'dive-a-back',
        'dive-a-stage',
      ]);
    });

    test('a dive after the first carries from the new tanks', () {
      var series = appendDive(
        PlanSeries.single(seriesDiveState()),
        newId: idSequence(),
      );
      series = followed(series);

      expect(series.dives[1].sourceTankIds.values.toSet(), {'t-0', 't-1'});
    });

    test('following keeps the first dive own pressures for Fill', () {
      final series = followed(PlanSeries.single(seriesDiveState()));
      // The editor stores what was carried in.
      final carried = updateDiveState(
        series,
        0,
        carriedState(series.dives, 0, const [], follow: series.follow),
        pinTypedPressures: false,
      );

      // The logged fills, which the carried pressures replace.
      expect(series.follow!.ownStartPressures, {'t-0': 220, 't-1': 200});
      expect(carried.dives.first.state.tanks.first.startPressure, 110);
      expect(fullPressureFor(carried, 0, 't-0'), 220);
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
      // The followed dive's tanks stay, back at their fills.
      expect(first.tanks.map((t) => t.id), ['t-0', 't-1']);
      expect(first.tanks.map((t) => t.startPressure), [220, 200]);
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
        b.state.tanks[0].id: 220,
        b.state.tanks[1].id: 200,
      });
      // Its tanks now carry from the logged tanks.
      final first = carriedState(
        removed.dives,
        0,
        const [],
        follow: removed.follow,
      );
      expect(first.tanks.map((t) => t.startPressure), [110, 150]);
    });
  });
}
