import 'dart:ui' show Size;

import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// Looks up the store-backed resolver for this device, or null when no media
/// store is attached. Deferred so building it (keychain read, store
/// construction) happens only when a row is confirmed uploaded.
typedef RemoteResolverLookup = Future<MediaStoreResolver?> Function();

/// Whether the row's synced stamps say the media store holds bytes for it.
///
/// A thumbnail request is satisfied by the thumb stamp alone because thumbs
/// upload before originals. The compressed stamp counts as confirmation in
/// its own right: an upload quality other than "original" uploads a rendition
/// and leaves [MediaItem.remoteUploadedAt] null permanently, so gating on the
/// original alone made every such photo unviewable on other devices even
/// though the store resolver can serve the rendition.
bool storeConfirmed(MediaItem item, {required bool thumbnail}) =>
    item.contentHash != null &&
    (item.remoteUploadedAt != null ||
        item.remoteCompressedUploadedAt != null ||
        (thumbnail && item.remoteThumbUploadedAt != null));

/// The full verdict for one tile: what to draw and how it was reached.
class TileResolution {
  const TileResolution({
    required this.data,
    this.videoPosterMissing = false,
    this.documentRenderable = false,
    this.storeFallbackUsed = false,
    this.nativeFailure,
  });

  final MediaSourceData data;

  /// The store holds this video but no poster was ever stamped, so the tile
  /// shows the movie icon rather than a failure.
  final bool videoPosterMissing;

  /// The store handed back a rendered page-1 poster for a document.
  final bool documentRenderable;

  /// Whether the store was consulted at all, including the case where the
  /// fallback was attempted and there was no store on this device to answer.
  final bool storeFallbackUsed;

  /// The native source's failure, kept even when the store covered for it,
  /// because the orphan flag is about the origin.
  final UnavailableKind? nativeFailure;
}

/// The store-fallback decision `MediaItemView` makes for every tile, as a
/// pure object so tests and diagnostics can ask for a verdict without a
/// widget tree.
///
/// The store fallback only engages when the native source cannot produce
/// bytes on this device and the row is confirmed uploaded (see
/// [storeConfirmed]). Rows without any confirmed upload skip the runtime
/// entirely. Any store failure keeps the native placeholder.
class MediaTileResolver {
  MediaTileResolver({
    required MediaSourceResolverRegistry registry,
    required RemoteResolverLookup remote,
  }) : _registry = registry,
       _remote = remote;

  final MediaSourceResolverRegistry _registry;
  final RemoteResolverLookup _remote;

  Future<TileResolution> resolve(
    MediaItem item, {
    required bool thumbnail,
    required Size thumbnailTarget,
  }) async {
    final resolver = _registry.resolverFor(item.sourceType);
    final native = thumbnail
        ? await resolver.resolveThumbnail(item, target: thumbnailTarget)
        : await resolver.resolve(item);
    if (native is! UnavailableData) {
      return TileResolution(data: native);
    }
    final nativeFailure = native.kind;
    if (!storeConfirmed(item, thumbnail: thumbnail)) {
      return TileResolution(data: native, nativeFailure: nativeFailure);
    }
    try {
      final remote = await _remote();
      if (remote == null) {
        // The row's stamps say the bytes exist somewhere, but nothing here
        // can reach them, so the native placeholder is the honest answer.
        return TileResolution(
          data: native,
          storeFallbackUsed: true,
          nativeFailure: nativeFailure,
        );
      }
      final served = await remote.tryResolveRemote(item, thumbnail: thumbnail);
      if (served != null) {
        return TileResolution(
          data: served,
          // A thumbnail request whose thumb object is missing degrades to the
          // ORIGINAL, and for a document that original is the PDF. Only the
          // store knows which it handed back, and isPoster is how it says so.
          documentRenderable:
              thumbnail && served is FileData && served.isPoster,
          storeFallbackUsed: true,
          nativeFailure: nativeFailure,
        );
      }
      // The movie tile claims something specific: this video has no poster
      // frame. Shown only when the store holds the item, no thumb was ever
      // stamped, and the resolver therefore declined to download the whole
      // video just to draw an icon.
      return TileResolution(
        data: native,
        videoPosterMissing:
            thumbnail && item.isVideo && item.remoteThumbUploadedAt == null,
        storeFallbackUsed: true,
        nativeFailure: nativeFailure,
      );
    } catch (_) {
      return TileResolution(
        data: native,
        storeFallbackUsed: true,
        nativeFailure: nativeFailure,
      );
    }
  }
}
