import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Decode target used when a caller asks for a [MediaItemView.thumbnail]
/// without naming a size. Matches the largest tile in the app (the media
/// grid), so it is safe for any of them and still two orders of magnitude
/// cheaper than the original.
const Size kDefaultThumbnailTarget = Size(200, 200);

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

  /// Decode target for [thumbnail] requests. Defaults to
  /// [kDefaultThumbnailTarget]; ignored when [thumbnail] is false.
  final Size? targetSize;

  /// Whether this view only ever draws a tile. Thumbnail requests never touch
  /// the full-resolution original, with or without a [targetSize].
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

/// What [_MediaItemViewState._resolve] produced.
///
/// [videoPosterMissing] separates "this video has no poster frame here" from
/// the missing-media reading [MediaSourceData] would otherwise force: the
/// store holds the item, it simply has no still image to draw, and pulling
/// the video down to discover that is exactly what the resolver declines to
/// do. Carried alongside the data rather than folded into it so the resolver
/// contract stays a plain "bytes or a reason".
///
/// [documentRenderable] marks a document resolution whose bytes are an
/// IMAGE rather than the document itself — a page-1 render, produced either
/// locally by [PdfThumbnailService] or by the upload pipeline and served
/// back as the store's THUMB. Every other document resolution (local
/// original, store original) is raw document bytes that Image widgets
/// cannot decode, and draws the placeholder instead.
typedef _Resolution = ({
  MediaSourceData data,
  bool videoPosterMissing,
  bool documentRenderable,
});

