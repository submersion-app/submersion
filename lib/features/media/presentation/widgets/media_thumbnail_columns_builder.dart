import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';

/// Measures the pane and hands [builder] how many thumbnails go across it
/// at the library's current size (issue #3297).
///
/// The first count shown for a slider step is then held, so resizing the
/// window scales the thumbnails rather than reflowing them.
class MediaThumbnailColumnsBuilder extends ConsumerWidget {
  const MediaThumbnailColumnsBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, int columns) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(mediaThumbnailScaleProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = scale.columnsAt(constraints.maxWidth);
        if (scale.columns == null) {
          // After the frame: a provider cannot be written during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(mediaThumbnailScaleProvider.notifier).hold(columns);
            }
          });
        }
        return builder(context, columns);
      },
    );
  }
}
