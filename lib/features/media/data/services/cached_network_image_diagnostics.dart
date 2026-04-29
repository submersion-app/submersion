import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/services/logger_service.dart';

/// Async function that resolves the on-disk cache directory used by
/// `cached_network_image`'s `DefaultCacheManager`. Tests can inject a temp
/// directory; production wires the real `path_provider` lookup.
typedef CacheDirectoryResolver = Future<Directory> Function();

/// Async callback that clears every cache entry. Tests inject a recording
/// noop; production calls `DefaultCacheManager().emptyCache()`.
typedef ClearCacheCallback = Future<void> Function();

/// Surfaces cache size + clear actions for the Settings → Network Sources →
/// Cache management card.
///
/// The disk cache lives at `<temp>/<DefaultCacheManager.key>`. We compute
/// size by walking the directory tree on demand because
/// `flutter_cache_manager` doesn't expose an aggregate size API.
///
/// Cache size is a best-effort metric — IO errors are swallowed and the
/// surface degrades to `0 bytes` rather than crashing the page.
class CachedNetworkImageDiagnostics {
  final CacheDirectoryResolver _resolveCacheDirectory;
  final ClearCacheCallback _clearCacheCallback;
  final _log = LoggerService.forClass(CachedNetworkImageDiagnostics);

  CachedNetworkImageDiagnostics({
    CacheDirectoryResolver? resolveCacheDirectory,
    ClearCacheCallback? clearCacheCallback,
  }) : _resolveCacheDirectory =
           resolveCacheDirectory ?? _defaultResolveCacheDirectory,
       _clearCacheCallback = clearCacheCallback ?? _defaultClearCacheCallback;

  /// Returns the total bytes used by the disk cache. Walks the directory.
  /// Returns 0 on any error.
  Future<int> cacheSize() async {
    try {
      final dir = await _resolveCacheDirectory();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += await entity.length();
          } on FileSystemException {
            // Skip transient unreadable entries; the user might be
            // browsing media right as we measure.
          }
        }
      }
      return total;
    } catch (e, st) {
      _log.warning('Cache size lookup failed: $e', stackTrace: st);
      return 0;
    }
  }

  /// Clears every cache entry. Logs the failure and rethrows on error so
  /// callers can surface cache-clear failures (disk I/O, permission denied,
  /// etc.) in the UI rather than silently swallowing them.
  ///
  /// Throws on cache-clear failure (rare).
  Future<void> clearCache() async {
    try {
      _log.info('Clearing cached_network_image disk cache');
      await _clearCacheCallback();
      _log.info('Cleared cached_network_image disk cache');
    } catch (e, st) {
      _log.error('Cache clear failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

Future<Directory> _defaultResolveCacheDirectory() async {
  final base = await getTemporaryDirectory();
  return Directory(p.join(base.path, DefaultCacheManager.key));
}

Future<void> _defaultClearCacheCallback() => DefaultCacheManager().emptyCache();
