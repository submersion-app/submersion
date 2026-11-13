import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_area_anchor_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/site_area_anchor.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

/// Where a dive with no GPS probably was: the site of the nearest dive in
/// time that has a located site, preferring the same trip.
///
/// Every instant is built with DateTime.utc: dive times are stored as wall
/// clock stamped UTC, and CI runs under a non-UTC time zone.
void main() {
  late SiteRepository sites;
  late DiveRepository dives;
  late SiteAreaAnchorRepository anchors;

  // The dive being named: noon on 10 November.
  final at = DateTime.utc(2026, 11, 10, 12);

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
    dives = DiveRepository();
    anchors = SiteAreaAnchorRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<DiveSite> site(
    String id, {
    GeoPoint? location = const GeoPoint(12.08, -68.28),
    String? island,
    String? region,
    String? country,
    String? diverId,
  }) => sites.createSite(
    DiveSite(
      id: id,
      name: id,
      location: location,
      island: island,
      region: region,
      country: country,
      diverId: diverId,
    ),
  );

  Future<void> dive(
    String id, {
    required DateTime when,
    DateTime? entryTime,
    DiveSite? at,
    String? tripId,
    String? diverId,
  }) => dives.createDive(
    Dive(
      id: id,
      diveNumber: 1,
      dateTime: when,
      entryTime: entryTime,
      maxDepth: 18,
      site: at,
      tripId: tripId,
      diverId: diverId,
    ),
  );

  Future<void> trip(String id) => TripRepository().createTrip(
    Trip(
      id: id,
      name: id,
      startDate: DateTime.utc(2026, 11, 1),
      endDate: DateTime.utc(2026, 11, 14),
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ),
  );

  Future<void> diver(String id) {
    final now = DateTime.now();
    return DiverRepository().createDiver(
      Diver(id: id, name: id, createdAt: now, updatedAt: now),
    );
  }

  group('forDive', () {
    test(
      'the nearest dive of the same trip wins, however far in time',
      () async {
        await trip('bonaire');
        final inTrip = await site('in-trip', island: 'Bonaire');
        final other = await site('other', location: const GeoPoint(50, 4));
        await dive(
          'old',
          when: at.subtract(const Duration(days: 9)),
          at: inTrip,
          tripId: 'bonaire',
        );
        await dive(
          'recent',
          when: at.subtract(const Duration(hours: 1)),
          at: other,
        );

        final anchor = await anchors.forDive(at: at, tripId: 'bonaire');

        expect(
          anchor,
          const SiteAreaAnchor(
            point: GeoPoint(12.08, -68.28),
            placeLabel: 'Bonaire',
          ),
        );
      },
    );

    test('within a trip the nearest in time wins', () async {
      await trip('bonaire');
      final far = await site('far', location: const GeoPoint(12.2, -68.3));
      final near = await site('near', location: const GeoPoint(12.1, -68.3));
      await dive(
        'd1',
        when: at.subtract(const Duration(days: 2)),
        at: far,
        tripId: 'bonaire',
      );
      await dive(
        'd2',
        when: at.add(const Duration(hours: 3)),
        at: near,
        tripId: 'bonaire',
      );

      final anchor = await anchors.forDive(at: at, tripId: 'bonaire');

      expect(anchor!.point, const GeoPoint(12.1, -68.3));
    });

    test('without a trip match the nearest dive within 3 days wins', () async {
      final before = await site('before', location: const GeoPoint(1, 1));
      final after = await site('after', location: const GeoPoint(2, 2));
      await dive('d1', when: at.subtract(const Duration(days: 2)), at: before);
      await dive('d2', when: at.add(const Duration(days: 1)), at: after);

      final anchor = await anchors.forDive(at: at);

      expect(anchor!.point, const GeoPoint(2, 2));
    });

    test('a dive exactly 3 days away counts', () async {
      final edge = await site('edge');
      await dive('d1', when: at.subtract(const Duration(days: 3)), at: edge);

      expect(await anchors.forDive(at: at), isNotNull);
    });

    test('a dive a minute past 3 days does not', () async {
      final edge = await site('edge');
      await dive(
        'd1',
        when: at.subtract(const Duration(days: 3, minutes: 1)),
        at: edge,
      );

      expect(await anchors.forDive(at: at), isNull);
    });

    test('a trip dive outside the window beats nothing nearer', () async {
      await trip('bonaire');
      final inTrip = await site('in-trip');
      await dive(
        'old',
        when: at.subtract(const Duration(days: 9)),
        at: inTrip,
        tripId: 'bonaire',
      );

      // No trip given: nine days is outside the window.
      expect(await anchors.forDive(at: at), isNull);
      // The same trip: found.
      expect(await anchors.forDive(at: at, tripId: 'bonaire'), isNotNull);
    });

    test('a dive whose site has no coordinates is skipped', () async {
      final unlocated = await site('unlocated', location: null);
      final located = await site('located', location: const GeoPoint(3, 3));
      await dive(
        'd1',
        when: at.subtract(const Duration(hours: 1)),
        at: unlocated,
      );
      await dive(
        'd2',
        when: at.subtract(const Duration(hours: 5)),
        at: located,
      );

      final anchor = await anchors.forDive(at: at);

      expect(anchor!.point, const GeoPoint(3, 3));
    });

    test('a dive with no site is skipped', () async {
      await dive('d1', when: at.subtract(const Duration(hours: 1)));

      expect(await anchors.forDive(at: at), isNull);
    });

    test('the dive being edited is excluded', () async {
      final here = await site('here');
      await dive('editing', when: at, at: here);

      expect(
        await anchors.forDive(at: at, excludeDiveIds: ['editing']),
        isNull,
      );
      expect(await anchors.forDive(at: at), isNotNull);
    });

    test("another diver's dives are ignored", () async {
      await diver('ana');
      await diver('ben');
      final bens = await site('bens', diverId: 'ben');
      await dive(
        'd1',
        when: at.subtract(const Duration(hours: 1)),
        at: bens,
        diverId: 'ben',
      );

      expect(await anchors.forDive(at: at, diverId: 'ana'), isNull);
      expect(await anchors.forDive(at: at, diverId: 'ben'), isNotNull);
    });

    test('the entry time is used when a dive has one', () async {
      final byEntry = await site('by-entry', location: const GeoPoint(4, 4));
      final byDate = await site('by-date', location: const GeoPoint(5, 5));
      // Dated a day away, but its entry time is ten minutes away.
      await dive(
        'd1',
        when: at.subtract(const Duration(days: 1)),
        entryTime: at.subtract(const Duration(minutes: 10)),
        at: byEntry,
      );
      await dive('d2', when: at.subtract(const Duration(hours: 2)), at: byDate);

      final anchor = await anchors.forDive(at: at);

      expect(anchor!.point, const GeoPoint(4, 4));
    });

    test('the place label is the island, else region, else country', () async {
      await dive(
        'd1',
        when: at.subtract(const Duration(hours: 1)),
        at: await site('s1', region: 'Palawan', country: 'Philippines'),
      );
      expect((await anchors.forDive(at: at))!.placeLabel, 'Palawan');

      await dive(
        'd2',
        when: at.subtract(const Duration(minutes: 30)),
        at: await site('s2', country: 'Egypt'),
      );
      expect((await anchors.forDive(at: at))!.placeLabel, 'Egypt');

      await dive(
        'd3',
        when: at.subtract(const Duration(minutes: 10)),
        at: await site('s3', island: '  '),
      );
      expect((await anchors.forDive(at: at))!.placeLabel, isNull);
    });
  });

  group('forDives', () {
    test('uses the earliest selected dive and its trip', () async {
      await trip('bonaire');
      final inTrip = await site('in-trip', island: 'Bonaire');
      await dive(
        'named',
        when: at.subtract(const Duration(days: 6)),
        at: inTrip,
        tripId: 'bonaire',
      );
      await dive('sel-1', when: at, tripId: 'bonaire');
      await dive('sel-2', when: at.add(const Duration(hours: 3)));

      final anchor = await anchors.forDives(['sel-2', 'sel-1']);

      expect(anchor!.placeLabel, 'Bonaire');
    });

    test('excludes every selected dive', () async {
      final here = await site('here');
      await dive('sel-1', when: at, at: here);
      await dive('sel-2', when: at.add(const Duration(hours: 3)), at: here);

      expect(await anchors.forDives(['sel-1', 'sel-2']), isNull);
    });

    test('with no ids returns null', () async {
      expect(await anchors.forDives(const []), isNull);
    });

    test('with ids that no longer exist returns null', () async {
      expect(await anchors.forDives(['gone']), isNull);
    });
  });
}
