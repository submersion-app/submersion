import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/domain/home_outings.dart';

/// A dive at [day] of 2026's month [month], as the wall clock flagged UTC.
OutingDive _dive(
  String id,
  int month,
  int day, {
  int hour = 10,
  int minute = 0,
  int year = 2026,
  String? tripId,
  String? tripName,
  String? site,
  double? depth,
  Set<String> species = const {},
  (double, double)? at,
}) => OutingDive(
  id: id,
  dateTime: DateTime.utc(year, month, day, hour, minute),
  tripId: tripId,
  tripName: tripName,
  siteName: site,
  maxDepth: depth,
  speciesIds: species,
  siteLatitude: at?.$1,
  siteLongitude: at?.$2,
);

CoverCandidate _media(
  String id, {
  bool video = false,
  bool favorite = false,
  bool tagged = false,
  DateTime? at,
}) => CoverCandidate(
  mediaId: id,
  diveId: 'd',
  isVideo: video,
  isFavorite: favorite,
  hasSpeciesTag: tagged,
  takenAt: at,
);

void main() {
  group('groupOutings', () {
    test('trip dives form one outing named after the trip', () {
      final outings = groupOutings([
        _dive('a', 5, 3, tripId: 't1', tripName: 'Bonaire May 2026'),
        _dive('b', 5, 5, tripId: 't1', tripName: 'Bonaire May 2026'),
        _dive('c', 5, 7, tripId: 't1', tripName: 'Bonaire May 2026'),
      ]);
      expect(outings, hasLength(1));
      final o = outings.single;
      expect(o.tripId, 't1');
      expect(o.name, 'Bonaire May 2026');
      expect(o.firstDay, DateTime(2026, 5, 3));
      expect(o.lastDay, DateTime(2026, 5, 7));
      expect(o.diveCount, 3);
      expect(o.diveIds, ['a', 'b', 'c']);
    });

    test('trip-less dives 2 days apart join; 3 days apart split', () {
      final joined = groupOutings([
        _dive('a', 9, 20, site: 'Maclearie Park'),
        _dive('b', 9, 21, site: 'Maclearie Park'),
        _dive('c', 9, 23, site: 'Maclearie Park'),
      ]);
      expect(joined, hasLength(1));
      expect(joined.single.diveCount, 3);

      final split = groupOutings([
        _dive('a', 9, 20, site: 'Maclearie Park'),
        _dive('b', 9, 24, site: 'Maclearie Park'),
      ]);
      expect(split, hasLength(2));
    });

    test('a trip-less dive between trip dives is its own outing', () {
      final outings = groupOutings([
        _dive('a', 5, 3, tripId: 't1', tripName: 'Bonaire'),
        _dive('x', 5, 4, site: 'Pool'),
        _dive('b', 5, 5, tripId: 't1', tripName: 'Bonaire'),
      ]);
      expect(outings, hasLength(2));
      final tripless = outings.firstWhere((o) => o.tripId == null);
      expect(tripless.diveIds, ['x']);
      final trip = outings.firstWhere((o) => o.tripId == 't1');
      expect(trip.diveIds, ['a', 'b']);
    });

    test('a trip-less outing is named after its most-dived site', () {
      final outings = groupOutings([
        _dive('a', 9, 20, site: 'Shark River'),
        _dive('b', 9, 20, hour: 12, site: 'Maclearie Park'),
        _dive('c', 9, 21, site: 'Maclearie Park'),
      ]);
      expect(outings.single.name, 'Maclearie Park');
    });

    test('a tie goes to the site dived first', () {
      final outings = groupOutings([
        _dive('a', 9, 20, site: 'Shark River'),
        _dive('b', 9, 21, site: 'Maclearie Park'),
      ]);
      expect(outings.single.name, 'Shark River');
    });

    test('no site on any dive gives no name', () {
      final outings = groupOutings([_dive('a', 9, 20), _dive('b', 9, 21)]);
      expect(outings.single.name, isNull);
    });

    test('max depth, depths in date order, species counted once', () {
      final outings = groupOutings([
        _dive('b', 5, 4, tripId: 't', depth: 29.7, species: {'b', 'c'}),
        _dive('a', 5, 3, tripId: 't', depth: 25.2, species: {'a', 'b'}),
        _dive('c', 5, 5, tripId: 't'),
      ]);
      final o = outings.single;
      expect(o.maxDepth, 29.7);
      expect(o.depths, [25.2, 29.7, 0]);
      expect(o.speciesCount, 3);
    });

    test('newest first and capped at the limit', () {
      final dives = [
        for (var m = 1; m <= 10; m++) _dive('d$m', m, 1, site: 'Site $m'),
      ];
      final outings = groupOutings(dives);
      expect(outings, hasLength(8));
      expect(outings.first.diveIds, ['d10']);
      expect(outings.last.diveIds, ['d3']);
    });

    test('the day is the wall-clock day', () {
      final outings = groupOutings([
        _dive('a', 5, 7, hour: 23, minute: 30, site: 'Invisibles'),
      ]);
      expect(outings.single.firstDay, DateTime(2026, 5, 7));
      expect(outings.single.lastDay, DateTime(2026, 5, 7));
    });

    test('a gap is counted in days across a month end', () {
      final outings = groupOutings([
        _dive('a', 1, 31, site: 'Pier'),
        _dive('b', 2, 2, site: 'Pier'),
      ]);
      expect(outings, hasLength(1));
    });

    test('a read cut short drops the trip-less chain at the cut', () {
      final dives = [
        _dive('old1', 3, 1, site: 'Pier'),
        _dive('old2', 3, 2, site: 'Pier'),
        _dive('new', 5, 1, site: 'Reef'),
      ];
      final cut = DateTime.utc(2026, 3, 1, 10);
      // Unread dives just before the cut could belong to the Pier chain.
      expect(groupOutings(dives, cutAt: cut).map((o) => o.diveIds), [
        ['new'],
      ]);
      expect(groupOutings(dives), hasLength(2));
    });

    test('a read cut short keeps a lone outing', () {
      final dives = [_dive('a', 3, 1, site: 'Pier'), _dive('b', 3, 2)];
      expect(
        groupOutings(dives, cutAt: DateTime.utc(2026, 3, 1, 10)),
        hasLength(1),
      );
    });

    test('a read cut short keeps trips, which the caller completes', () {
      final dives = [
        _dive('t-a', 3, 1, tripId: 't', tripName: 'Trip'),
        _dive('t-b', 3, 3, tripId: 't', tripName: 'Trip'),
        _dive('new', 5, 1, site: 'Reef'),
      ];
      final outings = groupOutings(dives, cutAt: DateTime.utc(2026, 3, 1, 10));
      expect(outings.map((o) => o.tripId), [null, 't']);
    });

    test(
      'only a trip-less chain within the join gap of the cut is dropped',
      () {
        final cut = DateTime.utc(2026, 3, 1, 10);
        final within = groupOutings([
          _dive('t', 3, 1, tripId: 't', tripName: 'Trip'),
          _dive('near', 3, 3, site: 'Pier'),
        ], cutAt: cut);
        expect(within.map((o) => o.tripId), ['t']);
        final beyond = groupOutings([
          _dive('t', 3, 1, tripId: 't', tripName: 'Trip'),
          _dive('far', 3, 4, site: 'Pier'),
        ], cutAt: cut);
        expect(beyond, hasLength(2));
      },
    );

    test('an outing lists its sites with a position once, in date order', () {
      final outings = groupOutings([
        _dive('a', 5, 3, tripId: 't', at: (12.1717, -68.2894)),
        _dive('b', 5, 4, tripId: 't', at: (12.0776, -68.2802)),
        _dive('c', 5, 5, tripId: 't', at: (12.1717, -68.2894)),
        _dive('d', 5, 6, tripId: 't'),
      ]);
      expect(outings.single.sites, [
        (latitude: 12.1717, longitude: -68.2894),
        (latitude: 12.0776, longitude: -68.2802),
      ]);
    });

    test('a site at 0,0 has no position', () {
      final outings = groupOutings([
        _dive('a', 5, 3, tripId: 't', at: (0, 0)),
        _dive('b', 5, 4, tripId: 't', at: (18.4654, -66.0859)),
      ]);
      expect(outings.single.sites, [(latitude: 18.4654, longitude: -66.0859)]);
    });

    test('no dives give no outings', () {
      expect(groupOutings(const []), isEmpty);
    });
  });

  group('chooseOutingCover', () {
    test('a favourite beats a species tag, which beats the earliest', () {
      final early = DateTime(2026, 5, 3);
      final late = DateTime(2026, 5, 6);
      expect(
        chooseOutingCover([
          _media('plain', at: early),
          _media('tagged', tagged: true, at: late),
          _media('fav', favorite: true, at: late),
        ]),
        'fav',
      );
      expect(
        chooseOutingCover([
          _media('plain', at: early),
          _media('tagged', tagged: true, at: late),
        ]),
        'tagged',
      );
      expect(
        chooseOutingCover([
          _media('late', at: late),
          _media('early', at: early),
        ]),
        'early',
      );
    });

    test('a photo comes before a video in the same tier', () {
      expect(
        chooseOutingCover([
          _media('clip', video: true, at: DateTime(2026, 5, 1)),
          _media('photo', at: DateTime(2026, 5, 2)),
        ]),
        'photo',
      );
    });

    test('an outing with only videos picks the earliest video', () {
      expect(
        chooseOutingCover([
          _media('v2', video: true, at: DateTime(2026, 5, 2)),
          _media('v1', video: true, at: DateTime(2026, 5, 1)),
        ]),
        'v1',
      );
    });

    test('a missing time sorts last', () {
      expect(
        chooseOutingCover([
          _media('undated'),
          _media('dated', at: DateTime(2026, 5, 2)),
        ]),
        'dated',
      );
    });

    test('no candidates give no cover', () {
      expect(chooseOutingCover(const []), isNull);
    });
  });

  test('the inputs copy with changes', () {
    final dive = _dive('a', 5, 3, site: 'Pier');
    expect(dive.copyWith(siteName: 'Reef').siteName, 'Reef');
    expect(dive.copyWith(siteName: 'Reef').id, 'a');
    final media = _media('m');
    expect(media.copyWith(isFavorite: true).isFavorite, isTrue);
    expect(media.copyWith(isFavorite: true).mediaId, 'm');
  });
}
