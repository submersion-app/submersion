import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_editing.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A site document's own page (the PDF viewer, the details page) closes
/// once the document is no longer the site's (issue #4527, phase 2): its
/// row deleted elsewhere, or unlinked from the site and kept for a dive.
/// It says so on the page below. An open sitting ends first, saying its
/// changes were not saved, and the page then closes without a second
/// message.
mixin AttachmentPageClosesWhenRemoved<W extends ConsumerStatefulWidget>
    on ConsumerState<W>, PhotoViewerEditing<W> {
  /// Whether the document has been read as no longer the site's.
  bool _removed = false;

  /// Whether the sitting's end has said the document went, unsaved, so
  /// the page closes without a second message.
  bool _toldGone = false;
  bool _closing = false;

  /// Follows [mediaId]'s stored row as [siteId]'s attachment. Call from
  /// `build`.
  void closeWhenRemoved(String mediaId, {required String siteId}) {
    final provider = photoRecordProvider(mediaId);
    ref.listen(provider, (_, next) => _consider(next, siteId));
    // The read as it is now too: a page opened on a document already gone
    // (a stale item while a sync lands) has no change to hear.
    _consider(ref.read(provider), siteId);
  }

  /// Acts on [next], a read of the document's row, once it shows the
  /// document is no longer [siteId]'s.
  void _consider(AsyncValue<PhotoRecord?> next, String siteId) {
    if (_removed || next.isLoading || next.hasError) return;
    final stored = next.value;
    final leftSite = stored != null && stored.item.siteId != siteId;
    if (stored != null && !leftSite) return;
    _removed = true;
    if (!photoUnlocked) {
      _close(say: true);
      return;
    }
    // A deleted row ends its sitting in PhotoViewerEditing, and its lock
    // closes the page. One that only left the site is ended here, on the
    // same terms.
    if (leftSite) _endLeftSite(stored);
  }

  /// The document found gone by the sitting itself, as a save refused
  /// for it: its lock, next, closes the page, and a later read of the row
  /// says nothing more.
  @override
  void onPhotoGone() {
    _removed = true;
    _toldGone = true;
  }

  @override
  void onPhotoLocked() {
    // Remembered rather than read again: by the lock the row is often
    // being read once more. A sitting that ended as a save (the document
    // went after it wrote) said nothing of it, so the page says so.
    if (_removed) _close(say: !_toldGone);
  }

  /// Ends the sitting over a document that left the site, unsaved, and
  /// says so; its lock closes the page.
  void _endLeftSite(PhotoRecord stored) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = photoEditController;
      // A save running now is refused for a document that left the site
      // (or, done before it left, ends as a save); either way its lock
      // closes the page.
      if (!controller.isUnlocked || controller.isSaving) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final message = context.l10n.media_viewer_documentGoneWhileEditing;
      _toldGone = true;
      controller.lock();
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _close({required bool say}) {
    if (_closing) return;
    _closing = true;
    // After the frame: the row can go while the page is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final message = context.l10n.media_viewer_documentRemoved;
      final navigator = Navigator.of(context);
      final route = ModalRoute.of(context);
      // Whatever is open above the page goes with it.
      if (route != null && !route.isCurrent) {
        navigator.popUntil((other) => other == route);
      }
      navigator.pop();
      if (say) messenger?.showSnackBar(SnackBar(content: Text(message)));
    });
  }
}
