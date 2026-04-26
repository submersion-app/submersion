import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';

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

  bool _inputsChanged(MediaItemView old) =>
      old.item.id != widget.item.id ||
      old.item.sourceType != widget.item.sourceType ||
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
    return widget.thumbnail && widget.targetSize != null
        ? await resolver.resolveThumbnail(
            widget.item,
            target: widget.targetSize!,
          )
        : await resolver.resolve(widget.item);
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
          FileData(file: final f) => Image.file(f, fit: widget.fit),
          NetworkData(url: final u, headers: final h) => CachedNetworkImage(
            imageUrl: u.toString(),
            httpHeaders: h,
            fit: widget.fit,
            placeholder: (_, _) => const _ShimmerThumbnail(),
            errorWidget: (_, _, _) => const UnavailableMediaPlaceholder(
              data: UnavailableData(kind: UnavailableKind.networkError),
            ),
          ),
          BytesData(bytes: final b) => Image.memory(b, fit: widget.fit),
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
