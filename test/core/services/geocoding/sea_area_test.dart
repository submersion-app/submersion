import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/geocoding/sea_area.dart';

/// A 10x10 degree square with its lower-left corner at [lon], [lat].
SeaAreaRing _square(double lon, double lat, double size) => SeaAreaRing(
  Float64List.fromList([
    lon,
    lat,
    lon + size,
    lat,
    lon + size,
    lat + size,
    lon,
    lat + size,
    lon,
    lat,
  ]),
);

void main() {
  group('SeaAreaRing', () {
    test('derives its bounding box from the coordinates', () {
      final ring = _square(10, 20, 5);
      expect(ring.minLon, 10);
      expect(ring.minLat, 20);
      expect(ring.maxLon, 15);
      expect(ring.maxLat, 25);
    });

    test('contains interior points and rejects exterior ones', () {
      final ring = _square(0, 0, 10);
      expect(ring.containsPoint(5, 5), isTrue);
      expect(ring.containsPoint(-1, 5), isFalse);
      expect(ring.containsPoint(11, 5), isFalse);
      expect(ring.containsPoint(5, -1), isFalse);
      expect(ring.containsPoint(5, 11), isFalse);
    });

    test('measures distance to the nearest edge in kilometres', () {
      final ring = _square(0, 0, 10);
      // One degree of latitude due south of the southern edge.
      expect(ring.distanceKm(5, -1), closeTo(110.6, 1.0));
      // Longitude shrinks with latitude: one degree west of the western
      // edge at 60 degrees north is about half a degree of latitude.
      final northern = _square(0, 55, 10);
      expect(northern.distanceKm(-1, 60), closeTo(55.7, 2.0));
    });

    test('reports zero distance for a point on the ring', () {
      expect(_square(0, 0, 10).distanceKm(0, 5), closeTo(0, 0.001));
    });
  });

  group('SeaAreaPolygon', () {
    test('excludes points that fall inside a hole', () {
      final polygon = SeaAreaPolygon(
        outer: _square(0, 0, 10),
        holes: [_square(4, 4, 2)],
      );
      expect(polygon.contains(1, 1), isTrue);
      expect(polygon.contains(5, 5), isFalse);
    });

    test('measures distance to hole edges as well as the outer ring', () {
      final polygon = SeaAreaPolygon(
        outer: _square(0, 0, 10),
        holes: [_square(4, 4, 2)],
      );
      // Deep inside the hole but close to its western edge.
      expect(polygon.distanceKm(4.2, 5), lessThan(30));
    });
  });

  group('SeaArea', () {
    test('parses the shipped JSON shape', () {
      final area = SeaArea.fromJson(<String, dynamic>{
        'name': 'Test Sea',
        'bbox': <dynamic>[0, 0, 10, 10],
        'area': 100.0,
        'polygons': <dynamic>[
          <String, dynamic>{
            'outer': <dynamic>[0, 0, 10, 0, 10, 10, 0, 10, 0, 0],
            'holes': <dynamic>[
              <dynamic>[4, 4, 6, 4, 6, 6, 4, 6, 4, 4],
            ],
          },
        ],
      });

      expect(area.name, 'Test Sea');
      expect(area.areaSquareDegrees, 100.0);
      expect(area.polygons.single.holes, hasLength(1));
      expect(area.contains(1, 1), isTrue);
      expect(area.contains(5, 5), isFalse);
    });

    test('names itself in a language it has, and English otherwise', () {
      final area = SeaArea(
        name: 'Red Sea',
        minLon: 0,
        minLat: 0,
        maxLon: 10,
        maxLat: 10,
        areaSquareDegrees: 100,
        polygons: [SeaAreaPolygon(outer: _square(0, 0, 10))],
        localizedNames: const {'de': 'Rotes Meer'},
      );

      expect(area.nameIn('de'), 'Rotes Meer');
      expect(area.nameIn('en'), 'Red Sea');
      expect(area.nameIn('hu'), 'Red Sea');
    });

    test('parses the names map, and tolerates its absence', () {
      Map<String, dynamic> json(Map<String, dynamic> extra) => {
        'name': 'Test Sea',
        'bbox': <dynamic>[0, 0, 10, 10],
        'area': 100.0,
        'polygons': <dynamic>[
          <String, dynamic>{
            'outer': <dynamic>[0, 0, 10, 0, 10, 10, 0, 10, 0, 0],
          },
        ],
        ...extra,
      };

      final translated = SeaArea.fromJson(
        json({
          'names': <String, dynamic>{'de': 'Testsee'},
        }),
      );
      expect(translated.nameIn('de'), 'Testsee');

      // Areas Wikidata had no label for ship without the key at all.
      final plain = SeaArea.fromJson(json({}));
      expect(plain.localizedNames, isEmpty);
      expect(plain.nameIn('de'), 'Test Sea');
    });

    test('rejects points outside its bounding box without ring work', () {
      final area = SeaArea(
        name: 'Test Sea',
        minLon: 0,
        minLat: 0,
        maxLon: 10,
        maxLat: 10,
        areaSquareDegrees: 100,
        polygons: [SeaAreaPolygon(outer: _square(0, 0, 10))],
      );
      expect(area.contains(50, 50), isFalse);
      expect(area.isNear(50, 50, 4), isFalse);
      expect(area.isNear(10.01, 5, 4), isTrue);
    });
  });
}
