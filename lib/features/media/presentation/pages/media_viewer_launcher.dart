import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';

/// Signature of [openMediaViewer], so a surface can take the opener as a
/// parameter and a test can capture calls instead of pushing the viewer.
typedef MediaViewerOpener =
    void Function(
      BuildContext context,
      List<MediaItem> items,
      String initialMediaId,
    );

/// Pushes the cross-dive media viewer as a full-screen dialog on [items],
/// starting at [initialMediaId]. The library grid and the media map share
/// this so the two entry points cannot drift.
///
/// [captionFor] adds a line naming where an item comes from, such as the
/// check-in a gear photo backs up (issue #3355).
void openMediaViewer(
  BuildContext context,
  List<MediaItem> items,
  String initialMediaId, {
  String? Function(MediaItem)? captionFor,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => MediaViewerPage(
        mediaList: items,
        initialMediaId: initialMediaId,
        showGoToDive: true,
        captionFor: captionFor,
      ),
    ),
  );
}
