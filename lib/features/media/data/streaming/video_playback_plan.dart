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

  /// An address for the player each call: a new presigned URL, a
  /// temporary link (reused only on the first call; a later call is a
  /// reopen after a failure, so it asks for a new one), or a new relay
  /// ticket.
  final Future<Uri> Function() open;

  /// Lets go of an address [open] gave (a relay ticket); nothing for a
  /// direct link.
  final void Function(Uri url) close;
}

/// One version of a stored video: where it is and what it is.
typedef _Version = ({ServedTier tier, String key, String extension});

/// The original's and the rendition's place in the store for a video with
/// [hash].
({_Version original, _Version rendition}) _versionsOf(
  MediaItem item,
  String hash,
) {
  final originalExtension = StoreKeys.extensionFor(item.originalFilename);
  final renditionExtension = StoreKeys.renditionExtension(isVideo: true);
  return (
    original: (
      tier: ServedTier.original,
      key: StoreKeys.objectKey(hash, extension: originalExtension),
      extension: originalExtension,
    ),
    rendition: (
      tier: ServedTier.rendition,
      key: StoreKeys.renditionKey(hash, ext: renditionExtension),
      extension: renditionExtension,
    ),
  );
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
  final (:original, :rendition) = _versionsOf(item, hash);
  final versions = [
    if (item.remoteUploadedAt != null) original,
    if (item.remoteCompressedUploadedAt != null) rendition,
  ];
  if (versions.isEmpty) return const NoPlayback(NoPlaybackReason.notFound);

  if (store case final DirectLinkStore links) {
    return StreamPlayback([
      for (final version in versions)
        _directCandidate(links, version.tier, version.key),
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

/// [item] stamped with the versions [store] holds, when its own stamps say
/// nothing of either: a row whose upload facts have not reached this
/// device. The gallery's tiles probe the store the same way
/// (`MediaStoreResolver.tryResolveProbed`), so a video whose poster shows
/// also plays. A row with a stamp comes back as it is, and a version the
/// store cannot vouch for (missing, or the HEAD failed) stays unstamped.
Future<MediaItem> withProbedStamps(
  MediaItem item, {
  required MediaObjectStore store,
}) async {
  final hash = item.contentHash;
  if (hash == null ||
      item.remoteUploadedAt != null ||
      item.remoteCompressedUploadedAt != null) {
    return item;
  }
  final (:original, :rendition) = _versionsOf(item, hash);
  final (originalAt, renditionAt) = await (
    _modifiedAt(store, original.key),
    _modifiedAt(store, rendition.key),
  ).wait;
  return item.copyWith(
    remoteUploadedAt: originalAt,
    remoteCompressedUploadedAt: renditionAt,
  );
}

/// When [store] last modified [key], or null when it does not hold it or
/// could not say.
Future<DateTime?> _modifiedAt(MediaObjectStore store, String key) async {
  try {
    return (await store.head(key))?.lastModified;
  } on Exception {
    return null;
  }
}

/// A candidate whose first open may reuse a still-fresh link and whose
/// later opens (reopens after a failure) ask the store for a new one.
StreamCandidate _directCandidate(
  DirectLinkStore links,
  ServedTier tier,
  String key,
) {
  var opened = false;
  return StreamCandidate(
    tier: tier,
    open: () async {
      final link = await links.directLink(key, fresh: opened);
      opened = true;
      return link.url;
    },
    close: (_) {},
  );
}
