// Constants for the network media cache caps, surfaced as
// `cached_network_image` (memory) limits and applied at app boot via
// [applyMediaCacheCaps].
//
// Only the memory caps live here. There is deliberately no byte cap for the
// disk cache: `flutter_cache_manager` exposes `maxNrOfCacheObjects` and
// `stalePeriod` but no byte budget, so honouring one would mean a custom
// `BaseCacheManager` with hand-rolled eviction, and a named cache manager
// would relocate the cache directory and orphan the existing one. A
// `kDiskCacheCapBytes` constant used to be declared here and wired to
// nothing, which claimed a guarantee the app did not provide. What actually
// governs the disk cache is `DefaultCacheManager`'s own defaults, and its
// real size is now reported on the Storage usage page next to the clear
// button that already worked. See issue #1375.
//
// Memory caps are wired via [PaintingBinding.instance.imageCache] because
// `cached_network_image` resolves through the global Flutter image cache, so
// the byte cap is honoured immediately for in-RAM decoded images.

import 'package:flutter/painting.dart';

/// Live in-memory decoded-image budget (75 MB), applied to
/// [PaintingBinding.imageCache] at app boot via [applyMediaCacheCaps].
const int kMemoryCacheCapBytes = 75 * 1024 * 1024;

/// Heuristic upper bound on the number of decoded images held in memory
/// at once. The Flutter image cache enforces both this object count
/// *and* [kMemoryCacheCapBytes]; the count guard exists so a stream of
/// tiny thumbnails cannot blow past expectations even though each frame
/// is well under the byte cap.
const int kMemoryCacheCapObjects = 200;

/// Applies [kMemoryCacheCapBytes] / [kMemoryCacheCapObjects] to the
/// global Flutter [PaintingBinding.imageCache] at app boot.
///
/// Memory only. The disk cache is governed by `flutter_cache_manager`'s own
/// defaults; see the file header. Idempotent; safe to call multiple times.
//
// Configures the global Flutter image cache. Called once at app boot from
// `_bootstrap()` in `lib/main.dart`.
// coverage:ignore-start
void applyMediaCacheCaps() {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSizeBytes = kMemoryCacheCapBytes;
  cache.maximumSize = kMemoryCacheCapObjects;
}

// coverage:ignore-end
