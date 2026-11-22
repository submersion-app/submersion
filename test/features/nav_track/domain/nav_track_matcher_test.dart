import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';

int _sec(int y, int m, int d, int h, int min, [int s = 0]) =>
    DateTime.utc(y, m, d, h, min, s).millisecondsSinceEpoch ~/ 1000;

Dive _dive(String id, DateTime entry, {DateTime? exit, Duration? runtime}) =>
    Dive(
      id: id,
      dateTime: entry,
      entryTime: entry,
      exitTime: exit,
      runtime: runtime,
    );

NavTrack _route(String id, DateTime start, DateTime end, {String? diveId}) =>
    NavTrack(
      id: id,
      diveId: diveId,
      source: NavTrackSource.seacraftEnc,
      startTime: start.millisecondsSinceEpoch,
      endTime: end.millisecondsSinceEpoch,
      pointCount: 2,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  group('NavTrackMatcher.candidatesFor', () {
    test('matches a dive whose window fully contains the route', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 8, 22, 10, 0),
        exit: DateTime.utc(2026, 8, 22, 11, 30),
      );
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 10, 10, 23),
        routeEndSeconds: _sec(2026, 8, 22, 11, 5, 47),
        dives: [dive],
      );
      expect(result, [dive]);
    });

    test('matches using runtime when no exit time is stored', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 8, 22, 10, 0),
        runtime: const Duration(minutes: 90),
      );
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 10, 10),
        routeEndSeconds: _sec(2026, 8, 22, 11, 0),
        dives: [dive],
      );
      expect(result, [dive]);
    });

    test('matches within the 30-minute tolerance on either side', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 8, 22, 10, 0),
        exit: DateTime.utc(2026, 8, 22, 11, 0),
      );
      // Route starts 20 minutes before the dive's own entry -- within the
      // 30-minute tolerance -- and ends inside the dive.
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 9, 40),
        routeEndSeconds: _sec(2026, 8, 22, 10, 30),
        dives: [dive],
      );
      expect(result, [dive]);
    });

    test('does not match beyond the 30-minute tolerance', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 8, 22, 10, 0),
        exit: DateTime.utc(2026, 8, 22, 11, 0),
      );
      // Route ends 31 minutes before the dive starts (tolerance-extended
      // dive window starts at 9:30) -- just outside.
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 8, 0),
        routeEndSeconds: _sec(2026, 8, 22, 9, 29),
        dives: [dive],
      );
      expect(result, isEmpty);
    });

    test('matches exactly at the edge of the tolerance', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 8, 22, 10, 0),
        exit: DateTime.utc(2026, 8, 22, 11, 0),
      );
      // Route ends exactly 30 minutes before the dive starts.
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 8, 0),
        routeEndSeconds: _sec(2026, 8, 22, 9, 30),
        dives: [dive],
      );
      expect(result, [dive]);
    });

    test('returns an empty list when no dive is close in time', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 1, 1, 10, 0),
        exit: DateTime.utc(2026, 1, 1, 11, 0),
      );
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        routeEndSeconds: _sec(2026, 8, 22, 11, 0),
        dives: [dive],
      );
      expect(result, isEmpty);
    });

    test('orders multiple candidates by overlap, largest first', () {
      final barelyOverlapping = _dive(
        'barely',
        DateTime.utc(2026, 8, 22, 9, 45),
        exit: DateTime.utc(2026, 8, 22, 10, 5),
      );
      final fullyOverlapping = _dive(
        'full',
        DateTime.utc(2026, 8, 22, 10, 0),
        exit: DateTime.utc(2026, 8, 22, 11, 0),
      );
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        routeEndSeconds: _sec(2026, 8, 22, 11, 0),
        dives: [barelyOverlapping, fullyOverlapping],
      );
      expect(result.map((d) => d.id), ['full', 'barely']);
    });

    test('a dive with neither exit time nor runtime still matches at its '
        'own instant', () {
      final dive = _dive('d1', DateTime.utc(2026, 8, 22, 10, 0));
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 9, 50),
        routeEndSeconds: _sec(2026, 8, 22, 10, 10),
        dives: [dive],
      );
      expect(result, [dive]);
    });

    test('returns an empty list for an empty dive list', () {
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        routeEndSeconds: _sec(2026, 8, 22, 11, 0),
        dives: const [],
      );
      expect(result, isEmpty);
    });
  });

  group('NavTrackMatcher.soleCandidateFor', () {
    final routeStart = _sec(2026, 8, 22, 10, 10);
    final routeEnd = _sec(2026, 8, 22, 11, 0);
    final overlapping = _dive(
      'd1',
      DateTime.utc(2026, 8, 22, 10, 0),
      exit: DateTime.utc(2026, 8, 22, 11, 30),
    );

    test('suggests the one dive whose window overlaps the route', () {
      final farAway = _dive(
        'd2',
        DateTime.utc(2026, 8, 23, 10, 0),
        exit: DateTime.utc(2026, 8, 23, 11, 0),
      );
      expect(
        NavTrackMatcher.soleCandidateFor(
          routeStartSeconds: routeStart,
          routeEndSeconds: routeEnd,
          dives: [farAway, overlapping],
        ),
        overlapping,
      );
    });

    test('suggests nothing when two dives overlap (ambiguous)', () {
      final alsoOverlapping = _dive(
        'd2',
        DateTime.utc(2026, 8, 22, 10, 20),
        exit: DateTime.utc(2026, 8, 22, 10, 50),
      );
      expect(
        NavTrackMatcher.soleCandidateFor(
          routeStartSeconds: routeStart,
          routeEndSeconds: routeEnd,
          dives: [overlapping, alsoOverlapping],
        ),
        isNull,
      );
    });

    test('suggests nothing when no dive is close in time (unmatched)', () {
      final farAway = _dive(
        'd2',
        DateTime.utc(2026, 8, 23, 10, 0),
        exit: DateTime.utc(2026, 8, 23, 11, 0),
      );
      expect(
        NavTrackMatcher.soleCandidateFor(
          routeStartSeconds: routeStart,
          routeEndSeconds: routeEnd,
          dives: [farAway],
        ),
        isNull,
      );
    });
  });

  group('NavTrackMatcher.nearestByStart', () {
    test('orders every dive by distance from the route start, however far '
        'outside the tolerance window (a device clock set 2 hours ahead)', () {
      final twoHoursBefore = _dive('two-h', DateTime.utc(2026, 8, 22, 8, 0));
      final nextDay = _dive('next-day', DateTime.utc(2026, 8, 23, 10, 0));
      final fiveHoursAfter = _dive('five-h', DateTime.utc(2026, 8, 22, 15, 0));
      final result = NavTrackMatcher.nearestByStart(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        dives: [nextDay, fiveHoursAfter, twoHoursBefore],
      );
      expect(result.map((d) => d.id), ['two-h', 'five-h', 'next-day']);
    });

    test('breaks a tie in distance by the earlier dive', () {
      final after = _dive('after', DateTime.utc(2026, 8, 22, 11, 0));
      final before = _dive('before', DateTime.utc(2026, 8, 22, 9, 0));
      final result = NavTrackMatcher.nearestByStart(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        dives: [after, before],
      );
      expect(result.map((d) => d.id), ['before', 'after']);
    });

    test('keeps only the nearest [limit] dives', () {
      final dives = [
        for (var h = 1; h <= 30; h++)
          _dive(
            'd$h',
            DateTime.utc(2026, 8, 22, 10, 0).add(Duration(hours: h)),
          ),
      ];
      final result = NavTrackMatcher.nearestByStart(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        dives: dives.reversed.toList(),
        limit: 3,
      );
      expect(result.map((d) => d.id), ['d1', 'd2', 'd3']);
    });

    test('defaults to nearestLimit dives', () {
      final dives = [
        for (var h = 1; h <= NavTrackMatcher.nearestLimit + 5; h++)
          _dive(
            'd$h',
            DateTime.utc(2026, 8, 22, 10, 0).add(Duration(hours: h)),
          ),
      ];
      final result = NavTrackMatcher.nearestByStart(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        dives: dives,
      );
      expect(result, hasLength(NavTrackMatcher.nearestLimit));
    });

    test('measures from effectiveEntryTime, not the logged dateTime', () {
      final dive = Dive(
        id: 'entry-differs',
        dateTime: DateTime.utc(2026, 8, 22, 6, 0),
        entryTime: DateTime.utc(2026, 8, 22, 10, 5),
      );
      final other = _dive('other', DateTime.utc(2026, 8, 22, 9, 0));
      final result = NavTrackMatcher.nearestByStart(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        dives: [other, dive],
      );
      expect(result.map((d) => d.id), ['entry-differs', 'other']);
    });

    test('returns an empty list for an empty dive list', () {
      expect(
        NavTrackMatcher.nearestByStart(
          routeStartSeconds: _sec(2026, 8, 22, 10, 0),
          dives: const [],
        ),
        isEmpty,
      );
    });
  });

  group('NavTrackMatcher.linkProposals (#4851)', () {
    final morning = _dive(
      'd1',
      DateTime.utc(2026, 8, 22, 10, 0),
      exit: DateTime.utc(2026, 8, 22, 11, 0),
    );
    final afternoon = _dive(
      'd2',
      DateTime.utc(2026, 8, 22, 14, 0),
      exit: DateTime.utc(2026, 8, 22, 15, 0),
    );

    test('proposes each unlinked route\'s sole overlapping dive, in the '
        'order the routes came', () {
      final late = _route(
        'r2',
        DateTime.utc(2026, 8, 22, 14, 5),
        DateTime.utc(2026, 8, 22, 14, 50),
      );
      final early = _route(
        'r1',
        DateTime.utc(2026, 8, 22, 10, 5),
        DateTime.utc(2026, 8, 22, 10, 50),
      );

      final proposals = NavTrackMatcher.linkProposals(
        routes: [late, early],
        dives: [morning, afternoon],
      );

      expect(
        [for (final p in proposals) (p.route.id, p.dive.id)],
        [('r2', 'd2'), ('r1', 'd1')],
      );
    });

    test('leaves out a route no dive overlaps, one several dives overlap, '
        'and one already linked', () {
      final unmatched = _route(
        'r1',
        DateTime.utc(2026, 8, 23, 10, 0),
        DateTime.utc(2026, 8, 23, 11, 0),
      );
      final ambiguous = _route(
        'r2',
        DateTime.utc(2026, 8, 22, 10, 0),
        DateTime.utc(2026, 8, 22, 15, 0),
      );
      final linked = _route(
        'r3',
        DateTime.utc(2026, 8, 22, 10, 5),
        DateTime.utc(2026, 8, 22, 10, 50),
        diveId: 'd9',
      );

      expect(
        NavTrackMatcher.linkProposals(
          routes: [unmatched, ambiguous, linked],
          dives: [morning, afternoon],
        ),
        isEmpty,
      );
    });
  });
}
