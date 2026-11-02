import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/services/logger_service.dart';

const _log = LoggerService('cacheLocation');

const _appDir = 'Submersion';
const _mediaCacheDir = 'media_cache';
const _mediaPoolDirs = ['thumbs', 'originals', 'renditions'];
const _videoThumbnailsDir = 'video_thumbnails';
const _pdfThumbnailsDir = 'pdf_thumbnails';

/// Where this device keeps what it can make or fetch again, as against what
/// it is still working on.
///
/// On iOS and Android the regenerable caches live in the OS cache directory
/// (issue #3341), so Android's "Clear cache" removes them, iOS can reclaim them
/// when short of space, and neither goes into a device backup. On desktop there
/// is no system "clear cache", so everything stays in application support,
/// where users would look.
///
/// The media cache's staging and transcode scratch stays in application support
/// everywhere: an upload in flight, or a finished video transcode waiting on a
/// retry, must not be left to the OS to delete. Both directories share a volume
/// on a phone, so a staged file still moves into a pool with a rename.
class CacheLocation {
  const CacheLocation({
    required Directory regenerableBase,
    required Directory supportBase,
    required this.osManagesCaches,
  }) : _regenerableBase = regenerableBase,
       _supportBase = supportBase;

  final Directory _regenerableBase;
  final Directory _supportBase;

  /// Whether the OS may empty the regenerable caches on its own.
  final bool osManagesCaches;

  /// Holds the thumbnail, original and rendition pools.
  Directory get mediaPools => _in(_regenerableBase, _mediaCacheDir);

  /// Holds the media cache's staging and transcode directories.
  Directory get mediaScratch => _in(_supportBase, _mediaCacheDir);

  Directory get videoThumbnails => _in(_regenerableBase, _videoThumbnailsDir);

  Directory get pdfThumbnails => _in(_regenerableBase, _pdfThumbnailsDir);

  Directory _in(Directory base, String name) =>
      Directory(p.join(base.path, name));

  /// Each regenerable directory's place in application support, paired with
  /// where it lives now.
  Iterable<(Directory, Directory)> get _moves sync* {
    for (final pool in _mediaPoolDirs) {
      yield (
        Directory(p.join(mediaScratch.path, pool)),
        Directory(p.join(mediaPools.path, pool)),
      );
    }
    yield (_in(_supportBase, _videoThumbnailsDir), videoThumbnails);
    yield (_in(_supportBase, _pdfThumbnailsDir), pdfThumbnails);
  }
}

/// The location for a platform where the OS does or does not manage caches.
Future<CacheLocation> resolveCacheLocation({
  required bool osManagesCaches,
  required Future<Directory> Function() cacheDirectory,
  required Future<Directory> Function() supportDirectory,
}) async {
  final support = Directory(p.join((await supportDirectory()).path, _appDir));
  return CacheLocation(
    regenerableBase: osManagesCaches
        ? Directory(p.join((await cacheDirectory()).path, _appDir))
        : support,
    supportBase: support,
    osManagesCaches: osManagesCaches,
  );
}

/// Moves regenerable caches out of application support, where every build
/// before issue #3341 kept them, and returns those it could not move.
///
/// A rename rather than a delete, since it costs one call per directory and
/// spares the diver regenerating thumbnails or downloading originals again. The
/// index stays valid because its paths are relative to the pool root.
///
/// Finds nothing to do on every launch after the first.
Future<List<Directory>> moveCachesToOsDirectory(CacheLocation location) async {
  if (!location.osManagesCaches) return const [];
  final leftovers = <Directory>[];
  for (final (from, to) in location._moves) {
    try {
      if (!await from.exists()) continue;
      await to.parent.create(recursive: true);
      await from.rename(to.path);
    } on FileSystemException catch (e) {
      _log.warning('Could not move ${from.path}', error: e);
      leftovers.add(from);
    }
  }
  return leftovers;
}

/// Deletes caches that could not be moved. Everything in them can be made
/// again, and the issue asks that nothing is left behind.
///
/// Never throws. A directory that survives is found again next launch.
Future<void> deleteLeftoverCaches(List<Directory> leftovers) async {
  for (final directory in leftovers) {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException catch (e) {
      _log.warning('Could not delete ${directory.path}', error: e);
    }
  }
}

Future<CacheLocation>? _cacheLocationFuture;

/// This platform's [CacheLocation], with any old caches already moved.
///
/// The move happens here so it finishes before any caller has a path, which
/// means nothing can write to the new location first. Leftovers are deleted
/// without waiting, because a recursive delete of a large pool is slow and a
/// grid tile may be waiting on this lookup.
///
/// Memoized for the process. Several call sites resolve this, each one a
/// platform channel round trip for a path that does not change while the
/// process lives. A failed lookup is deliberately not cached, so the next
/// caller retries rather than inheriting a permanent failure from one bad
/// moment at boot.
Future<CacheLocation> cacheLocation() async {
  final cached = _cacheLocationFuture;
  if (cached != null) return cached;

  final pending = _resolveAndMove();
  _cacheLocationFuture = pending;
  try {
    return await pending;
  } catch (_) {
    _cacheLocationFuture = null;
    rethrow;
  }
}

Future<CacheLocation> _resolveAndMove() async {
  final location = await resolveCacheLocation(
    osManagesCaches: Platform.isIOS || Platform.isAndroid,
    cacheDirectory: getApplicationCacheDirectory,
    supportDirectory: getApplicationSupportDirectory,
  );
  unawaited(deleteLeftoverCaches(await moveCachesToOsDirectory(location)));
  return location;
}

/// Drops the memoized [cacheLocation], so a test that overrides the
/// path_provider platform channel is not served another test's directory.
@visibleForTesting
void resetCacheLocationForTesting() => _cacheLocationFuture = null;
