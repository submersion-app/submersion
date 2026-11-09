import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_bytes_memory.dart';
import 'package:submersion/features/media/data/resolvers/media_store_fetches.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// A browser's [MediaStoreFetches] (issue #4121): each tier is downloaded
/// into page memory, kept in [MediaBytesMemory] and served as [BytesData].
///
/// Thumbnails serve for every row. An original or a rendition serves only
/// for a photo, the one kind a page shows from bytes. A document needs a
/// file to render, so it keeps its thumbnail. A video is never downloaded
/// here either: the viewer streams it to the player from a signed link or
/// through the media stream worker (`planStoreVideo`, issue #4162).
class MemoryMediaStoreFetches implements MediaStoreFetches {
  MemoryMediaStoreFetches({
    required MediaObjectStore store,
    required MediaBytesMemory memory,
  }) : _store = store,
       _memory = memory;

  final MediaObjectStore _store;
  final MediaBytesMemory _memory;
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
  }) => _serve(
    item,
    // A thumb overwritten in place (a PDF's) is fresh only against its own
    // stamp, so each stamp is its own entry.
    memoryKey: freshAfter == null
        ? '$hash#thumb'
        : '$hash#thumb#${freshAfter.millisecondsSinceEpoch}',
    storeKey: StoreKeys.thumbKey(hash),
    tier: ServedTier.thumbnail,
    isPoster: isPoster,
  );

  @override
  Future<MediaSourceData?> rendition(MediaItem item, String hash) async {
    if (item.mediaType != MediaType.photo) return null;
    return _serve(
      item,
      memoryKey:
          '$hash#rendition'
          '#${item.remoteCompressedUploadedAt?.millisecondsSinceEpoch ?? 0}',
      storeKey: StoreKeys.renditionKey(
        hash,
        ext: StoreKeys.renditionExtension(isVideo: false),
      ),
      tier: ServedTier.rendition,
    );
  }

  @override
  Future<MediaSourceData?> original(MediaItem item, String hash) async {
    if (item.mediaType != MediaType.photo) return null;
    // A browser decodes only the web's own formats: a HEIC or camera RAW
    // original would not show, so the resolver falls through to the JPEG
    // rendition instead.
    final extension = StoreKeys.extensionFor(item.originalFilename);
    if (!_decodable.contains(extension)) return null;
    return _serve(
      item,
      memoryKey: '$hash#original',
      storeKey: StoreKeys.objectKey(hash, extension: extension),
      tier: ServedTier.original,
      // Derived tiers carry the hash only for addressing; the original is
      // the bytes the hash names.
      verify: (bytes) => sha256.convert(bytes).toString() == hash,
    );
  }

  /// The image formats every target browser decodes.
  static const _decodable = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  Future<MediaSourceData?> _serve(
    MediaItem item, {
    required String memoryKey,
    required String storeKey,
    required ServedTier tier,
    bool isPoster = false,
    bool Function(Uint8List bytes)? verify,
  }) async {
    final kept = _memory.get(memoryKey);
    if (kept != null) {
      return BytesData(
        bytes: kept,
        isPoster: isPoster,
        servedFrom: ServedFrom.storeCache,
        servedTier: tier,
      );
    }
    try {
      final bytes = await _store.getBytes(storeKey);
      if (verify != null && !verify(bytes)) {
        _log.warning('Store object failed hash verification for ${item.id}');
        return null;
      }
      _memory.put(memoryKey, bytes);
      return BytesData(
        bytes: bytes,
        isPoster: isPoster,
        servedFrom: ServedFrom.storeNetwork,
        servedTier: tier,
      );
    } on Exception catch (e) {
      _log.warning('Store fetch failed for ${item.id} ($tier): $e');
      return null;
    }
  }
}
