part of 'media_viewer_page.dart';

/// The viewer's Unlink (issue #5126): its name, the strip over a photo whose
/// Unlink is held, and what the viewer does once the unlink is saved.
extension _ViewerUnlink on _MediaViewerPageState {
  /// What the Unlink action is called for [scope].
  String _unlinkLabelFor(BuildContext context, ViewerUnlinkScope scope) {
    final l10n = context.l10n;
    return switch (scope) {
      ViewerUnlinkScope.dive => l10n.media_viewer_unlinkFromDive,
      ViewerUnlinkScope.site => l10n.media_viewer_unlinkFromSite,
      ViewerUnlinkScope.gear => l10n.media_viewer_unlinkFromGear,
      ViewerUnlinkScope.library => l10n.media_viewer_unlink,
    };
  }

  /// What the strip says will happen at Save for [scope].
  String _unlinkHeldMessageFor(BuildContext context, ViewerUnlinkScope scope) {
    final l10n = context.l10n;
    return switch (scope) {
      ViewerUnlinkScope.dive => l10n.media_viewer_unlinkHeldDive,
      ViewerUnlinkScope.site => l10n.media_viewer_unlinkHeldSite,
      ViewerUnlinkScope.gear => l10n.media_viewer_unlinkHeldGear,
      ViewerUnlinkScope.library => l10n.media_viewer_unlinkHeldLibrary,
    };
  }

  /// The strip over the item while its Unlink is held, kept above the
  /// bottom panel when that is shown; nothing otherwise.
  Widget? _unlinkStrip(BuildContext context, {required bool panelShown}) {
    final scope = unlinkScope;
    if (scope == null || !photoUnlinkHeld) return null;
    return Positioned(
      left: 16,
      right: 16,
      bottom:
          (panelShown ? _bottomPanelHeight : 0) +
          MediaQuery.paddingOf(context).bottom +
          16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: MediaViewerUnlinkStrip(
            message: _unlinkHeldMessageFor(context, scope),
            onUndo: undoPhotoUnlink,
          ),
        ),
      ),
    );
  }

  /// [child], the photo, dimmed while its Unlink is held.
  Widget _dimWhileUnlinkHeld(Widget child) =>
      Opacity(opacity: photoUnlinkHeld ? 0.45 : 1, child: child);

  /// Closes the viewer once a saved Unlink has taken its last item away
  /// (the pager drops the item through [unlinkedPhotoIds], so the next one
  /// takes its place, or the one before when it was the last).
  void _closeWhenEmptied() {
    if (_pageableMedia.isNotEmpty) return;
    // After the next frame: the leave guard reads the sitting from its last
    // build, which still had it open, and would refuse the pop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageableMedia.isEmpty) Navigator.of(context).maybePop();
    });
  }
}
