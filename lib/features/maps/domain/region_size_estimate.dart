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
/// Only regions in [measuredRegionIds], the ones that own a per-region store,
/// count. A region downloaded before per-region stores recorded a flat
/// 20 KiB per tile, a guess rather than a measurement, so learning from it
/// would only echo that guess back. A measured region reporting no size or
/// no tiles is skipped too. Weighted by tile count (total bytes over total
/// tiles), so a big region outweighs a small one.
///
/// Falls back to [fallbackBytesPerTile] when no region qualifies.
int averageBytesPerTile(
  Iterable<CachedRegion> regions, {
  required Set<String> measuredRegionIds,
}) {
  var bytes = 0;
  var tiles = 0;
  for (final region in regions) {
    if (!measuredRegionIds.contains(region.id)) continue;
    if (region.sizeBytes <= 0 || region.tileCount <= 0) continue;
    bytes += region.sizeBytes;
    tiles += region.tileCount;
  }
  if (tiles == 0) return fallbackBytesPerTile;
  return (bytes / tiles).round().clamp(1, fallbackBytesPerTile * 4).toInt();
}

/// Estimated bytes to store [tiles] tiles, from the diver's own downloads.
int estimateRegionBytes(
  int tiles,
  Iterable<CachedRegion> regions, {
  required Set<String> measuredRegionIds,
}) =>
    tiles * averageBytesPerTile(regions, measuredRegionIds: measuredRegionIds);
