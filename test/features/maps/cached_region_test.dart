import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/maps/domain/entities/cached_region.dart';

void main() {
  group('CachedRegion', () {
    late CachedRegion region;

    setUp(() {
      region = CachedRegion(
        id: 'test-id',
        name: 'Test Region',
        minLat: 20.0,
        maxLat: 22.0,
        minLng: -88.0,
        maxLng: -86.0,
        minZoom: 8,
        maxZoom: 16,
        tileCount: 1000,
        sizeBytes: 1024 * 1024 * 25, // 25 MB
        createdAt: DateTime(2024, 1, 15),
        lastAccessedAt: DateTime(2024, 1, 20),
      );
    });

    test('formattedSize returns bytes for small sizes', () {
      final small = region.copyWith(sizeBytes: 500);
      expect(small.formattedSize, '500 B');
    });

    test('formattedSize returns KB for kilobyte sizes', () {
      final kb = region.copyWith(sizeBytes: 1024 * 50); // 50 KB
      expect(kb.formattedSize, '50.0 KB');
    });

    test('formattedSize returns MB for megabyte sizes', () {
      expect(region.formattedSize, '25.0 MB');
    });

    test('formattedSize returns GB for gigabyte sizes', () {
      final gb = region.copyWith(sizeBytes: 1024 * 1024 * 1024 * 2); // 2 GB
      expect(gb.formattedSize, '2.00 GB');
    });

    test('center calculates correctly', () {
      expect(region.center.latitude, 21.0);
      expect(region.center.longitude, -87.0);
    });

    test('southWest returns correct corner', () {
      expect(region.southWest.latitude, 20.0);
      expect(region.southWest.longitude, -88.0);
    });

    test('northEast returns correct corner', () {
      expect(region.northEast.latitude, 22.0);
      expect(region.northEast.longitude, -86.0);
    });

    test('copyWith preserves unmodified values', () {
      final modified = region.copyWith(name: 'Modified Name');

      expect(modified.name, 'Modified Name');
      expect(modified.id, region.id);
      expect(modified.minLat, region.minLat);
      expect(modified.maxLat, region.maxLat);
      expect(modified.tileCount, region.tileCount);
    });

    test('copyWith updates multiple values', () {
      final modified = region.copyWith(
        name: 'New Name',
        tileCount: 2000,
        sizeBytes: 1024 * 1024 * 50,
      );

      expect(modified.name, 'New Name');
      expect(modified.tileCount, 2000);
      expect(modified.sizeBytes, 1024 * 1024 * 50);
    });

    test('equality based on all properties', () {
      final same = CachedRegion(
        id: 'test-id',
        name: 'Test Region',
        minLat: 20.0,
        maxLat: 22.0,
        minLng: -88.0,
        maxLng: -86.0,
        minZoom: 8,
        maxZoom: 16,
        tileCount: 1000,
        sizeBytes: 1024 * 1024 * 25,
        createdAt: DateTime(2024, 1, 15),
        lastAccessedAt: DateTime(2024, 1, 20),
      );

      expect(region, equals(same));
    });

    test('different ids are not equal', () {
      final different = region.copyWith(id: 'different-id');
      expect(region, isNot(equals(different)));
    });
  });
}
