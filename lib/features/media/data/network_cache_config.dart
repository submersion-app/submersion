// The caps on Flutter's in-memory decoded-image cache, applied at app boot
// and again whenever the diver changes the size, via [applyMediaCacheCaps].
//
// Only the memory caps live here. There is deliberately no byte cap for the
// `cached_network_image` disk cache: `flutter_cache_manager` exposes
// `maxNrOfCacheObjects` and `stalePeriod` but no byte budget, so honouring
// one would mean a custom `BaseCacheManager` with hand-rolled eviction, and a
// named cache manager would relocate the cache directory and orphan the
// existing one. A `kDiskCacheCapBytes` constant used to be declared here and
// wired to nothing, which claimed a guarantee the app did not provide. What
// actually governs that cache is `DefaultCacheManager`'s own defaults, and
// its real size is reported on the Storage usage page next to the clear
// button that already worked. See issue #1375. (The thumbnail disk cache is a
// different cache with a real cap: see `MediaCacheStore`.)
//
// Memory caps are wired via [PaintingBinding.instance.imageCache] because
// every image the app shows, local or network, resolves through the global
// Flutter image cache, so the byte cap is honoured immediately for in-RAM
// decoded images.

import 'package:flutter/painting.dart';

import 'package:submersion/features/media/data/media_cache_settings.dart';

/// Upper bound on the number of decoded images held in memory at once.
///
/// The Flutter image cache enforces both this object count and the byte cap.
/// It was 200, which for small thumbnails was reached long before the bytes
/// were, and at the smallest thumbnail size a large window shows more than
/// 200 tiles at once. 2000 leaves the byte cap, which the diver sets, as the
/// limit that matters (issue #3337).
const int kMemoryCacheCapObjects = 2000;

/// Applies [memoryBytes] and [kMemoryCacheCapObjects] to the global Flutter
/// [PaintingBinding.imageCache]. With no [memoryBytes] the default size
/// applies.
///
/// Memory only. Idempotent; safe to call multiple times. Lowering the byte
/// cap evicts down to it at once.
void applyMediaCacheCaps({int? memoryBytes}) {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSizeBytes =
      memoryBytes ?? const MediaCacheSettings().memoryCacheBytes;
  cache.maximumSize = kMemoryCacheCapObjects;
}
