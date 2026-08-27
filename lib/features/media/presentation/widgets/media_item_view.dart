import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_orphan_reconciler.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Decode target used when a caller asks for a [MediaItemView.thumbnail]
/// without naming a size. Matches the largest tile in the app (the media
/// grid), so it is safe for any of them and still two orders of magnitude
/// cheaper than the original.
const Size kDefaultThumbnailTarget = Size(200, 200);

/// How far past the viewport a full-screen image is decoded, so pinch-zoom
/// still has pixels to show.
///
/// The viewers run `PhotoViewGallery` at `maxScale: covered * 3.0`, so a bound
/// of exactly one viewport would go soft the moment the user zooms. Two keeps
/// detail through the range people actually use while still cutting a 24 MP
/// original (~96 MB of RGBA) to roughly a tenth of that on a phone. Raising it
/// buys sharpness at 3x zoom for a quadratic cost in bytes.
const double _viewerZoomHeadroom = 2.0;

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
///
/// [storeFallbackUsed] records that the row's own source could not produce
/// bytes here and the media store was asked to cover. No resolver can report
/// this: it is a fact about the SEQUENCE of attempts rather than about any
/// single one, and it is what lets the info panel say "the photo library
/// lookup failed" instead of merely "served from cloud".
///
/// [nativeFailure] is why the row's OWN source could not produce bytes, or
/// null when it did. Deliberately separate from [data], which is what ended
/// up on screen: when the store covers for a dead origin, `data` is bytes and
/// carries no failure at all, so anything reasoning about whether the ORIGIN
/// still exists has to read this instead. `MediaItem.isOrphaned` is exactly
/// such a fact, and driving it from `data` would clear the flag every time
/// the cloud successfully covered for a missing local file.
typedef _Resolution = ({
  MediaSourceData data,
  bool videoPosterMissing,
  bool documentRenderable,
  bool storeFallbackUsed,
  UnavailableKind? nativeFailure,
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

  /// Resolves and records the outcome.
  ///
  /// Recording once here rather than at each of [_resolveInner]'s seven exits
  /// means a new exit added later cannot silently skip it: the record type
  /// forces every return to supply `storeFallbackUsed`, so an omission is a
  /// compile error rather than a quietly missing observation.
  ///
  /// The `ref` read is safe despite both callers running inside the build
  /// phase: it happens after [_resolveInner] has completed, which is well
  /// past that method's own opening yield.
  Future<_Resolution> _resolve() async {
    final resolution = await _resolveInner();
    // A grid tile can scroll out and be disposed while its resolution is
    // still in flight. Riverpod's WidgetRef.read asserts the element is still
    // mounted and throws StateError otherwise (flutter_riverpod
    // consumer.dart, read -> _assertNotDisposed), and because FutureBuilder
    // keeps an onError callback registered across dispose, that throw is
    // silently swallowed rather than surfaced. The observable cost is a
    // thrown-and-discarded exception per tile on every fast scroll, and a
    // real error here would be just as invisible. Nothing to record anyway:
    // no one is watching this resolution.
    if (!mounted) return resolution;
    final data = resolution.data;
    ref
        .read(mediaServingRecorderProvider)
        .record(
          widget.item.id,
          thumbnail: widget.thumbnail,
          servedFrom: data.servedFrom,
          servedTier: data.servedTier,
          failure: data is UnavailableData ? data.kind : null,
          storeFallbackUsed: resolution.storeFallbackUsed,
        );
    _reconcileOrphanState(resolution.nativeFailure);
    return resolution;
  }

  /// Persists what this resolution just proved about the row's source.
  ///
  /// The recorder above is session-scoped and 200 entries deep, so without
  /// this the app rediscovers a deleted asset on every scroll and never
  /// writes it down. `isOrphaned` is then read by the status badge, the
  /// orphaned placeholder, and the orphan sweeps, all of which understate
  /// library damage while nothing updates the column.
  ///
  /// Writes only on an actual change: [reconciledOrphanFlag] returns null
  /// when the flag already agrees or the outcome was inconclusive, so a
  /// library at rest costs nothing. That matters because every
  /// `MediaRepository` write calls `markRecordPending`, and a write per
  /// visible tile would queue one pending sync row per thumbnail scrolled
  /// past.
  void _reconcileOrphanState(UnavailableKind? nativeFailure) {
    final desired = reconciledOrphanFlag(
      currentlyOrphaned: widget.item.isOrphaned,
      failure: nativeFailure,
    );
    if (desired == null) return;
    // Unawaited and fully guarded: this runs on the resolve path of a grid
    // tile and must neither delay the frame nor turn a write failure into a
    // broken thumbnail. markVerified logs its own errors.
    try {
      unawaited(
        ref
            .read(mediaRepositoryProvider)
            .markVerified(
              widget.item.id,
              isOrphaned: desired,
              verifiedAt: DateTime.now(),
            )
            .catchError((Object _) {}),
      );
    } on Object catch (e) {
      _imageErrorLog.error(
        'Orphan reconciliation failed for ${widget.item.id}',
        error: e,
      );
    }
  }

  /// Re-runs resolution after the user taps a still-loading tile.
  ///
  /// Only [UnavailableKind.stillFetching] is retryable by tapping. It is the
  /// one kind that means "nothing is wrong, this is just slow", so a retry has
  /// a real chance of a different answer; offering one for a dead pointer or an
  /// unmounted volume would be a placebo. `MediaFetchGate` coalesces the retry
  /// onto the fetch still in flight, so the tap joins the live download rather
  /// than starting a second one.
  /// A block body, not an arrow: `setState(() => _future = _resolve())` makes
  /// the closure evaluate to the assigned Future, and setState asserts that
  /// its callback returns nothing so an `async` body cannot slip through.
  void _retry() {
    setState(() {
      _future = _resolve();
    });
  }

  // Declared `async` (not just returning a Future from a sync body) so any
  // synchronous throw — e.g. `MediaSourceResolverRegistry.resolverFor`
  // throwing UnsupportedError when a row's source_type has no registered
  // resolver — becomes a Future error caught by FutureBuilder's hasError
  // branch in [build] instead of escaping initState/didUpdateWidget.
  Future<_Resolution> _resolveInner() async {
    // Yield before the first `ref` touch. Both callers (initState and
    // didUpdateWidget) run inside the build phase, and an `async` body still
    // executes synchronously up to its first await -- so reading a provider
    // here initialized it mid-build. Riverpod 3.3.2 marks the enclosing
    // ProviderScope dirty when that happens, which Flutter rejects with
    // "setState() or markNeedsBuild() called during build". Surfaced by the
    // shrinking-gallery case in photo_viewer_gallery_change_test.dart, where
    // an invalidate rebuilds the gallery and fires didUpdateWidget.
    await null;
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
      // The render is built from the source's bytes, so it inherits the
      // source's provenance. thumbFor caches its output, and on a cache hit
      // the closure is never called, leaving this null: the honest answer,
      // because on that pass the bytes did not come from anywhere.
      ServedFrom? sourceFrom;
      final page1 = await ref
          .read(pdfThumbnailServiceProvider)
          .thumbFor(
            widget.item,
            source: () async {
              final resolved = await resolver.resolve(widget.item);
              sourceFrom = resolved.servedFrom;
              return resolved;
            },
          );
      if (page1 != null) {
        return (
          data: BytesData(
            bytes: page1,
            servedFrom: sourceFrom,
            servedTier: ServedTier.thumbnail,
          ),
          videoPosterMissing: false,
          documentRenderable: true,
          storeFallbackUsed: false,
          nativeFailure: null,
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
        storeFallbackUsed: false,
        nativeFailure: null,
      );
    }
    // Captured once, here, where `native` is promoted. Every return below
    // this line describes a resolution whose ORIGIN failed, whether or not
    // the store went on to cover for it.
    final nativeFailure = native.kind;
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
        // The store was never consulted: the row carries no stamp saying it
        // would have anything to offer.
        storeFallbackUsed: false,
        nativeFailure: nativeFailure,
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
          // True on purpose: the fallback was attempted and there was no
          // store here to answer it, which is a different situation from
          // never having looked.
          storeFallbackUsed: true,
          nativeFailure: nativeFailure,
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
          storeFallbackUsed: true,
          // The store covered, but the ORIGIN still failed and that is what
          // the orphan flag is about. Reporting null here would clear the
          // flag on exactly the rows MediaStatus.cloudOnly exists for.
          nativeFailure: nativeFailure,
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
        storeFallbackUsed: true,
        nativeFailure: nativeFailure,
      );
    } catch (_) {
      return (
        data: native,
        videoPosterMissing: false,
        documentRenderable: false,
        storeFallbackUsed: true,
        nativeFailure: nativeFailure,
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
        // Bound the DECODE, not just the layout. Photo resolvers hand back the
        // original file, so an unbounded Image.file holds a full-resolution
        // bitmap (a 12 MP JPEG is ~48 MB RGBA) for as long as the tile has a
        // listener -- and ImageCache cannot evict an image that still has one.
        // Grouped views build every tile of every group eagerly (shrinkWrap),
        // and the library page now stays mounted underneath a pushed dive, so
        // those decodes would otherwise stay resident for the whole visit.
        // Width only: passing both dimensions decodes to exact bounds and
        // distorts the aspect ratio.
        //
        // With no targetSize this used to pass null, which is the FULL-SCREEN
        // viewer's case: media_viewer_page and site_media_viewer_page both
        // build `MediaItemView(item: item, fit: BoxFit.contain)`. So the one
        // surface that draws whole originals was the one with no decode bound
        // at all -- a 24 MP JPEG at ~96 MB of RGBA, two of them alive while a
        // PageView swipe is in flight, and neither evictable because
        // ImageCache's budget only governs images with no listener. That is
        // the Android OOM in #1175. Falling back to the viewport keeps the
        // decode proportional to what can actually be displayed.
        //
        // The effective target is computed exactly as [_resolveInner] computes
        // it, and must stay that way. A sizeless `thumbnail: true` resolves
        // against kDefaultThumbnailTarget, so decoding it at the full-screen
        // bound would hand a 128 px tile the viewer's budget -- reintroducing,
        // in the decode, the same "the flag does nothing unless you also pass
        // a Size" defect this widget was fixed for once already.
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final target =
            widget.targetSize ??
            (widget.thumbnail ? kDefaultThumbnailTarget : null);
        final cacheWidth = target != null
            ? (target.longestSide * dpr).round()
            : (MediaQuery.sizeOf(context).longestSide *
                      dpr *
                      _viewerZoomHeadroom)
                  .round();
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
            cacheWidth: cacheWidth,
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
            cacheWidth: cacheWidth,
            errorBuilder: _imageError,
          ),
          UnavailableData(kind: UnavailableKind.stillFetching) =>
            GestureDetector(
              onTap: _retry,
              // The placeholder paints an opaque background, but the Column
              // inside it does not fill the tile, so without this the gaps
              // around the icon are not hit-testable and the tap falls through
              // to whatever is behind the grid.
              behavior: HitTestBehavior.opaque,
              child: UnavailableMediaPlaceholder(data: data),
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
