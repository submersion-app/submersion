import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';

/// Measures the pane and hands [builder] how many thumbnails go across it
/// at the library's current size, and the size to decode them at
/// (issue #3297).
///
/// The first count shown for a slider step is then held, so resizing the
/// window scales the thumbnails rather than reflowing them.
class MediaThumbnailColumnsBuilder extends ConsumerWidget {
  const MediaThumbnailColumnsBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, int columns, Size targetSize)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only a new step rebuilds the gallery. Holding a count changes nothing
    // on screen, so it is read at each layout instead of watched: a resize
    // then sees the held count without the hold costing a second build.
    ref.watch(mediaThumbnailScaleProvider.select((scale) => scale.step));
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = ref.read(mediaThumbnailScaleProvider);
        final width = constraints.maxWidth;
        final columns = scale.columnsAt(width);
        if (scale.columns == null) {
          // After the frame: a provider cannot be written during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(mediaThumbnailScaleProvider.notifier).hold(columns);
            }
          });
        }
        return builder(
          context,
          columns,
          mediaThumbnailDecodeTarget(width, columns),
        );
      },
    );
  }
}
