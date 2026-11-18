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

  /// Set once a desktop root visit starts moving this page into the list
  /// pane, so it moves once; with an edit address the pane opens the dive
  /// unlocked itself, and this page, about to go, does not.
  bool _redirectingToPane = false;

  /// Unlocks on [stored] after this frame, once per page, when the page was
  /// asked to open unlocked. Call where the page first has the stored dive.
  void _openUnlockedOnce(Dive stored) {
    if (!widget.openUnlocked || _openedUnlocked || isCreating) return;
    // A page moving into the list pane leaves the unlock to the pane's.
    if (_redirectingToPane) return;
    _openedUnlocked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = editController;
      if (controller.isUnlocked) return;
      controller.unlock(shownRecord(stored));
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
    // Turned off (the address left `mode=edit`, as Android's Back does on
    // the same page): a sitting it opened with nothing to lose locks.
    final controller = maybeEditController;
    if (!widget.openUnlocked &&
        oldWidget.openUnlocked &&
        _sittingOpenedUnlocked &&
        controller != null &&
        controller.isUnlocked &&
        !controller.isDirty &&
        !controller.isBusy) {
      controller.lock();
    }
  }

  /// Called on every change of the sitting: tells the page's owner once
  /// when the sitting it opened unlocked has ended.
  @override
  void _noteSittingEnded() {
    if (isSittingOpen) return;
    // Whichever sitting a leave discarded, its end clears the mark, so it
    // cannot stand for a later sitting's end.
    final byLeave = sittingEndedByLeave;
    sittingEndedByLeave = false;
    if (!_sittingOpenedUnlocked) return;
    _sittingOpenedUnlocked = false;
    // Discarded by a leave the app asked about: the pane is moving on, and
    // the router may not have applied that yet.
    if (byLeave) return;
    final ended = widget.onSittingEnded;
    if (ended == null) return;
    // After the frame: the lock can come while the page is being built.
    // A lock on the way out (a leave that asked first, a deleted dive) is
    // not reported: the page has gone, and the pane has moved on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_leftDeletedDive) ended();
    });
  }
}
