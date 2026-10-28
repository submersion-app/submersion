import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_tile_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_orphan_reconciler.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_tile_image_memo.dart';
import 'package:submersion/features/media/presentation/widgets/color_corrected.dart';
import 'package:submersion/features/media/presentation/widgets/limited_access_actions.dart';
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
/// While the future is loading, a tile shows a [_ShimmerThumbnail]
/// placeholder; a full-screen view shows nothing, so the viewer's own
/// background shows through (see [_MediaItemViewState._loading]). Either way,
/// when the decoded image this item last drew is still in memory, it paints
/// that on the first frame instead (see [MediaTileImageMemo]).
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

  /// Whether a photo outside the user's limited selection offers "Allow
  /// full access" and "Choose photo again" (spec 6.3). The full-screen
  /// viewer sets it; a grid tile has no room for buttons.
  final bool showAccessActions;

  /// Called once with the decoded image's pixel size, for a caller that
  /// lays something over the image by its aspect (the viewer's face boxes,
  /// issue #1745). The size is the decode-bounded one, so only its aspect
  /// is the original's.
  final ValueChanged<Size>? onImageSize;

  const MediaItemView({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.targetSize,
    this.thumbnail = false,
    this.showAccessActions = false,
    this.onImageSize,
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

  /// The item the last finished resolution was for. Rebuilt for another
  /// item, the FutureBuilder keeps drawing the old answer until the new one
  /// lands; that picture must not be analysed as the new item's colours.
  String? _resolvedFor;

  /// The image stream [MediaItemView.onImageSize] listens to, and its
  /// listener, held so the listener is removed when the image changes or
  /// the view goes away.
  ImageStream? _sizeStream;
  ImageStreamListener? _sizeListener;
  String? _sizeReportedFor;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void dispose() {
    _stopSizeWatch();
    super.dispose();
  }

  void _stopSizeWatch() {
    final listener = _sizeListener;
    if (listener != null) _sizeStream?.removeListener(listener);
    _sizeStream = null;
    _sizeListener = null;
  }

  /// Reports [provider]'s decoded size to [MediaItemView.onImageSize], once
  /// per item.
  void _watchSize(ImageProvider provider) {
    final report = widget.onImageSize;
    if (report == null || _sizeReportedFor == widget.item.id) return;
    final stream = provider.resolve(ImageConfiguration.empty);
    if (stream.key == _sizeStream?.key) return;
    _stopSizeWatch();
    final itemId = widget.item.id;
    final listener = ImageStreamListener((info, _) {
      if (!mounted || _sizeReportedFor == itemId) return;
      _sizeReportedFor = itemId;
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      // A cached image answers synchronously, inside this build; the caller
      // may setState with the size, so it hears after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) report(size);
      });
      _stopSizeWatch();
    }, onError: (_, _) => _stopSizeWatch());
    _sizeStream = stream;
    _sizeListener = listener;
    stream.addListener(listener);
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
  //
  // A colour adjustment saved on the row (issue #3520) changes the item and
  // bumps updatedAt but not the pixels, so it is drawn without resolving
  // the image again (which would flash a placeholder on every save).
  bool _inputsChanged(MediaItemView old) =>
      _resolutionInputs(old.item) != _resolutionInputs(widget.item) ||
      old.thumbnail != widget.thumbnail ||
      old.targetSize != widget.targetSize;

  // The profile match does not choose the pixels either: a viewer page
  // that hydrates a lean library row gains it a moment after opening.
  static MediaItem _resolutionInputs(MediaItem item) => item.copyWith(
    colorAdjustment: null,
    enrichment: null,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

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
    final forId = widget.item.id;
    final resolution = await _resolveInner();
    _resolvedFor = forId;
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
    // A thumbnail found again in the cache was served without looking at
    // the original, so it proves nothing about whether the original is
    // still there. Reconciling on it would clear the orphan flag of every
    // missing photo that still has a thumbnail. The resolver checks the
    // original itself, off this path, and reports what it finds.
    if (!(data is FileData && data.originUntouched)) {
      _reconcileOrphanState(resolution.nativeFailure);
    }
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
    //
    // Native resolve, the store-confirmed gate and the store fallback all
    // live in MediaTileResolver (design spec section 10), so tests and
    // diagnostics can ask for the same verdict without a widget tree. The
    // runtime lookup is deferred: rows without any confirmed upload never
    // build it (no keychain read, no store construction). A foreign row
    // with no stamps is probed through a resolver on the store adapter
    // alone, so a grid render never builds the runtime, whose construction
    // drains the queue and may run a verify sweep (spec 7.2).
    final tile =
        await MediaTileResolver(
          registry: registry,
          remote: () async =>
              (await ref.read(mediaStoreRuntimeProvider.future))?.resolver,
          probeRemote: () => ref.read(mediaStoreProbeResolverProvider.future),
        ).resolve(
          widget.item,
          thumbnail: widget.thumbnail,
          thumbnailTarget: widget.targetSize ?? kDefaultThumbnailTarget,
        );
    return (
      data: tile.data,
      videoPosterMissing: tile.videoPosterMissing,
      documentRenderable: tile.documentRenderable,
      storeFallbackUsed: tile.storeFallbackUsed,
      nativeFailure: tile.nativeFailure,
    );
  }

  /// Draws [file], and notes that it did so the next mount of this item can
  /// find the decoded image without waiting on resolution.
  Widget _fileImage(MediaTileImageMemo memo, File file, int cacheWidth) {
    memo.remember(
      widget.item,
      thumbnail: widget.thumbnail,
      cacheWidth: cacheWidth,
      file: file,
    );
    return _correctedImage(
      MediaTileImageMemo.providerFor(file, cacheWidth),
      resolved: true,
    );
  }

  /// [provider]'s image drawn with the item's colour correction (issue
  /// #3520). Only the decoded frame goes through the filter: the broken-image
  /// tile from [Image.errorBuilder] replaces the frame and is drawn as is.
  ///
  /// [resolved] marks [provider] as drawn from a resolution, which is this
  /// item's only once one finished for it. Its colours are analysed only
  /// then, and only once the frame has decoded: a tile flung past before it
  /// draws asks for nothing.
  Widget _correctedImage(ImageProvider provider, {required bool resolved}) {
    _watchSize(provider);
    final ownPixels = !resolved || _resolvedFor == widget.item.id;
    return Image(
      image: provider,
      fit: widget.fit,
      errorBuilder: _imageError,
      frameBuilder: (context, child, frame, synchronouslyLoaded) =>
          ColorCorrected(
            item: widget.item,
            analysisSource: ownPixels && (frame != null || synchronouslyLoaded)
                ? provider
                : null,
            child: child,
          ),
    );
  }

  /// Whether this view fills a full-screen viewer page rather than a tile.
  ///
  /// The same test the decode bound in [build] uses: the viewers pass neither
  /// [MediaItemView.thumbnail] nor a [MediaItemView.targetSize], and every
  /// tile passes at least one.
  bool get _fullScreen => !widget.thumbnail && widget.targetSize == null;

  /// What to draw while the bytes are on their way.
  ///
  /// A tile gets the opaque surface fill so the grid keeps its shape. A
  /// full-screen view draws nothing: the viewers paint a black gallery behind
  /// every page, and the tile fill (near white on a light theme) slid in ahead
  /// of each photo as a pale panel (#3298).
  Widget _loading() =>
      _fullScreen ? const SizedBox.expand() : const _ShimmerThumbnail();

  @override
  Widget build(BuildContext context) {
    final memo = ref.watch(mediaTileImageMemoProvider);
    return FutureBuilder<_Resolution>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const UnavailableMediaPlaceholder(
            data: UnavailableData(kind: UnavailableKind.notFound),
          );
        }
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
        if (!snapshot.hasData) {
          // A tile scrolling back into view: resolution is asynchronous, but
          // the image it will resolve to may still be decoded in memory.
          // Painting that now skips the placeholder (issue #3337). The
          // resolution carries on behind it and replaces this if the answer
          // has changed. Not for an orphaned row, whose answer is most likely
          // the missing-file placeholder: the picture would only flash.
          final remembered = widget.item.isOrphaned
              ? null
              : memo.cachedProvider(
                  widget.item,
                  thumbnail: widget.thumbnail,
                  cacheWidth: cacheWidth,
                );
          if (remembered != null) {
            // Remembered for this very item, so its pixels are its own.
            return _correctedImage(remembered, resolved: false);
          }
          return _loading();
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
          FileData(file: final f) => _fileImage(memo, f, cacheWidth),
          NetworkData(url: final u, headers: final h) => CachedNetworkImage(
            imageUrl: u.toString(),
            httpHeaders: h,
            fit: widget.fit,
            // The same decode bound as the file and bytes branches: without
            // it a served original decodes at native size, and the viewers
            // keep a neighbour built either side of the current page.
            memCacheWidth: cacheWidth,
            // Only the loaded image is colour corrected; the placeholder and
            // the error tile below are drawn as they are (issue #3520). The
            // builder is handed the package's unresized provider, so it is
            // bounded here the same way memCacheWidth bounds the package's
            // own decode (the same cache entry): drawing it as handed over
            // would decode every original at full size.
            imageBuilder: (context, provider) => _correctedImage(
              ResizeImage.resizeIfNeeded(cacheWidth, null, provider),
              resolved: true,
            ),
            placeholder: (_, _) => _loading(),
            errorWidget: (_, _, _) => const UnavailableMediaPlaceholder(
              data: UnavailableData(kind: UnavailableKind.networkError),
            ),
          ),
          BytesData(bytes: final b) => _correctedImage(
            ResizeImage.resizeIfNeeded(cacheWidth, null, MemoryImage(b)),
            resolved: true,
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
          // The viewer offers the ways back to a photo outside a limited
          // selection (spec 6.3); a grid tile has no room for buttons and
          // shows the placeholder alone. Only the viewer sets the flag, and
          // it lays this out in bounded height.
          UnavailableData(
            kind: UnavailableKind.accessDenied,
            limitedAccess: true,
          )
              when widget.showAccessActions =>
            Column(
              children: [
                Expanded(child: UnavailableMediaPlaceholder(data: data)),
                LimitedAccessActions(onChanged: _retry),
              ],
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