class _MediaItemViewState extends ConsumerState<MediaItemView> {
  late Future<_Resolution> _future;

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
  Future<_Resolution> _resolve() async {
    final registry = ref.read(mediaSourceResolverRegistryProvider);
    final resolver = registry.resolverFor(widget.item.sourceType);
    // A PDF tile draws page 1. Rendering is the only way raw document bytes
    // become an image, and doing it here rather than in the resolver keeps
    // resolveThumbnail's contract intact -- ThumbnailGenerator calls it
    // expecting the PDF itself to feed to the same renderer. Cache-first
    // inside the service, so the source read (on Android, the whole file
    // back across a platform channel) happens once per document instead of
    // once per tile that scrolls into view.
    if (widget.thumbnail && widget.item.isPdf) {
      final page1 = await ref
          .read(pdfThumbnailServiceProvider)
          .thumbFor(widget.item, source: () => resolver.resolve(widget.item));
      if (page1 != null) {
        return (
          data: BytesData(bytes: page1),
          videoPosterMissing: false,
          documentRenderable: true,
        );
      }
      // No local render (bytes unavailable here, or an unreadable PDF):
      // fall through, which reaches the store's own page-1 thumb below.
    }
    // [thumbnail] alone decides the path. Requiring a [targetSize] too made
    // the flag a silent no-op wherever one was omitted, and the fallback is
    // the full-resolution original: for a gallery item, AssetEntity
    // .originBytes, decoded at native resolution because the Image widgets
    // below carry no cacheWidth. A screenful of 12 MP originals behind
    // 128 px tiles is enough for iOS to kill the app.
    final native = widget.thumbnail
        ? await resolver.resolveThumbnail(
            widget.item,
            target: widget.targetSize ?? kDefaultThumbnailTarget,
          )
        : await resolver.resolve(widget.item);
    if (native is! UnavailableData) {
      return (
        data: native,
        videoPosterMissing: false,
        documentRenderable: false,
      );
    }
    // Media store fallback (design spec section 10): only engages when the
    // native source cannot produce bytes on this device and the row is
    // confirmed uploaded - for thumbnail requests the thumb stamp alone
    // suffices, since thumbs upload before originals. Rows without any
    // confirmed upload skip the runtime entirely (no keychain read, no
    // store construction). Any store failure keeps the native placeholder.
    //
    // The compressed stamp counts as confirmation in its own right: an
    // upload-quality setting other than "original" uploads a rendition and
    // leaves remoteUploadedAt null permanently, so gating on the original
    // alone made every such photo unviewable on other devices even though
    // MediaStoreResolver.tryResolveRemote can serve the rendition. This
    // mirrors what MediaRepository already treats as backed up.
    final storeConfirmed =
        widget.item.contentHash != null &&
        (widget.item.remoteUploadedAt != null ||
            widget.item.remoteCompressedUploadedAt != null ||
            (widget.thumbnail && widget.item.remoteThumbUploadedAt != null));
    if (!storeConfirmed) {
      return (
        data: native,
        videoPosterMissing: false,
        documentRenderable: false,
      );
    }
    try {
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      // No store on this device: the row's stamps say the bytes exist
      // somewhere, but nothing here can reach them, so the native
      // placeholder is the honest answer.
      if (runtime == null) {
        return (
          data: native,
          videoPosterMissing: false,
          documentRenderable: false,
        );
      }
      final remote = await runtime.resolver.tryResolveRemote(
        widget.item,
        thumbnail: widget.thumbnail,
      );
      if (remote != null) {
        return (
          data: remote,
          videoPosterMissing: false,
          // Not "the request was a thumbnail": a thumbnail request whose
          // thumb object is missing or unfetchable degrades to the ORIGINAL
          // (see MediaStoreResolver.tryResolveRemote), and for a document
          // that original is the PDF. Only the store knows which of the two
          // it handed back, and isPoster is how it says so.
          documentRenderable:
              widget.thumbnail && remote is FileData && remote.isPoster,
        );
      }
      // The movie tile claims something specific -- this video has no poster
      // frame -- so it is shown only when that is what happened: the store
      // holds the item, no thumb was ever stamped, and the resolver therefore
      // declined to download the whole video just to draw an icon. A poster
      // that IS stamped but failed to fetch is an error, not an absence, and
      // keeps the native placeholder so a transient failure cannot read as a
      // video that simply has no preview.
      return (
        data: native,
        videoPosterMissing:
            widget.thumbnail &&
            widget.item.isVideo &&
            widget.item.remoteThumbUploadedAt == null,
        documentRenderable: false,
      );
    } catch (_) {
      return (
        data: native,
        videoPosterMissing: false,
        documentRenderable: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Resolution>(
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
        final resolution = snapshot.data!;
        if (resolution.videoPosterMissing) {
          return const _VideoThumbnailPlaceholder();
        }
        final data = resolution.data;
        // A document resolves to raw document bytes (PDF, docx, ...), which
        // the Image widgets cannot decode. The renderable exception is a
        // PDF's page-1 image: rendered here for a tile, or served as the
        // store's THUMB when this device cannot read the PDF itself.
        final documentRenderable = resolution.documentRenderable;
        return switch (data) {
          FileData() when widget.item.isDocument && !documentRenderable =>
            _DocumentThumbnailPlaceholder(item: widget.item),
          BytesData() when widget.item.isDocument && !documentRenderable =>
            _DocumentThumbnailPlaceholder(item: widget.item),
          // A video normally resolves to the raw video file, which Image.file
          // cannot decode. Show a placeholder instead of surfacing an
          // "Invalid image data" exception. A poster frame is the exception:
          // it is a JPEG derived from the video, and only its producer can
          // tell the two apart. (Connector video posters arrive as BytesData
          // JPEGs below and render normally.)
          FileData(isPoster: false) when widget.item.isVideo =>
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

/// Neutral tile shown for document attachments, whose raw bytes the Image
/// widgets cannot render. The grid stacks its extension badge over this.
class _DocumentThumbnailPlaceholder extends StatelessWidget {
  final MediaItem item;
  const _DocumentThumbnailPlaceholder({required this.item});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.description_outlined,
              color: scheme.onSurfaceVariant,
            ),
            if (item.originalFilename != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.originalFilename!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
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

final _imageErrorLog = LoggerService.forClass(MediaItemView);

/// Graceful fallback when image bytes fail to decode (corrupt/unsupported), so
/// the raw "Invalid image data" exception never reaches the UI. Shows a
/// broken-image tile rather than the "file not found" placeholder: the file is
/// present, it just couldn't be rendered.
///
/// The underlying error is logged: `errorBuilder` suppresses the framework's
/// own console report, so without this a load/decode failure (sandbox denial,
/// truncated bytes, unsupported codec) leaves no trace anywhere.
Widget _imageError(BuildContext context, Object error, StackTrace? stack) {
  _imageErrorLog.warning(
    'Image failed to load/decode',
    error: error,
    stackTrace: stack,
  );
  final scheme = Theme.of(context).colorScheme;
  return ColoredBox(
    color: scheme.surfaceContainerHighest,
    child: Center(
      child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
    ),
  );
}
