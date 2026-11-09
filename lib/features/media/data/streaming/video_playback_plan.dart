import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_streaming.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/streaming/media_stream_relay.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// How a video plays on this device (issue #4162).
sealed class VideoPlayback {
  const VideoPlayback();
}

/// From a file: the installed apps.
class FilePlayback extends VideoPlayback {
  const FilePlayback(this.path);

  final String path;
}

/// From the media store, streamed: a browser. The player tries
/// [candidates] in order.
class StreamPlayback extends VideoPlayback {
  const StreamPlayback(this.candidates);

  final List<StreamCandidate> candidates;
}

/// Not at all, and why.
class NoPlayback extends VideoPlayback {
  const NoPlayback(this.reason);

  final NoPlaybackReason reason;
}

enum NoPlaybackReason {
  /// Nothing to play: no file here and nothing in the store.
  notFound,

  /// The store streams only through the stream worker, which this browser
  /// does not offer (a private window).
  needsNormalWindow,
}

/// One version of a stored video a player can try.
class StreamCandidate {
  const StreamCandidate({
    required this.tier,
    required this.open,
    required this.close,
  });

  final ServedTier tier;

  /// A fresh address for the player each call: a new presigned URL, a
  /// still-fresh temporary link, or a new relay ticket.
  final Future<Uri> Function() open;

  /// Lets go of an address [open] gave (a relay ticket); nothing for a
  /// direct link.
  final void Function(Uri url) close;
}

/// How [item] streams from [store] in a browser: the original, then the
/// rendition, as the store's own resolver orders them. [relay] is the
/// stream worker's, or null when this browser has none.
VideoPlayback planStoreVideo(
  MediaItem item, {
  required MediaObjectStore store,
  required MediaStreamRelay? relay,
}) {
  final hash = item.contentHash;
  if (hash == null) return const NoPlayback(NoPlaybackReason.notFound);
  final versions = <({ServedTier tier, String key, String extension})>[
    if (item.remoteUploadedAt != null)
      (
        tier: ServedTier.original,
        key: StoreKeys.objectKey(
          hash,
          extension: StoreKeys.extensionFor(item.originalFilename),
        ),
        extension: StoreKeys.extensionFor(item.originalFilename),
      ),
    if (item.remoteCompressedUploadedAt != null)
      (
        tier: ServedTier.rendition,
        key: StoreKeys.renditionKey(
          hash,
          ext: StoreKeys.renditionExtension(isVideo: true),
        ),
        extension: StoreKeys.renditionExtension(isVideo: true),
      ),
  ];
  if (versions.isEmpty) return const NoPlayback(NoPlaybackReason.notFound);

  if (store is DirectLinkStore) {
    final links = store as DirectLinkStore;
    return StreamPlayback([
      for (final version in versions)
        StreamCandidate(
          tier: version.tier,
          open: () async => (await links.directLink(version.key)).url,
          close: (_) {},
        ),
    ]);
  }
  if (store is RangeReadStore) {
    if (relay == null) {
      return const NoPlayback(NoPlaybackReason.needsNormalWindow);
    }
    return StreamPlayback([
      for (final version in versions)
        StreamCandidate(
          tier: version.tier,
          open: () async => relay.register(
            store: store,
            key: version.key,
            extension: version.extension,
          ),
          close: relay.release,
        ),
    ]);
  }
  return const NoPlayback(NoPlaybackReason.notFound);
}
