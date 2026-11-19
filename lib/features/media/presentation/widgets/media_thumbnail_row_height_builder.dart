import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';

/// Measures the pane and hands [builder] the row height the library's
/// thumbnails are packed at, at its current size (issues #3297, #4738).
///
/// The first height shown for a slider step is then held, so resizing the
/// window re-packs the rows at the same height rather than scaling them.
class MediaThumbnailRowHeightBuilder extends ConsumerWidget {
  const MediaThumbnailRowHeightBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, double rowHeight) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only a new step rebuilds the gallery. Holding a height changes nothing
    // on screen, so it is read at each layout instead of watched: a resize
    // then sees the held height without the hold costing a second build.
    ref.watch(mediaThumbnailScaleProvider.select((scale) => scale.step));
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = ref.read(mediaThumbnailScaleProvider);
        final rowHeight = scale.rowHeightAt(constraints.maxWidth);
        if (scale.rowHeight == null) {
          // After the frame: a provider cannot be written during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(mediaThumbnailScaleProvider.notifier).hold(rowHeight);
            }
          });
        }
        return builder(context, rowHeight);
      },
    );
  }
}
