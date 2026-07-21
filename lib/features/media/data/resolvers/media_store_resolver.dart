import 'dart:io';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Store-backed fallback resolution (design spec section 10). Deliberately
/// NOT a MediaSourceResolver and never registered under a MediaSourceType:
/// rows keep their native source type, so disconnecting the store degrades
/// every row to exactly the pre-store behavior.
class MediaStoreResolver {
  MediaStoreResolver({
    required MediaObjectStore store,
    required MediaCacheStore cache,
  }) : _store = store,
       _cache = cache;

  final MediaObjectStore _store;
  final MediaCacheStore _cache;
  final _log = LoggerService.forClass(MediaStoreResolver);

  /// Returns FileData when the bytes are cached or fetched (originals are
  /// hash-verified); null when this item is not confirmed in the store or
  /// any error occurs (the caller keeps its native UnavailableData).
  ///
  /// Thumbnail requests route to the thumb object when one was uploaded
  /// and degrade to the original otherwise (spec section 10). The thumb
  /// path needs only the thumb stamp: the pipeline uploads thumbs before
  /// originals, so another device can legitimately serve the thumb while
  /// the original is still in flight.
  Future<MediaSourceData?> tryResolveRemote(
    MediaItem item, {
    required bool thumbnail,
  }) async {
    final hash = item.contentHash;
    if (hash == null) return null;
    if (thumbnail && item.remoteThumbUploadedAt != null) {
      final thumb = await _fetchThumb(item, hash);
      if (thumb != null) return thumb;
      // Fall through: a missing/broken thumb degrades to the original.
    }
    if (item.remoteUploadedAt != null) {
      final original = await _fetchOriginal(item, hash);
      if (original != null) return original;
    }
    if (item.remoteCompressedUploadedAt != null) {
      return _fetchCompressed(item, hash);
    }
    return null;
  }

  Future<MediaSourceData?> _fetchThumb(MediaItem item, String hash) async {
    File? staging;
    try {
      final cached = await _cache.get(hash, MediaCacheKind.thumb);
      if (cached != null) return FileData(file: cached);
      staging = await _cache.stagingFile();
      await _store.getFile(StoreKeys.thumbKey(hash), staging);
      // No hash verification: thumb bytes are derived; the key carries the
      // original's hash purely for addressing.
      final file = await _cache.put(hash, MediaCacheKind.thumb, staging);
      return FileData(file: file);
    } on Exception catch (e) {
      _log.warning('Thumb fetch failed for ${item.id}: $e');
      return null;
    } finally {
      await _discardStaging(staging);
    }
  }

  /// Fetches the compressed rendition (spec section 11). Derived bytes, so no
  /// hash verification; validated against remoteCompressedUploadedAt so a
  /// re-uploaded (overwritten) rendition invalidates a stale cache entry.
  Future<MediaSourceData?> _fetchCompressed(MediaItem item, String hash) async {
    final ext = item.mediaType == MediaType.video ? 'mp4' : 'jpg';
    File? staging;
    try {
      final cached = await _cache.get(
        hash,
        MediaCacheKind.rendition,
        freshAfter: item.remoteCompressedUploadedAt,
      );
      if (cached != null) return FileData(file: cached);
      staging = await _cache.stagingFile();
      await _store.getFile(StoreKeys.renditionKey(hash, ext: ext), staging);
      final file = await _cache.put(
        hash,
        MediaCacheKind.rendition,
        staging,
        sourceVersion: item.remoteCompressedUploadedAt?.millisecondsSinceEpoch,
      );
      return FileData(file: file);
    } on Exception catch (e) {
      _log.warning('Rendition fetch failed for ${item.id}: $e');
      return null;
    } finally {
      await _discardStaging(staging);
    }
  }

  Future<MediaSourceData?> _fetchOriginal(MediaItem item, String hash) async {
    File? staging;
    try {
      final cached = await _cache.get(hash, MediaCacheKind.original);
      if (cached != null) return FileData(file: cached);

      staging = await _cache.stagingFile();
      final extension = StoreKeys.extensionFor(item.originalFilename);
      await _store.getFile(
        StoreKeys.objectKey(hash, extension: extension),
        staging,
      );
      final digest = await sha256OfFile(staging);
      if (digest.hash != hash) {
        _log.warning('Store object failed hash verification for ${item.id}');
        return null;
      }
      final file = await _cache.put(hash, MediaCacheKind.original, staging);
      return FileData(file: file);
    } on Exception catch (e) {
      _log.warning('Store fallback failed for ${item.id}: $e');
      return null;
    } finally {
      await _discardStaging(staging);
    }
  }

  /// cache.put moves the staging file into the pool, so anything still at
  /// the staging path after a fetch is the debris of a failed one
  /// (partial download, hash mismatch, put error).
  Future<void> _discardStaging(File? staging) async {
    if (staging == null) return;
    try {
      if (await staging.exists()) await staging.delete();
    } on FileSystemException {
      // Best-effort: an undeletable staging file is not worth surfacing.
    }
  }
}
