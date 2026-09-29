import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';

void main() {
  group('shortestLongitudeSpan', () {
    test('returns null for no longitudes', () {
      expect(shortestLongitudeSpan(const []), isNull);
    });

    test('is a zero-width span for a single longitude', () {
      final span = shortestLongitudeSpan(const [42])!;
      expect(span.west, 42);
      expect(span.east, 42);
    });

    test('is the ordinary min-to-max span when nothing crosses 180', () {
      final span = shortestLongitudeSpan(const [-80, -60, -70])!;
      expect(span.west, -80);
      expect(span.east, -60);
    });

    test('wraps across the date line for Australia and the Pacific', () {
      // Australia (150E), Fiji (178E) and Tahiti (149W): the short way
      // round runs east from Australia across 180, not west through Africa.
      final span = shortestLongitudeSpan(const [150, 178, -149])!;
      expect(span.west, 150);
      expect(span.east, closeTo(211, 1e-9));
      expect(span.east - span.west, closeTo(61, 1e-9));
    });

    test('keeps east at or past west so the width is east minus west', () {
      final span = shortestLongitudeSpan(const [179, -179])!;
      expect(span.west, 179);
      expect(span.east, closeTo(181, 1e-9));
    });
  });
}
