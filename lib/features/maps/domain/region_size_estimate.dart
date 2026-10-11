import 'package:submersion/features/maps/domain/entities/cached_region.dart';

/// What the region download dialog assumes per tile when the diver has no
/// measured region to learn from.
///
/// Deliberately generous: real tiles average far less (open water is mostly
/// skipped or tiny), so the first estimate errs on the large side.
const int fallbackBytesPerTile = 30 * 1024;

/// Average stored size of one tile, learned from the regions already
/// downloaded.
///
/// Only regions with a measured size count: a region downloaded before
/// per-region stores reports `sizeBytes` 0 because its tiles cannot be told
/// apart from the rest, and counting it would drag the average towards zero.
/// Weighted by tile count (total bytes over total tiles), so a big region
/// outweighs a small one.
///
/// Falls back to [fallbackBytesPerTile] when no region qualifies.
int averageBytesPerTile(Iterable<CachedRegion> regions) {
  var bytes = 0;
  var tiles = 0;
  for (final region in regions) {
    if (region.sizeBytes <= 0 || region.tileCount <= 0) continue;
    bytes += region.sizeBytes;
    tiles += region.tileCount;
  }
  if (tiles == 0) return fallbackBytesPerTile;
  return (bytes / tiles).round().clamp(1, fallbackBytesPerTile * 4).toInt();
}

/// Estimated bytes to store [tiles] tiles, from the diver's own downloads.
int estimateRegionBytes(int tiles, Iterable<CachedRegion> regions) =>
    tiles * averageBytesPerTile(regions);
