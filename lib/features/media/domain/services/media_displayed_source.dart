import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// Where to tell the user this item's bytes came from.
///
/// Prefers what ACTUALLY served the last resolution, which is the interesting
/// answer: a gallery-linked row whose asset was deleted is served from the
/// cloud store instead, and only the observed value can say so.
///
/// Falls back to the source the row was linked from when nothing has resolved
/// yet. Without the fallback every badge would pop in a frame or two after the
/// thumbnail, which on a scrolling grid reads as flicker rather than as
/// information.
ServedFrom displayedSourceFor(MediaItem item, ServingFacts serving) =>
    serving.servedFrom ?? expectedSourceFor(item.sourceType);

/// The source a row of this type would normally be served from.
///
/// Exhaustive with no default arm, so a new [MediaSourceType] has to decide
/// what it looks like rather than silently inheriting someone else's glyph.
ServedFrom expectedSourceFor(MediaSourceType type) => switch (type) {
  MediaSourceType.platformGallery => ServedFrom.platformGallery,
  MediaSourceType.localFile => ServedFrom.localDisk,

  // Both are plain URLs over HTTP; a manifest entry is only a different way
  // of having discovered one.
  MediaSourceType.networkUrl => ServedFrom.networkUrl,
  MediaSourceType.manifestEntry => ServedFrom.networkUrl,

  // The network variants rather than the cache ones: a cache hit is a fact
  // about this session that only an observation can establish, so guessing it
  // would over-claim.
  MediaSourceType.serviceConnector => ServedFrom.connectorNetwork,
  MediaSourceType.mediaStore => ServedFrom.storeNetwork,

  MediaSourceType.signature => ServedFrom.embedded,
};
