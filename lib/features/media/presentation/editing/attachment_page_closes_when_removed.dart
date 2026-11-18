import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_editing.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A site document's own page (the PDF viewer, the details page) closes
/// once its document is deleted elsewhere (issue #4527, phase 2), and says
/// so on the page below. An open sitting ends first, saying its changes
/// were not saved ([PhotoViewerEditing]); the page then closes without a
/// second message.
mixin AttachmentPageClosesWhenRemoved<W extends ConsumerStatefulWidget>
    on ConsumerState<W>, PhotoViewerEditing<W> {
  /// Whether the document's row has been read as gone.
  bool _removed = false;
  bool _closing = false;

  /// Follows [mediaId]'s stored row. Call from `build`.
  void closeWhenRemoved(String mediaId) {
    ref.listen(photoRecordProvider(mediaId), (_, next) {
      if (!_isGone(next)) return;
      _removed = true;
      // The sitting ends first and says so; its lock closes the page.
      if (photoUnlocked) return;
      _close(say: true);
    });
  }

  @override
  void onPhotoLocked() {
    // Remembered rather than read again: by the lock the row is often
    // being read once more.
    if (_removed) _close(say: false);
  }

  /// Read, and found to be gone; not loading, failed or still there.
  bool _isGone(AsyncValue<Object?> stored) =>
      !stored.isLoading && !stored.hasError && stored.value == null;

  void _close({required bool say}) {
    if (_closing) return;
    _closing = true;
    // After the frame: the row can go while the page is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final message = context.l10n.media_viewer_documentRemoved;
      Navigator.of(context).pop();
      if (say) messenger?.showSnackBar(SnackBar(content: Text(message)));
    });
  }
}
