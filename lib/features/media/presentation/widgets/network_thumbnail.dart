// Adapted from plan
// `docs/design/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 16. Drop-in `CachedNetworkImage` wrapper that resolves the
// per-host `Authorization` header from [NetworkCredentialsService]
// before painting.
//
// Deviations from the plan code (lines 1373-1397):
//
// - The plan's snippet calls `const UnavailableMediaPlaceholder()` for
//   the error widget, but `UnavailableMediaPlaceholder` (Phase 1)
//   requires a `data: UnavailableData` parameter. We pass
//   [UnavailableKind.networkError] to match the existing `MediaItemView`
//   error branch which renders the same placeholder for failed network
//   loads.
// - We expose the `fit` parameter (defaulting to `BoxFit.cover` to match
//   the plan) so the URL review pane can pass a thumbnail-friendly fit
//   without needing a wrapper. Width / height fall back to [size] when
//   not provided so the plan's two-arg call site (`NetworkThumbnail(url:
//   ..., size: ...)`) still compiles.
// - While the headers are resolving we render an
//   [UnavailableMediaPlaceholder] only on error, and during the brief
//   resolve window we paint a neutral surface tint so the row doesn't
//   flicker into a "broken" state for one frame. This mirrors
//   `_ShimmerThumbnail` in `media_item_view.dart`.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';

/// Compact thumbnail for a remote media URL. Reads the appropriate
/// `Authorization` header (if any) from [networkThumbnailHeadersProvider]
/// before delegating to [CachedNetworkImage].
class NetworkThumbnail extends ConsumerWidget {
  const NetworkThumbnail({
    super.key,
    required this.url,
    this.size = 96,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(networkThumbnailHeadersProvider(url));
    if (headers.isLoading && !headers.hasValue) return _Pending(size: size);
    return CachedNetworkImage(
      // The image provider's identity ignores headers, so without this key an
      // image that failed before the user signed in would never be refetched.
      key: ValueKey(headers.value?['Authorization']),
      imageUrl: url,
      httpHeaders: headers.value,
      width: size,
      height: size,
      fit: fit,
      placeholder: (_, _) => _Pending(size: size),
      errorWidget: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: const UnavailableMediaPlaceholder(
          data: UnavailableData(kind: UnavailableKind.networkError),
        ),
      ),
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}
