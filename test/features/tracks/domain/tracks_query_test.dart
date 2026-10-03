import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/domain/tracks_query.dart';

GpsTrack _gps(String id, DateTime start, {DateTime? trimStart}) => GpsTrack(
  id: id,
  startTime: start.millisecondsSinceEpoch,
  endTime: start.add(const Duration(hours: 4)).millisecondsSinceEpoch,
  trimStartTime: trimStart?.millisecondsSinceEpoch,
);

NavTrack _uw(String id, DateTime start, {bool anchored = false}) => NavTrack(
  id: id,
  source: NavTrackSource.seacraftEnc,
  startTime: start.millisecondsSinceEpoch,
  endTime: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
  pointCount: 5,
  anchorLatitude: anchored ? 47.1 : null,
  anchorLongitude: anchored ? 8.3 : null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

List<String> _keys(List<TrackListItem> items) => [
  for (final i in items) i.selectionKey,
];

void main() {
  final may = DateTime.utc(2026, 5, 10);
  final june = DateTime.utc(2026, 6, 15);
  final july = DateTime.utc(2026, 7, 20);

  group('mergeTracks', () {
    test('lists both kinds newest first', () {
      final items = mergeTracks(
        gps: [_gps('g-july', july), _gps('g-may', may)],
        underwater: [_uw('u-june', june)],
        kind: TrackKindFilter.all,
        range: null,
      );
      expect(_keys(items), ['gps:g-july', 'underwater:u-june', 'gps:g-may']);
    });

    test('the kind filter keeps one kind', () {
      final gps = [_gps('g', may)];
      final uw = [_uw('u', june)];
      expect(
        _keys(
          mergeTracks(
            gps: gps,
            underwater: uw,
            kind: TrackKindFilter.gps,
            range: null,
          ),
        ),
        ['gps:g'],
      );
      expect(
        _keys(
          mergeTracks(
            gps: gps,
            underwater: uw,
            kind: TrackKindFilter.underwater,
            range: null,
          ),
        ),
        ['underwater:u'],
      );
    });

    test('the date filter bounds both kinds, inclusive of the end day', () {
      final items = mergeTracks(
        gps: [_gps('g-may', may), _gps('g-july', july)],
        underwater: [_uw('u-june', june), _uw('u-may', may)],
        kind: TrackKindFilter.all,
        range: DateTimeRange(
          start: DateTime.utc(2026, 5, 1),
          end: DateTime.utc(2026, 6, 15),
        ),
      );
      expect(_keys(items), [
        'underwater:u-june',
        'gps:g-may',
        'underwater:u-may',
      ]);
    });

    test('a range matching nothing returns nothing', () {
      expect(
        mergeTracks(
          gps: [_gps('g', may)],
          underwater: [_uw('u', june)],
          kind: TrackKindFilter.all,
          range: DateTimeRange(
            start: DateTime.utc(2025, 1, 1),
            end: DateTime.utc(2025, 12, 31),
          ),
        ),
        isEmpty,
      );
    });

    test('a GPS track sorts by its trimmed start', () {
      // Recorded from 08:00 but trimmed to start at 11:00, so it sorts after
      // an underwater track at 10:00 even though it started first.
      final day = DateTime.utc(2026, 6, 1);
      final items = mergeTracks(
        gps: [
          _gps(
            'g',
            day.add(const Duration(hours: 8)),
            trimStart: day.add(const Duration(hours: 11)),
          ),
        ],
        underwater: [_uw('u', day.add(const Duration(hours: 10)))],
        kind: TrackKindFilter.all,
        range: null,
      );
      expect(_keys(items), ['gps:g', 'underwater:u']);
    });

    test('equal start times break ties by selection key, whatever the '
        'input order', () {
      // Inputs arrive in the reverse of the tie-break order, so this fails
      // without the tie-breaker.
      final items = mergeTracks(
        gps: [_gps('b', may), _gps('a', may)],
        underwater: [_uw('a', may)],
        kind: TrackKindFilter.all,
        range: null,
      );
      expect(_keys(items), ['gps:a', 'gps:b', 'underwater:a']);
    });
  });

  group('startsWithin', () {
    // The date picker hands back LOCAL midnights, while track start times are
    // wall-clock-as-UTC: a range must be read as calendar days, or on any
    // host off UTC the bounds shift by the host's offset. (On a UTC host the
    // two readings coincide, so this guards the contract wherever the suite
    // runs off UTC, as the maintainer's machine does.)
    final july4 = DateTimeRange(
      start: DateTime(2026, 7, 4),
      end: DateTime(2026, 7, 4),
    );

    test('a track early on the picked day is inside it', () {
      final early = DateTime.utc(2026, 7, 4, 0, 30).millisecondsSinceEpoch;
      expect(startsWithin(early, july4), isTrue);
    });

    test('a track late on the picked day is inside it', () {
      final late = DateTime.utc(2026, 7, 4, 23, 30).millisecondsSinceEpoch;
      expect(startsWithin(late, july4), isTrue);
    });

    test('a track just after the picked day is outside it', () {
      final next = DateTime.utc(2026, 7, 5, 0, 30).millisecondsSinceEpoch;
      expect(startsWithin(next, july4), isFalse);
    });

    test('a track just before the picked day is outside it', () {
      final prev = DateTime.utc(2026, 7, 3, 23, 30).millisecondsSinceEpoch;
      expect(startsWithin(prev, july4), isFalse);
    });
  });

  group('capOverview', () {
    test('keeps the newest mappable items and drops unanchored ones', () {
      final items = mergeTracks(
        gps: [_gps('g', may)],
        underwater: [
          _uw('u-anchored', june, anchored: true),
          _uw('u-loose', july),
        ],
        kind: TrackKindFilter.all,
        range: null,
      );
      final capped = capOverview(items);
      expect(_keys(capped.items), ['underwater:u-anchored', 'gps:g']);
      expect(capped.truncated, isFalse);
    });

    test('the cap is shared across kinds', () {
      final start = DateTime.utc(2026, 1, 1);
      final items = mergeTracks(
        gps: [
          for (var i = 0; i < 30; i++)
            _gps('g$i', start.add(Duration(days: -2 * i))),
        ],
        underwater: [
          for (var i = 0; i < 30; i++)
            _uw('u$i', start.add(Duration(days: -2 * i - 1)), anchored: true),
        ],
        kind: TrackKindFilter.all,
        range: null,
      );
      final capped = capOverview(items);
      expect(capped.items.length, kTracksOverviewLimit);
      expect(capped.items.first.selectionKey, 'gps:g0');
      expect(capped.truncated, isTrue);
    });
  });
}
