import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/image_resize_job.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/native_image_resize.dart';

/// How many thumbnails are made at once.
///
/// Each one decodes a full-size original, so this is a memory bound as much
/// as a CPU one. Tiles beyond it wait their turn showing the placeholder.
const int kLocalThumbnailConcurrency = 4;

/// Turns a resize request into a JPEG file. [resizeToJpegFileNative] in
/// production.
typedef ThumbnailWriter =
    Future<ImageResizeResult> Function(ImageResizeRequest request);

/// A photo's original as [LocalThumbnailCache.generateFrom]'s loader hands
/// it over: exactly one of [file] and [bytes].
typedef ThumbnailSource = ({File? file, Uint8List? bytes});

/// On-disk thumbnails of photos linked from local files (issue #3337).
///
/// Such a photo had no thumbnail anywhere: every gallery tile was decoded
/// from the full-size original, and decoded again whenever the result had
/// left memory. This keeps one small JPEG per photo in the media cache's
/// thumbnail pool, so it is counted against the diver's disk cache size and
/// evicted with everything else there.
///
/// Photos from the device photo library are not handled here, since the
/// operating system already thumbnails those; nor are videos and PDFs, which
/// have poster caches of their own.
///
/// Nothing here throws. This runs while grid tiles render, and a cache that
/// cannot be opened or written must cost a thumbnail, not a tile: every
/// failure is a null, and the caller serves the original as it always did.
class LocalThumbnailCache {
  LocalThumbnailCache({
    required Future<MediaCacheStore> Function() store,
    ThumbnailWriter write = resizeToJpegFileNative,
    int maxConcurrent = kLocalThumbnailConcurrency,
  }) : assert(maxConcurrent > 0),
       _store = store,
       _write = write,
       _maxConcurrent = maxConcurrent;

  /// Longest edge of a thumbnail, and its JPEG quality. The same as the
  /// thumbnails uploaded to the media store, so the two look alike.
  static const int maxDimension = 512;
  static const int jpegQuality = 80;

  /// Looked up per call rather than held: the store captures the cache
  /// database, which a database location change replaces.
  final Future<MediaCacheStore> Function() _store;
  final ThumbnailWriter _write;
  final int _maxConcurrent;
  final _log = LoggerService.forClass(
    LocalThumbnailCache,
    category: LogCategory.media,
  );

  /// Generations in flight by key, so tiles showing the same file share one.
  final Map<String, Future<File?>> _generating = {};
  var _running = 0;

  /// Keys waiting for a slot, oldest first, and each one's waiter.
  final Queue<String> _waiting = Queue<String>();
  final Map<String, Completer<void>> _waiters = {};

  /// The pool key of [item]'s thumbnail: a hash of where its file is.
  ///
  /// Built from the row alone, so finding a thumbnail never touches the
  /// original; that is the whole saving. The cost is that a file replaced in
  /// place keeps its old thumbnail until `LocalFileResolver`'s deferred check
  /// notices the newer modification time.
  ///
  /// Deliberately not the content hash, though the pool is otherwise keyed
  /// by it. A thumbnail fetched from the media store for another device's
  /// row sits under that hash, and serving it from here would report bytes
  /// that came from the cloud as read off this device's disk. The prefix
  /// keeps the two key spaces apart by construction.
  ///
  /// The prefix also carries a version. Thumbnails made under the first one
  /// could hold a neighbouring photo's picture (two staged at one path), and
  /// nothing on disk says which, so none of them is served; they leave
  /// through the pool's ordinary eviction.
  static String keyFor(MediaItem item) {
    final path = item.localPath ?? item.filePath ?? '';
    final ref = item.bookmarkRef ?? '';
    // Rows with no pointer at all cannot resolve; the id keeps them from
    // sharing a key with one another.
    final basis = path.isEmpty && ref.isEmpty
        ? 'local-thumb-v2\u0000id\u0000${item.id}'
        : 'local-thumb-v2\u0000$path\u0000$ref';
    return sha256.convert(utf8.encode(basis)).toString();
  }

  /// [item]'s thumbnail if one has been made, without reading the original
  /// or the database.
  Future<File?> cached(MediaItem item) async {
    try {
      return await (await _store()).peekThumb(keyFor(item));
    } on Object catch (e) {
      _log.debug('Thumbnail cache unavailable for ${item.id}', error: e);
      return null;
    }
  }

