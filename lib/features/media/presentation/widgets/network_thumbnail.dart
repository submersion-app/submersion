// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
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
// - While the `headersFor` future is in flight we render an
//   [UnavailableMediaPlaceholder] only on error — during the brief
//   resolve window we paint a neutral surface tint so the row doesn't
//   flicker into a "broken" state for one frame. This mirrors
//   `_ShimmerThumbnail` in `media_item_view.dart`.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';

/// Compact thumbnail for a remote media URL. Fetches the appropriate
/// `Authorization` header (if any) from
/// [networkCredentialsServiceProvider] before delegating to
/// [CachedNetworkImage].
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
    final credentials = ref.watch(networkCredentialsServiceProvider);
    return FutureBuilder<Map<String, String>?>(
      future: credentials.headersFor(Uri.parse(url)),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _Pending(size: size);
        }
        return CachedNetworkImage(
          imageUrl: url,
          httpHeaders: snap.data,
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
      },
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
