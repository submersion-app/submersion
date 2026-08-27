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

/// Whether [item] already exists in the attached media store. Mirrors the
/// pipeline's own dedup check so a tile never reports "not backed up" for
/// an item the pipeline would skip as already uploaded.
bool isBackedUp(MediaItem item) => isThumbOnlyMedia(item)
    ? item.remoteThumbUploadedAt != null
    : item.remoteUploadedAt != null || item.remoteCompressedUploadedAt != null;
