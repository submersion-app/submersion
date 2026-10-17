import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/local_thumbnail_cache.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_tile_image_memo.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

const _log = LoggerService('purgeMediaCaches');

/// Clears [items] out of this device's caches once their rows have left the
/// library (issue #3337): unlinking a photo removes its thumbnail from disk
/// and its decoded images from memory, not just its row.
///
/// The original file is never touched, here or anywhere on the unlink path.
///
/// Copies fetched from the media store ([store]) are removed only for a
/// content hash that no remaining row uses, as [hashStillReferenced] reports
/// it: the same photo on two dives is two rows over one hash, and unlinking
/// one must not cost the other its cached original. A thumbnail of a local
/// file is removed regardless, since making it again is one local decode.
///
/// Never throws. This runs after a deletion that has already succeeded, and
/// anything left behind is bounded by the caches' own eviction.
Future<void> purgeMediaCaches(
  Iterable<MediaItem> items, {
  required LocalThumbnailCache thumbnails,
  required MediaTileImageMemo memo,
  Future<MediaCacheStore> Function()? store,
  Future<bool> Function(String contentHash)? hashStillReferenced,
}) async {
  final purged = items.toList();
  try {
    await memo.evictItems([for (final item in purged) item.id]);
  } on Object catch (e) {
    _log.debug('Could not evict decoded images', error: e);
  }
  for (final item in purged) {
    await thumbnails.remove(item);
  }
  if (store == null || hashStillReferenced == null) return;
  final hashes = {
    for (final item in purged)
      if (item.contentHash case final hash? when hash.length >= 2) hash,
  };
  for (final hash in hashes) {
    try {
      if (await hashStillReferenced(hash)) continue;
      final cache = await store();
      for (final kind in MediaCacheKind.values) {
        await cache.remove(hash, kind);
      }
    } on Object catch (e) {
      _log.debug('Could not remove cached store copies of $hash', error: e);
    }
  }
}
