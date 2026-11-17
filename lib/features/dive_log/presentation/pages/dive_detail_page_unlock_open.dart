part of 'dive_detail_page.dart';

/// Opening the page already unlocked, as the old edit addresses ask:
/// `/dives/<id>/edit` and the list pane's `&mode=edit` (issue #4527,
/// plan 11). The page unlocks once, when it first has the dive, and once
/// more if [DiveDetailPage.openUnlocked] turns on later; Save, Cancel or a
/// lock end that sitting as any other, and the page stays locked after.
mixin _DiveDetailPageUnlockOpen
    on
        ConsumerState<DiveDetailPage>,
        _DiveDetailPageActions,
        _DiveDetailPageEditing {
  /// Whether this page has already opened unlocked (or tried to).
  bool _openedUnlocked = false;

  /// Whether the open sitting is the one this page opened unlocked, so its
  /// end is told to [DiveDetailPage.onSittingEnded].
  bool _sittingOpenedUnlocked = false;

  /// Unlocks on [stored] after this frame, once per page, when the page was
  /// asked to open unlocked. Call where the page first has the stored dive.
  void _openUnlockedOnce(Dive stored) {
    if (!widget.openUnlocked || _openedUnlocked || isCreating) return;
    _openedUnlocked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = editController;
      if (controller.isUnlocked) return;
      controller.unlock(shownDive(stored));
      _sittingOpenedUnlocked = controller.isUnlocked;
    });
  }

  @override
  void didUpdateWidget(DiveDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Turned on for a page already showing the dive: open unlocked again.
    if (widget.openUnlocked && !oldWidget.openUnlocked) {
      _openedUnlocked = false;
    }
  }

  /// Called on every change of the sitting: tells the page's owner once
  /// when the sitting it opened unlocked has ended.
  @override
  void _noteSittingEnded() {
    if (!_sittingOpenedUnlocked || isSittingOpen) return;
    _sittingOpenedUnlocked = false;
    final ended = widget.onSittingEnded;
    if (ended == null) return;
    // After the frame: the lock can come while the page is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_leftDeletedDive) ended();
    });
  }
}
