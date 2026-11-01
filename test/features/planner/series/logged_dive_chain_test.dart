import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/logged_dive_chain.dart';

import '../../../helpers/dst_transition.dart';
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

  group('diveEnd', () {
    test('is the recorded exit time, even when the runtime disagrees', () {
      // An import whose runtime stops short of the recorded exit.
      final exit = day.add(const Duration(minutes: 52));
      final dive = loggedDive('d1', day, minutes: 45, exitTime: exit);

      expect(diveEnd(dive), exit);
    });

    test('is the start plus the runtime without an exit time', () {
      expect(
        diveEnd(loggedDive('d1', day, minutes: 45)),
        day.add(const Duration(minutes: 45)),
      );
    });

    test('decides the 48-hour gap from the recorded exit', () {
      final dives = [
        loggedDive(
          'd1',
          day,
          minutes: 45,
          exitTime: day.add(const Duration(hours: 2)),
        ),
        // 48 h 15 min after d1's runtime ends, but 47 h after its exit.
        loggedDive('d2', day.add(const Duration(hours: 49))),
      ];

      expect(loggedDiveChain(dives, 'd2').map((d) => d.id), ['d1', 'd2']);
    });
  });

  group('diveEndInstant', () {
    test('reads a stored exit in the device zone', () {
      final dive = Dive(
        id: 'd',
        dateTime: DateTime.utc(2026, 7, 1, 9),
        exitTime: DateTime.utc(2026, 7, 1, 10),
      );

      expect(diveEndInstant(dive), DateTime(2026, 7, 1, 10));
    });

    test('adds the runtime to the real start across a clock change', () {
      final change = dstTransition(forward: true)!;
      final start = change.subtract(const Duration(minutes: 30));
      final dive = Dive(
        id: 'd',
        dateTime: asWallClockUtc(start.toLocal()),
        runtime: const Duration(hours: 1),
      );

      expect(
        diveEndInstant(
          dive,
        ).isAtSameMomentAs(start.add(const Duration(hours: 1))),
        isTrue,
      );
    }, skip: zoneHasNoDst);
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

    test('is an hour for a dive that ended less than an hour ago', () {
      for (final minutes in const [5, 30, 59]) {
        expect(
          followSurfaceInterval(end, now: end.add(Duration(minutes: minutes))),
          const Duration(hours: 1),
        );
      }
    });

    test('is the time since from an hour on', () {
      expect(
        followSurfaceInterval(end, now: end.add(const Duration(hours: 1))),
        const Duration(hours: 1),
      );
      expect(
        followSurfaceInterval(
          end,
          now: end.add(const Duration(hours: 1, minutes: 20)),
        ),
        const Duration(hours: 1, minutes: 20),
      );
    });

    test('starts the plan now for a dive long ago, not in the past', () {
      expect(
        followSurfaceInterval(end, now: end.add(const Duration(days: 3))),
        const Duration(days: 3),
      );
    });

    test('rounds up, so the start is not a few seconds in the past', () {
      expect(
        followSurfaceInterval(
          end,
          now: end.add(const Duration(hours: 2, seconds: 1)),
        ),
        const Duration(hours: 2, minutes: 1),
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

    group('a tank changed from the logged one starts full', () {
      const logged = DiveTank(
        id: 'l1',
        volume: 12,
        workingPressure: 232,
        endPressure: 90,
        gasMix: ean32,
      );
      const planned = DiveTank(
        id: 'back',
        volume: 12,
        workingPressure: 232,
        startPressure: 90,
        gasMix: ean32,
      );

      List<DiveTank> carried(DiveTank tank) => followedTankPressures(
        [tank],
        follow(const [logged]),
        sources: {'back': 'l1'},
      );

      test('the same tank carries', () {
        expect(carried(planned).single.startPressure, 90);
      });

      test('on another gas', () {
        expect(
          carried(planned.copyWith(gasMix: ean50)).single.startPressure,
          232,
        );
      });

      test('of another size', () {
        expect(
          carried(
            planned.copyWith(volume: 15, workingPressure: 300),
          ).single.startPressure,
          300,
        );
      });

      test('but not when pinned', () {
        final tanks = followedTankPressures(
          [planned.copyWith(gasMix: ean50, startPressure: 120)],
          follow(const [logged]),
          sources: {'back': 'l1'},
          pinned: {'back'},
        );
        expect(tanks.single.startPressure, 120);
      });
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
