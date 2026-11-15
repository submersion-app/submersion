import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_nearby.dart';

/// Scapa Flow. One thousandth of a degree of latitude is about 111 m.
const _lat = 58.9;
const _lon = -3.1;

/// A point [metersNorth] of the record under test.
GeoPoint _north(double metersNorth) =>
    GeoPoint(_lat + metersNorth / 111320, _lon);

CatalogueSite _record(
  String id,
  double metersNorth, {
  CatalogueKind kind = CatalogueKind.site,
}) => CatalogueSite(
  id: id,
  name: id,
  location: _north(metersNorth),
  source: 'osm',
  kind: kind,
);

SiteWithDiveCount _mine(
  String id,
  double metersNorth, {
  int dives = 0,
  String? catalogueId,
  Set<String> also = const {},
}) => SiteWithDiveCount(
  site: DiveSite(
    id: id,
    name: id,
    location: _north(metersNorth),
    catalogueId: catalogueId,
    catalogueAnswers: SiteCatalogueAnswers(also: also),
  ),
  diveCount: dives,
);

final _here = _record('here', 0);

void main() {
  test('the limits are the ones the design names', () {
    expect(kCatalogueNearbyRadiusMeters, 10000);
    expect(kCatalogueNearbyOwnLimit, 5);
    expect(kCatalogueNearbyRecordLimit, 6);
  });

  group('your sites', () {
    test('within 10 km, nearest first, with their dive counts', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: const [],
        userSites: [
          _mine('far', 8000, dives: 2),
          _mine('near', 1200, dives: 3),
          _mine('outside', 10100),
        ],
      );

      expect(nearby.yours.map((s) => s.site.id), ['near', 'far']);
      expect(nearby.yours.first.diveCount, 3);
      expect(nearby.yours.first.meters, closeTo(1200, 5));
    });

    test('at most five', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: const [],
        userSites: [for (var i = 1; i <= 8; i++) _mine('s$i', i * 500)],
      );

      expect(nearby.yours.map((s) => s.site.id), [
        's1',
        's2',
        's3',
        's4',
        's5',
      ]);
    });

    test('a site of the diver\'s without coordinates is left out', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: const [],
        userSites: const [
          SiteWithDiveCount(
            site: DiveSite(id: 'nowhere', name: 'nowhere'),
            diveCount: 9,
          ),
        ],
      );

      expect(nearby.yours, isEmpty);
    });
  });

  group('built-in sites', () {
    test('dive sites come before charted wrecks, each nearest first', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: [
          _record('wreck_near', 1000, kind: CatalogueKind.register),
          _record('site_far', 8000),
          _record('wreck_far', 4000, kind: CatalogueKind.register),
          _record('site_near', 2000),
        ],
        userSites: const [],
      );

      expect(nearby.builtIn.map((r) => r.record.id), [
        'site_near',
        'site_far',
        'wreck_near',
        'wreck_far',
      ]);
      expect(nearby.builtIn.first.meters, closeTo(2000, 5));
    });

    test('the record itself and anything past 10 km are left out', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: [_here, _record('outside', 10100), _record('inside', 9900)],
        userSites: const [],
      );

      expect(nearby.builtIn.map((r) => r.record.id), ['inside']);
    });

    test('a record the diver has, by link or after a merge, is left out', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: [
          _record('linked', 1000),
          _record('merged', 2000),
          _record('free', 3000),
        ],
        userSites: [
          _mine('a', 1000, catalogueId: 'linked', also: {'merged'}),
        ],
      );

      expect(nearby.builtIn.map((r) => r.record.id), ['free']);
    });

    test('a record an unlinked site of the diver\'s sits on is left out, '
        'as on the map', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: [_record('under_mine', 3000), _record('free', 5000)],
        userSites: [_mine('hand_made', 3050)],
      );

      expect(nearby.builtIn.map((r) => r.record.id), ['free']);
    });

    test('at most six', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: [for (var i = 1; i <= 9; i++) _record('r$i', i * 400)],
        userSites: const [],
      );

      expect(nearby.builtIn, hasLength(6));
      expect(nearby.builtIn.last.record.id, 'r6');
    });

    test('a crowded neighbourhood still lists six, none of them the '
        'diver\'s', () {
      // Forty charted wrecks within 10 km, the ten nearest already the
      // diver's own: the limit is of rows shown, not of records looked at.
      final wrecks = [
        for (var i = 1; i <= 40; i++)
          _record('w$i', i * 200, kind: CatalogueKind.register),
      ];
      final nearby = catalogueNearby(
        record: _here,
        candidates: wrecks,
        userSites: [
          for (var i = 1; i <= 10; i++)
            _mine('mine$i', i * 200, catalogueId: 'w$i'),
        ],
      );

      expect(nearby.builtIn.map((r) => r.record.id), [
        'w11',
        'w12',
        'w13',
        'w14',
        'w15',
        'w16',
      ]);
    });
  });

  group('your site here', () {
    test('the nearest unlinked site of the diver\'s within 150 m', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: const [],
        userSites: [_mine('further', 120), _mine('closest', 40)],
      );

      expect(nearby.here?.site.id, 'closest');
      expect(nearby.here?.meters, closeTo(40, 2));
    });

    test('not one past 150 m', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: const [],
        userSites: [_mine('neighbour', 160)],
      );

      expect(nearby.here, isNull);
    });

    test('not a linked site: it stands for a different record', () {
      final nearby = catalogueNearby(
        record: _here,
        candidates: const [],
        userSites: [_mine('east', 40, catalogueId: 'barracuda_east')],
      );

      expect(nearby.here, isNull);
      // It is still one of the diver's sites nearby.
      expect(nearby.yours.map((s) => s.site.id), ['east']);
    });
  });

  test('a record without coordinates has nothing near it', () {
    final nearby = catalogueNearby(
      record: const CatalogueSite(id: 'nowhere', name: 'x', source: 'osm'),
      candidates: [_record('a', 100)],
      userSites: [_mine('b', 100)],
    );

    expect(nearby.yours, isEmpty);
    expect(nearby.builtIn, isEmpty);
    expect(nearby.here, isNull);
    expect(nearby.isEmpty, isTrue);
  });

  test('isEmpty is about the two lists', () {
    expect(
      catalogueNearby(
        record: _here,
        candidates: const [],
        userSites: const [],
      ).isEmpty,
      isTrue,
    );
    expect(
      catalogueNearby(
        record: _here,
        candidates: [_record('a', 100)],
        userSites: const [],
      ).isEmpty,
      isFalse,
    );
  });
}
