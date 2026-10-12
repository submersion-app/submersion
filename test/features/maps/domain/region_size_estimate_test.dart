import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/maps/domain/entities/cached_region.dart';
import 'package:submersion/features/maps/domain/region_size_estimate.dart';

CachedRegion _region({
  required int tileCount,
  required int sizeBytes,
  String? id,
}) => CachedRegion(
  id: id ?? 'r$tileCount',
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
  // Only regions that own a per-region store have a measured size.
  Set<String> idsOf(Iterable<CachedRegion> regions) => {
    for (final r in regions) r.id,
  };

  group('averageBytesPerTile', () {
    test('falls back to the flat guess with no regions', () {
      expect(
        averageBytesPerTile(const [], measuredRegionIds: const {}),
        fallbackBytesPerTile,
      );
    });

    test('ignores a legacy region that recorded the old flat estimate', () {
      // Regions downloaded before per-region stores saved tiles * 20 KiB, a
      // guess rather than a measurement; they own no store of their own.
      final legacy = _region(tileCount: 7352, sizeBytes: 7352 * 20 * 1024);
      expect(
        averageBytesPerTile([legacy], measuredRegionIds: const {}),
        fallbackBytesPerTile,
      );
    });

    test('ignores a measured region that reports no size', () {
      final empty = _region(tileCount: 100, sizeBytes: 0);
      expect(
        averageBytesPerTile([empty], measuredRegionIds: idsOf([empty])),
        fallbackBytesPerTile,
      );
    });

    test('learns the average from a measured region', () {
      final measured = _region(tileCount: 1000, sizeBytes: 1500000);
      expect(
        averageBytesPerTile([measured], measuredRegionIds: idsOf([measured])),
        1500,
      );
    });

    test('weights regions by tile count, not by region', () {
      final big = _region(tileCount: 9000, sizeBytes: 9000 * 1000);
      final small = _region(tileCount: 1000, sizeBytes: 1000 * 5000);
      // (9,000,000 + 5,000,000) / 10,000 tiles = 1400 bytes per tile.
      expect(
        averageBytesPerTile([
          big,
          small,
        ], measuredRegionIds: idsOf([big, small])),
        1400,
      );
    });

    test('a legacy region does not skew a measured average', () {
      final measured = _region(tileCount: 1000, sizeBytes: 1500000);
      final legacy = _region(
        id: 'legacy',
        tileCount: 50000,
        sizeBytes: 50000 * 20 * 1024,
      );
      expect(
        averageBytesPerTile([
          measured,
          legacy,
        ], measuredRegionIds: idsOf([measured])),
        1500,
      );
    });
  });

  test('estimateRegionBytes multiplies the tiles by the learned average', () {
    final measured = _region(tileCount: 1000, sizeBytes: 1500000);
    expect(
      estimateRegionBytes(2000, [
        measured,
      ], measuredRegionIds: idsOf([measured])),
      3000000,
    );
  });
}
