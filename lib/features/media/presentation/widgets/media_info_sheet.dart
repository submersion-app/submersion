import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_panel.dart';

/// Opens the media info panel.
///
/// A modal bottom sheet at every width. This app has `ResponsiveBreakpoints`
/// and a `MasterDetailScaffold`, but no transient panel in it branches on
/// them: every one is a `showModalBottomSheet`, including all four existing
/// media-feature sheets. Following the app beats following a wireframe.
///
/// The draggable sheet lets a reader pull the panel up when a long file path
/// or a queue error makes it taller than the initial fraction.
Future<void> showMediaInfoSheet(BuildContext context, MediaItem item) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) =>
            MediaInfoPanel(item: item, scrollController: controller),
      ),
    );
