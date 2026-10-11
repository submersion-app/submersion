import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/maps/domain/entities/cached_region.dart';
import 'package:submersion/features/maps/domain/region_size_estimate.dart';

CachedRegion _region({required int tileCount, required int sizeBytes}) =>
    CachedRegion(
      id: 'r$tileCount',
      name: 'Region',
      minLat: 0,
      maxLat: 1,
      minLng: 0,
      maxLng: 1,
      minZoom: 8,
      maxZoom: 16,
      tileCount: tileCount,
      sizeBytes: sizeBytes,
      createdAt: DateTime(2026, 1, 1),
      lastAccessedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('averageBytesPerTile', () {
    test('falls back to the flat guess with no regions', () {
      expect(averageBytesPerTile(const []), fallbackBytesPerTile);
    });

    test('ignores regions whose size was never measured', () {
      // sizeBytes 0 marks a region downloaded before per-region stores.
      final legacy = _region(tileCount: 7352, sizeBytes: 0);
      expect(averageBytesPerTile([legacy]), fallbackBytesPerTile);
    });

    test('learns the average from a measured region', () {
      final measured = _region(tileCount: 1000, sizeBytes: 1500000);
      expect(averageBytesPerTile([measured]), 1500);
    });

    test('weights regions by tile count, not by region', () {
      final big = _region(tileCount: 9000, sizeBytes: 9000 * 1000);
      final small = _region(tileCount: 1000, sizeBytes: 1000 * 5000);
      // (9,000,000 + 5,000,000) / 10,000 tiles = 1400 bytes per tile.
      expect(averageBytesPerTile([big, small]), 1400);
    });

    test('a legacy region does not pull a measured average down', () {
      final measured = _region(tileCount: 1000, sizeBytes: 1500000);
      final legacy = _region(tileCount: 50000, sizeBytes: 0);
      expect(averageBytesPerTile([measured, legacy]), 1500);
    });
  });

  test('estimateRegionBytes multiplies the tiles by the learned average', () {
    final measured = _region(tileCount: 1000, sizeBytes: 1500000);
    expect(estimateRegionBytes(2000, [measured]), 3000000);
  });
}
