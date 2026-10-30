import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// Source types whose items the upload pipeline will carry to a media
/// store. Shared with the pipeline so the tile badge and the pipeline can
/// never disagree about what is uploadable.
const Set<MediaSourceType> kUploadableSources = {
  MediaSourceType.platformGallery,
  MediaSourceType.localFile,
  MediaSourceType.serviceConnector,
};

/// Connector videos never download their original in v1 (Lightroom spec:
/// match + thumbnail only), so the store carries only their thumb and
/// their backed-up signal is the thumb stamp rather than the original.
bool isThumbOnlyMedia(MediaItem item) =>
    item.sourceType == MediaSourceType.serviceConnector &&
    item.mediaType == MediaType.video;

/// Whether [item]'s stamps were made in a store other than [storeId]
/// (issue #3569): it names another store and still carries a stamp. With
/// no store named, nothing is elsewhere.
bool stampedElsewhere(MediaItem item, String? storeId) {
  final owner = item.remoteStoreId;
  return storeId != null &&
      owner != null &&
      owner != storeId &&
      (item.remoteUploadedAt != null ||
          item.remoteThumbUploadedAt != null ||
          item.remoteCompressedUploadedAt != null);
}

/// Whether a device attached to [storeId] takes over rows stamped in
/// another store (issue #3569): only when its store is the one the library
/// announces, or none is announced. A device left on an older store leaves
/// them alone, so two devices on different stores never trade a row.
bool takesOverStores(String? storeId, String? announcedStoreId) =>
    announcedStoreId == null || storeId == announcedStoreId;

/// [item] as the store [storeId] sees it (issue #3482): stamps made in
/// another store say nothing about this one, so they are dropped, with the
/// rendition facts they describe. Stamps naming no store predate the column
/// and stand, as do all stamps when no store is named.
MediaItem stampsInStore(MediaItem item, String? storeId) {
  final owner = item.remoteStoreId;
  if (storeId == null || owner == null || owner == storeId) return item;
  return item.copyWith(
    remoteUploadedAt: null,
    remoteThumbUploadedAt: null,
    remoteCompressedUploadedAt: null,
    compressedLevel: null,
    compressedSizeBytes: null,
  );
}

/// Whether [item] already exists in the attached media store, [storeId]
/// when known. Mirrors the pipeline's own dedup check so a tile never
/// reports "not backed up" for an item the pipeline would skip as already
/// uploaded.
bool isBackedUp(MediaItem item, {String? storeId}) {
  final seen = stampsInStore(item, storeId);
  return isThumbOnlyMedia(seen)
      ? seen.remoteThumbUploadedAt != null
      : seen.remoteUploadedAt != null ||
            seen.remoteCompressedUploadedAt != null;
}
