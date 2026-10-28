import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/logged_dive_chain.dart';

import 'series_fixtures.dart';

void main() {
  final day = DateTime(2026, 10, 25, 9);

  group('loggedDiveChain', () {
    test('runs back from the followed dive to the first 48-hour gap', () {
      final dives = [
        loggedDive('old', day.subtract(const Duration(days: 4))),
        loggedDive('d1', day.subtract(const Duration(hours: 30))),
        loggedDive('d2', day),
        loggedDive('d3', day.add(const Duration(hours: 3))),
      ];

      final chain = loggedDiveChain(dives, 'd3');

      expect(chain.map((d) => d.id), ['d1', 'd2', 'd3']);
    });

    test('ignores dives logged after the followed one, and planned dives', () {
      final dives = [
        loggedDive('d1', day),
        loggedDive(
          'planned',
          day.add(const Duration(hours: 2)),
          isPlanned: true,
        ),
        loggedDive('d2', day.add(const Duration(hours: 4))),
        loggedDive('later', day.add(const Duration(hours: 8))),
      ];

      final chain = loggedDiveChain(dives, 'd2');

      expect(chain.map((d) => d.id), ['d1', 'd2']);
    });

    test('is empty when the followed dive is not there', () {
      expect(loggedDiveChain([loggedDive('d1', day)], 'gone'), isEmpty);
    });
  });

  group('followSurfaceInterval', () {
    final end = DateTime(2026, 10, 25, 10);

    test('is the time since a recent dive ended', () {
      expect(
        followSurfaceInterval(
          end,
          now: end.add(const Duration(hours: 2, minutes: 10)),
        ),
        const Duration(hours: 2, minutes: 10),
      );
    });

    test('is an hour for a dive that only just ended or long ago', () {
      expect(
        followSurfaceInterval(end, now: end.add(const Duration(minutes: 5))),
        const Duration(hours: 1),
      );
      expect(
        followSurfaceInterval(end, now: end.add(followLookback)),
        const Duration(hours: 1),
      );
    });
  });

  group('followedTankPressures', () {
    final planTanks = [
      const DiveTank(id: 'back', startPressure: 232, gasMix: ean32),
      const DiveTank(id: 'stage', startPressure: 200, gasMix: ean50),
      const DiveTank(id: 'spare', startPressure: 210, gasMix: ean32),
    ];
    SeriesFollow follow(List<DiveTank> logged, [Map<String, double>? own]) =>
        SeriesFollow(
          loggedDives: [seriesLoggedDive('d1', day)],
          endTanks: logged,
          ownStartPressures: own ?? const {},
        );

    test('a tank linked to a logged tank starts at its end pressure', () {
      final tanks = followedTankPressures(
        planTanks,
        follow(const [
          DiveTank(id: 'l1', endPressure: 90, gasMix: ean32),
          DiveTank(id: 'l2', endPressure: 140, gasMix: ean50),
        ]),
        sources: {'back': 'l1', 'stage': 'l2'},
      );

      expect(tanks.map((t) => t.startPressure), [90, 140, 210]);
    });

    test('a pinned tank, or one with no logged end pressure, is not carried; '
        'an unlinked tank keeps its own pressure', () {
      final tanks = followedTankPressures(
        [planTanks[0].copyWith(startPressure: 100), ...planTanks.skip(1)],
        follow(
          const [
            DiveTank(id: 'l1', gasMix: ean32),
            DiveTank(id: 'l2', endPressure: 140, gasMix: ean50),
          ],
          {'back': 232},
        ),
        sources: {'back': 'l1', 'stage': 'l2'},
        pinned: {'stage'},
      );

      expect(tanks.map((t) => t.startPressure), [232, 200, 210]);
    });

    test('an end pressure below zero starts at zero', () {
      final tanks = followedTankPressures(
        planTanks,
        follow(const [DiveTank(id: 'l1', endPressure: -5, gasMix: ean32)]),
        sources: {'back': 'l1'},
      );

      expect(tanks.first.startPressure, 0);
    });
  });
}
