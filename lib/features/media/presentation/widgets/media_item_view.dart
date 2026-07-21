import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Universal display widget for any [MediaItem] regardless of its source
/// type.
///
/// Resolves the item via [mediaSourceResolverRegistryProvider] and renders
/// the appropriate Flutter widget for the resulting [MediaSourceData]
/// variant:
///   * [FileData] — [Image.file] (zero-copy, OS-mapped)
///   * [NetworkData] — [CachedNetworkImage] (LRU disk + memory cache)
///   * [BytesData] — [Image.memory] (signatures, small assets only)
///   * [UnavailableData] — [UnavailableMediaPlaceholder] (badge with reason)
///
/// While the future is loading, shows a [_ShimmerThumbnail] placeholder.
/// If the resolver future completes with an error, falls back to an
/// [UnavailableMediaPlaceholder] (kind: [UnavailableKind.notFound]) so a
/// failure never looks like a permanent shimmer.
///
/// The resolver Future is memoized: it is computed once in [State.initState]
/// and recomputed only when [item.id], [item.sourceType], [thumbnail], or
/// [targetSize] changes. This avoids re-resolution flicker on parent rebuilds.
class MediaItemView extends ConsumerStatefulWidget {
  final MediaItem item;
  final BoxFit fit;
  final Size? targetSize;
  final bool thumbnail;

  const MediaItemView({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.targetSize,
    this.thumbnail = false,
  });

  @override
  ConsumerState<MediaItemView> createState() => _MediaItemViewState();
}

class _MediaItemViewState extends ConsumerState<MediaItemView> {
  late Future<MediaSourceData> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(covariant MediaItemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_inputsChanged(oldWidget)) {
      _future = _resolve();
    }
  }

  // MediaItem is Equatable and its props cover every pointer field that can
  // affect resolution (platformAssetId, localPath, bookmarkRef, url,
  // imageData, sourceType, etc.), so deep equality on the item is the
  // correct cache key — it catches both identity changes and in-place
  // mutations of the same row.
  bool _inputsChanged(MediaItemView old) =>
      old.item != widget.item ||
      old.thumbnail != widget.thumbnail ||
      old.targetSize != widget.targetSize;

  // Declared `async` (not just returning a Future from a sync body) so any
  // synchronous throw — e.g. `MediaSourceResolverRegistry.resolverFor`
  // throwing UnsupportedError when a row's source_type has no registered
  // resolver — becomes a Future error caught by FutureBuilder's hasError
  // branch in [build] instead of escaping initState/didUpdateWidget.
  Future<MediaSourceData> _resolve() async {
    final registry = ref.read(mediaSourceResolverRegistryProvider);
    final resolver = registry.resolverFor(widget.item.sourceType);
    final native = widget.thumbnail && widget.targetSize != null
        ? await resolver.resolveThumbnail(
            widget.item,
            target: widget.targetSize!,
          )
        : await resolver.resolve(widget.item);
    if (native is! UnavailableData) return native;
    // Media store fallback (design spec section 10): only engages when the
    // native source cannot produce bytes on this device and the row is
    // confirmed uploaded - for thumbnail requests the thumb stamp alone
    // suffices, since thumbs upload before originals. Rows without any
    // confirmed upload skip the runtime entirely (no keychain read, no
    // store construction). Any store failure keeps the native placeholder.
    final storeConfirmed =
        widget.item.contentHash != null &&
        (widget.item.remoteUploadedAt != null ||
            (widget.thumbnail && widget.item.remoteThumbUploadedAt != null));
    if (!storeConfirmed) {
      return native;
    }
    try {
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      final remote = await runtime?.resolver.tryResolveRemote(
        widget.item,
        thumbnail: widget.thumbnail,
      );
      return remote ?? native;
    } catch (_) {
      return native;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MediaSourceData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const UnavailableMediaPlaceholder(
            data: UnavailableData(kind: UnavailableKind.notFound),
          );
        }
        if (!snapshot.hasData) {
          return const _ShimmerThumbnail();
        }
        final data = snapshot.data!;
        return switch (data) {
          // A local video resolves to the raw video file, which Image.file
          // cannot decode. Show a placeholder instead of surfacing an
          // "Invalid image data" exception. (Connector video posters arrive as
          // BytesData JPEGs below and render normally.)
          FileData() when widget.item.isVideo =>
            const _VideoThumbnailPlaceholder(),
          FileData(file: final f) => Image.file(
            f,
            fit: widget.fit,
            errorBuilder: _imageError,
          ),
          NetworkData(url: final u, headers: final h) => CachedNetworkImage(
            imageUrl: u.toString(),
            httpHeaders: h,
            fit: widget.fit,
            placeholder: (_, _) => const _ShimmerThumbnail(),
            errorWidget: (_, _, _) => const UnavailableMediaPlaceholder(
              data: UnavailableData(kind: UnavailableKind.networkError),
            ),
          ),
          BytesData(bytes: final b) => Image.memory(
            b,
            fit: widget.fit,
            errorBuilder: _imageError,
          ),
          UnavailableData() => UnavailableMediaPlaceholder(data: data),
        };
      },
    );
  }
}

class _ShimmerThumbnail extends StatelessWidget {
  const _ShimmerThumbnail();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

/// Neutral tile shown in place of a decodable image for local videos (whose
/// raw bytes Image.file/Image.memory cannot render). The grid stacks its own
/// videocam badge over this.
class _VideoThumbnailPlaceholder extends StatelessWidget {
  const _VideoThumbnailPlaceholder();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// Graceful fallback when image bytes fail to decode (corrupt/unsupported), so
/// the raw "Invalid image data" exception never reaches the UI. Shows a
/// broken-image tile rather than the "file not found" placeholder: the file is
/// present, it just couldn't be rendered.
Widget _imageError(BuildContext context, Object error, StackTrace? stack) {
  final scheme = Theme.of(context).colorScheme;
  return ColoredBox(
    color: scheme.surfaceContainerHighest,
    child: Center(
      child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
    ),
  );
}
