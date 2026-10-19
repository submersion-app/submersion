import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/domain/map_utils.dart';

void main() {
  group('clampRegionToWorld', () {
    test('leaves a rectangle inside the world as it is', () {
      final region = clampRegionToWorld(
        const LatLng(10, 20),
        const LatLng(30, 40),
      );

      expect(region.southWest, const LatLng(10, 20));
      expect(region.northEast, const LatLng(30, 40));
      expect(region.crossesDateLine, isFalse);
    });

    test('moves a rectangle drawn on the next world east back', () {
      // Palau (134 E) seen one world copy to the east is at 494 E.
      final region = clampRegionToWorld(
        const LatLng(6, 493),
        const LatLng(8, 495),
      );

      expect(region.southWest.longitude, closeTo(133, 1e-9));
      expect(region.northEast.longitude, closeTo(135, 1e-9));
      expect(region.crossesDateLine, isFalse);
    });

    test('moves a rectangle drawn on the world to the west back', () {
      final region = clampRegionToWorld(
        const LatLng(6, -227),
        const LatLng(8, -225),
      );

      expect(region.southWest.longitude, closeTo(133, 1e-9));
      expect(region.northEast.longitude, closeTo(135, 1e-9));
      expect(region.crossesDateLine, isFalse);
    });

    test('flags a rectangle that crosses the date line, east edge at 180', () {
      final region = clampRegionToWorld(
        const LatLng(-20, 170),
        const LatLng(-10, 190),
      );

      expect(region.crossesDateLine, isTrue);
      expect(region.southWest.longitude, 170);
      expect(region.northEast.longitude, 180);
    });

    test('flags a rectangle that crosses the date line in the west copy', () {
      final region = clampRegionToWorld(
        const LatLng(-20, -200),
        const LatLng(-10, -170),
      );

      expect(region.crossesDateLine, isTrue);
      expect(region.southWest.longitude, closeTo(160, 1e-9));
    });

    test('a rectangle ending exactly on 180 does not cross it', () {
      final region = clampRegionToWorld(
        const LatLng(-20, 170),
        const LatLng(-10, 180),
      );

      expect(region.crossesDateLine, isFalse);
      expect(region.northEast.longitude, 180);
    });

    test('a rectangle 360 degrees wide or more is the whole world', () {
      final region = clampRegionToWorld(
        const LatLng(-30, -200),
        const LatLng(30, 250),
      );

      expect(region.southWest.longitude, -180);
      expect(region.northEast.longitude, 180);
      expect(region.crossesDateLine, isFalse);
    });

    test('exactly 360 degrees wide is the whole world too', () {
      final region = clampRegionToWorld(
        const LatLng(0, 10),
        const LatLng(10, 370),
      );

      expect(region.southWest.longitude, -180);
      expect(region.northEast.longitude, 180);
    });

    test('holds latitudes to the web Mercator limit', () {
      final region = clampRegionToWorld(
        const LatLng(-89, 0),
        const LatLng(89, 10),
      );

      expect(region.southWest.latitude, closeTo(-85.0511, 1e-9));
      expect(region.northEast.latitude, closeTo(85.0511, 1e-9));
    });
  });

  group('longitudeSpans', () {
    test('is one span for a box inside the world', () {
      expect(longitudeSpans(10, 40), [(west: 10, east: 40)]);
    });

    test('moves a box on another copy of the world back', () {
      final spans = longitudeSpans(493, 495);
      expect(spans, hasLength(1));
      expect(spans.single.west, closeTo(133, 1e-9));
      expect(spans.single.east, closeTo(135, 1e-9));
    });

    test('is two spans, one each side, for a box across the date line', () {
      final spans = longitudeSpans(170, 190);
      expect(spans, hasLength(2));
      expect(spans[0], (west: 170, east: 180));
      expect(spans[1].west, -180);
      expect(spans[1].east, closeTo(-170, 1e-9));
    });

    test('is the whole world for a box 360 degrees wide or more', () {
      expect(longitudeSpans(-200, 250), [(west: -180, east: 180)]);
    });
  });
}
