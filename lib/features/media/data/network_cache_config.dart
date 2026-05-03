// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 16. Constants for the network media cache caps surfaced as
// `cached_network_image` (memory) + `flutter_cache_manager` (disk) limits.
//
// Phase 3c will surface these as user-editable Settings; for Phase 3a
// they live as `const`s here and are applied at app boot via
// [applyMediaCacheCaps].
//
// Deviations from the plan:
//
// - The plan asks for "500 MB disk + 75 MB memory caps" configured via
//   `DefaultCacheManager`-style configuration. `flutter_cache_manager`
//   3.4.1 only exposes `maxNrOfCacheObjects` (object count) on its `Config`
//   class — there is no public API to express a byte-size cap on the disk
//   cache, and `DefaultCacheManager` is a singleton constructed with the
//   default `Config` we cannot mutate after the fact. The byte cap is
//   therefore declared as a constant for now and not wired to disk in 3a;
//   Phase 3c is expected to introduce a custom `BaseCacheManager` subclass
//   passed via `CachedNetworkImage(cacheManager: ...)` that honours the
//   byte budget directly. See `kDiskCacheCapBytes` doc comment.
// - Memory cap is wired today via [PaintingBinding.instance.imageCache]
//   because `cached_network_image` resolves through the global Flutter
//   image cache, so the byte cap is honoured immediately for in-RAM
//   decoded images.

import 'package:flutter/painting.dart';

/// Target on-disk LRU budget for cached remote media (500 MB).
///
/// Phase 3a: declarative only. `flutter_cache_manager` 3.4.1 only exposes
/// an object-count cap (`maxNrOfCacheObjects`); a real byte budget needs
/// a custom `BaseCacheManager` subclass which Phase 3c will introduce
/// alongside the Settings UI for adjusting these caps.
const int kDiskCacheCapBytes = 500 * 1024 * 1024;

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
/// Disk-side caps ([kDiskCacheCapBytes]) are *not* wired here — see the
/// constant's doc comment. Idempotent; safe to call multiple times.
//
// Configures global Flutter image cache; exercised at app boot by
// `MediaSourcesApp.bootstrap()` in Phase 3c.
// coverage:ignore-start
void applyMediaCacheCaps() {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSizeBytes = kMemoryCacheCapBytes;
  cache.maximumSize = kMemoryCacheCapObjects;
}

// coverage:ignore-end
