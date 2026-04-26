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
class MediaItemView extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(mediaSourceResolverRegistryProvider);
    final resolver = registry.resolverFor(item.sourceType);

    final future = thumbnail && targetSize != null
        ? resolver.resolveThumbnail(item, target: targetSize!)
        : resolver.resolve(item);

    return FutureBuilder<MediaSourceData>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _ShimmerThumbnail();
        }
        final data = snapshot.data!;
        return switch (data) {
          FileData(file: final f) => Image.file(f, fit: fit),
          NetworkData(url: final u, headers: final h) => CachedNetworkImage(
            imageUrl: u.toString(),
            httpHeaders: h,
            fit: fit,
            placeholder: (_, _) => const _ShimmerThumbnail(),
            errorWidget: (_, _, _) => const UnavailableMediaPlaceholder(
              data: UnavailableData(kind: UnavailableKind.networkError),
            ),
          ),
          BytesData(bytes: final b) => Image.memory(b, fit: fit),
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
