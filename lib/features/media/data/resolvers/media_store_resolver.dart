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
    if (thumbnail && item.mediaType == MediaType.video) {
      // A video's original and rendition are both video: they can only ever
      // render as the movie placeholder, so degrading to them buys nothing
      // and costs a full download (potentially over cellular) per grid tile.
      // Give up instead and let the caller keep its native placeholder.
      return null;
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
    // The pipeline always uploads thumbs as JPEG, whatever the source's own
    // format. For a video that JPEG is a poster frame, so the result is
    // decodable as an image even though the row is a video -- something only
    // this side knows, and the flag is how MediaItemView is told.
    final isPoster = item.mediaType == MediaType.video;
    File? staging;
    try {
      final cached = await _cache.get(hash, MediaCacheKind.thumb);
      if (cached != null) return FileData(file: cached, isPoster: isPoster);
      staging = await _cache.stagingFile();
      await _store.getFile(StoreKeys.thumbKey(hash), staging);
      // No hash verification: thumb bytes are derived; the key carries the
      // original's hash purely for addressing.
      final file = await _cache.put(
        hash,
        MediaCacheKind.thumb,
        staging,
        extension: 'jpg',
      );
      return FileData(file: file, isPoster: isPoster);
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
        extension: ext,
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
      final file = await _cache.put(
        hash,
        MediaCacheKind.original,
        staging,
        extension: _cacheExtensionFor(item, extension),
      );
      return FileData(file: file);
    } on Exception catch (e) {
      _log.warning('Store fallback failed for ${item.id}: $e');
      return null;
    } finally {
      await _discardStaging(staging);
    }
  }

  /// Extension for the CACHED copy, which is a different question from the
  /// store key's.
  ///
  /// The key records how the object was addressed when it was uploaded and
  /// can never be recomputed differently — that is where the bytes live. The
  /// cache name is local and disposable, and its only job is to let the OS
  /// identify the file. Those come apart when a row has no usable filename:
  /// [StoreKeys.extensionFor] yields [StoreKeys.unknownExtension], which is a
  /// fine address and a useless container hint, so a video cached under it
  /// stays unplayable (`AVURLAsset` infers the container from the path
  /// extension alone).
  ///
  /// Only videos are rescued. A photo's bytes are identified by sniffing, so
  /// giving it a guessed image extension would risk contradicting them for no
  /// gain. Videos fall back to the local path's extension — still recorded on
  /// the row even after the file itself is gone — and then to the media
  /// type's container. That last guess is safe: AVFoundation opens QuickTime
  /// and MP4 bytes under either extension, and rejects only names it does not
  /// recognise at all.
  String _cacheExtensionFor(MediaItem item, String storeExtension) {
    if (storeExtension != StoreKeys.unknownExtension) return storeExtension;
    if (item.mediaType != MediaType.video) return storeExtension;
    final localPath = item.localPath ?? '';
    final dot = localPath.lastIndexOf('.');
    if (dot >= 0 && dot < localPath.length - 1) {
      final ext = localPath.substring(dot + 1).toLowerCase();
      if (_extPattern.hasMatch(ext)) return ext;
    }
    return 'mp4';
  }

  static final RegExp _extPattern = RegExp(r'^[a-z0-9]{1,8}$');

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
