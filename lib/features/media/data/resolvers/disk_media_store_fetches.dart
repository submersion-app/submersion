import 'dart:io';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_fetches.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// The installed apps' [MediaStoreFetches]: each tier is downloaded into a
/// staging file and kept in the [MediaCacheStore] on disk, and served as
/// [FileData].
class DiskMediaStoreFetches implements MediaStoreFetches {
  DiskMediaStoreFetches({
    required MediaObjectStore store,
    required MediaCacheStore cache,
  }) : _store = store,
       _cache = cache;

  final MediaObjectStore _store;
  final MediaCacheStore _cache;
  static const _log = LoggerService(
    'MediaStoreResolver',
    category: LogCategory.media,
  );

  @override
  Future<MediaSourceData?> thumb(
    MediaItem item,
    String hash, {
    DateTime? freshAfter,
    required bool isPoster,
  }) async {
    File? staging;
    try {
      // The cheap hit first: one stat, no index read and write. [get] still
      // finds a thumbnail cached before they were all stored as JPEG.
      final version = freshAfter;
      final cached = version != null
          ? await _cache.get(hash, MediaCacheKind.thumb, freshAfter: version)
          : await _cache.peekThumb(hash) ??
                await _cache.get(hash, MediaCacheKind.thumb);
      if (cached != null) {
        return FileData(
          file: cached,
          isPoster: isPoster,
          servedFrom: ServedFrom.storeCache,
          servedTier: ServedTier.thumbnail,
        );
      }
      staging = await _cache.stagingFile();
      await _store.getFile(StoreKeys.thumbKey(hash), staging);
      // No hash verification: thumb bytes are derived; the key carries the
      // original's hash purely for addressing.
      final file = await _cache.put(
        hash,
        MediaCacheKind.thumb,
        staging,
        sourceVersion: version?.millisecondsSinceEpoch,
        extension: 'jpg',
      );
      return FileData(
        file: file,
        isPoster: isPoster,
        servedFrom: ServedFrom.storeNetwork,
        servedTier: ServedTier.thumbnail,
      );
    } on Exception catch (e) {
      _log.warning('Thumb fetch failed for ${item.id}: $e');
      return null;
    } finally {
      await _discardStaging(staging);
    }
  }

  @override
  Future<MediaSourceData?> rendition(MediaItem item, String hash) async {
    final ext = StoreKeys.renditionExtension(
      isVideo: item.mediaType == MediaType.video,
    );
    File? staging;
    try {
      final cached = await _cache.get(
        hash,
        MediaCacheKind.rendition,
        freshAfter: item.remoteCompressedUploadedAt,
      );
      if (cached != null) {
        return FileData(
          file: cached,
          servedFrom: ServedFrom.storeCache,
          servedTier: ServedTier.rendition,
        );
      }
      staging = await _cache.stagingFile();
      await _store.getFile(StoreKeys.renditionKey(hash, ext: ext), staging);
      final file = await _cache.put(
        hash,
        MediaCacheKind.rendition,
        staging,
        sourceVersion: item.remoteCompressedUploadedAt?.millisecondsSinceEpoch,
        extension: ext,
      );
      return FileData(
        file: file,
        servedFrom: ServedFrom.storeNetwork,
        servedTier: ServedTier.rendition,
      );
    } on Exception catch (e) {
      _log.warning('Rendition fetch failed for ${item.id}: $e');
      return null;
    } finally {
      await _discardStaging(staging);
    }
  }

  @override
  Future<MediaSourceData?> original(MediaItem item, String hash) async {
    File? staging;
    try {
      final cached = await _cache.get(hash, MediaCacheKind.original);
      if (cached != null) {
        return FileData(
          file: cached,
          servedFrom: ServedFrom.storeCache,
          servedTier: ServedTier.original,
        );
      }

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
      return FileData(
        file: file,
        servedFrom: ServedFrom.storeNetwork,
        servedTier: ServedTier.original,
      );
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
