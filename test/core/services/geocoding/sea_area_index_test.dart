import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/geocoding/sea_area.dart';
import 'package:submersion/core/services/geocoding/sea_area_index.dart';

SeaArea _box(String name, double lon, double lat, double size) => SeaArea(
  name: name,
  minLon: lon,
  minLat: lat,
  maxLon: lon + size,
  maxLat: lat + size,
  areaSquareDegrees: size * size,
  polygons: [
    SeaAreaPolygon(
      outer: SeaAreaRing(
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
      ),
    ),
  ],
);

void main() {
  group('SeaAreaIndex', () {
    test('names the smallest area containing the point', () {
      // A small gulf sitting inside a large ocean, ordered as the generator
      // writes them: ascending by area.
      final index = SeaAreaIndex([
        _box('Small Gulf', 2, 2, 2),
        _box('Big Ocean', 0, 0, 20),
      ]);

      expect(index.nameAt(3, 3), 'Small Gulf');
      expect(index.nameAt(10, 10), 'Big Ocean');
    });

    test('returns null for a point in no area at all', () {
      final index = SeaAreaIndex([_box('Big Ocean', 0, 0, 20)]);
      expect(index.nameAt(50, 50), isNull);
    });

    test('claims points just outside a limit, up to the shore tolerance', () {
      final index = SeaAreaIndex([_box('Big Ocean', 0, 0, 20)]);

      // Roughly 2 km south of the southern limit: still the ocean.
      expect(index.nameAt(-0.018, 10), 'Big Ocean');
      // Roughly 11 km south: too far inland to be claimed.
      expect(index.nameAt(-0.1, 10), isNull);
    });

    test('picks the nearer coastline when two areas are both in range', () {
      final index = SeaAreaIndex([
        _box('West Sea', 0, 0, 10),
        _box('East Sea', 10.05, 0, 10),
      ]);

      // In the gap between them, but nearer the western limit.
      expect(index.nameAt(5, 10.01), 'West Sea');
      expect(index.nameAt(5, 10.04), 'East Sea');
    });

    test('parses the shipped JSON shape', () {
      final index = SeaAreaIndex.fromJson(<String, dynamic>{
        'areas': <dynamic>[
          <String, dynamic>{
            'name': 'Test Sea',
            'bbox': <dynamic>[0, 0, 10, 10],
            'area': 100.0,
            'polygons': <dynamic>[
              <String, dynamic>{
                'outer': <dynamic>[0, 0, 10, 0, 10, 10, 0, 10, 0, 0],
              },
            ],
          },
        ],
      });

      expect(index.areas, hasLength(1));
      expect(index.nameAt(5, 5), 'Test Sea');
    });
  });
}