  /// Makes [item]'s thumbnail from the original, given as [file] or as
  /// [bytes], and stores it. Null when the original cannot be decoded or the
  /// cache cannot be written.
  Future<File?> generate(MediaItem item, {File? file, Uint8List? bytes}) {
    assert((file == null) != (bytes == null), 'pass exactly one source');
    return generateFrom(item, () async => (file: file, bytes: bytes));
  }

  /// [generate] with the original fetched by [load], called only once this
  /// generation holds a slot. Null from [load] means there is no original
  /// to be had.
  ///
  /// On the bookmark and content URI paths fetching the original means
  /// reading all of it into memory, so a request must not hold one while it
  /// waits: a fast scroll queues a request per tile it passes.
  ///
  /// A request for a key already in flight joins that generation without
  /// calling its [load], and moves it to the front of the queue: it is
  /// being asked for now, so its tile is on screen now.
  Future<File?> generateFrom(
    MediaItem item,
    Future<ThumbnailSource?> Function() load,
  ) {
    final key = keyFor(item);
    final inFlight = _generating[key];
    if (inFlight != null) {
      _promote(key);
      return inFlight;
    }
    // A block body: remove() returns this very future, and whenComplete
    // waits on a future its callback returns.
    return _generating[key] = _generate(item, key, load).whenComplete(() {
      _generating.remove(key);
    });
  }

  Future<File?> _generate(
    MediaItem item,
    String key,
    Future<ThumbnailSource?> Function() load,
  ) async {
    await _acquire(key);
    File? staged;
    try {
      final source = await load();
      if (source == null) return null;
      final (:file, :bytes) = source;
      assert((file == null) != (bytes == null), 'load exactly one source');
      final store = await _store();
      staged = await store.stagingFile();
      final request = file != null
          ? ImageResizeRequest.fromFile(
              sourcePath: file.path,
              destinationPath: staged.path,
              declaredName: item.originalFilename,
              maxDimension: maxDimension,
              jpegQuality: jpegQuality,
            )
          : ImageResizeRequest.fromBytes(
              bytes: bytes!,
              destinationPath: staged.path,
              declaredName: item.originalFilename,
              maxDimension: maxDimension,
              jpegQuality: jpegQuality,
            );
      final result = await _write(request);
      if (result.outcome != ImageResizeOutcome.written) {
        final error = result.error;
        _log.debug(
          'No thumbnail for ${item.id}: ${result.outcome.name}'
          '${error == null ? '' : ' ($error)'}',
        );
        return null;
      }
      return await store.put(
        key,
        MediaCacheKind.thumb,
        staged,
        extension: MediaCacheStore.thumbExtension,
      );
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Thumbnail generation failed for ${item.id}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      _release();
      // put() moves the staged file into the pool, so one still here is the
      // debris of a failure.
      await _discard(staged);
    }
  }

  /// Deletes [item]'s thumbnail, if it has one.
  Future<void> remove(MediaItem item) async {
    try {
      await (await _store()).remove(keyFor(item), MediaCacheKind.thumb);
    } on Object catch (e) {
      _log.debug('Could not remove the thumbnail of ${item.id}', error: e);
    }
  }

  Future<void> _discard(File? staged) async {
    if (staged == null) return;
    try {
      if (await staged.exists()) await staged.delete();
    } on FileSystemException {
      // Best-effort: an undeletable staging file is not worth surfacing.
    }
  }

  Future<void> _acquire(String key) {
    if (_running < _maxConcurrent) {
      _running++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiting.add(key);
    _waiters[key] = waiter;
    return waiter.future;
  }

  /// Moves [key] to the newest end of the queue, if it is waiting.
  void _promote(String key) {
    if (!_waiters.containsKey(key)) return;
    _waiting
      ..remove(key)
      ..addLast(key);
  }

  /// Hands the slot straight to the newest waiter, or frees it.
  ///
  /// Newest first: nothing cancels a wait, so after a fast scroll the queue
  /// is mostly tiles already scrolled past, and the ones on screen now are
  /// the ones asked for last.
  void _release() {
    if (_waiting.isNotEmpty) {
      _waiters.remove(_waiting.removeLast())!.complete();
    } else {
      _running--;
    }
  }
}
