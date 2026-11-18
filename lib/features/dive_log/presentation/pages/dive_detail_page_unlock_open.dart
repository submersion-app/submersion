part of 'dive_detail_page.dart';

/// Opening the page already unlocked, as the old edit addresses ask:
/// `/dives/<id>/edit` and the list pane's `&mode=edit` (issue #4527,
/// plan 11). What every record page shares is [RecordOpenUnlocked]; this
/// is the dive's own: where the request comes from, who is told, and the
/// two moments the page is on its way out.
mixin _DiveDetailPageUnlockOpen
    on
        ConsumerState<DiveDetailPage>,
        _DiveDetailPageActions,
        RecordEditHost<DiveDetailPage, Dive>,
        _DiveDetailPageEditing,
        RecordOpenUnlocked<DiveDetailPage, Dive> {
  /// Set once a desktop root visit starts moving this page into the list
  /// pane, so it moves once; with an edit address the pane opens the dive
  /// unlocked itself, and this page, about to go, does not.
  bool _redirectingToPane = false;

  @override
  bool openUnlockedOf(DiveDetailPage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  bool get handsUnlockElsewhere => _redirectingToPane;

  @override
  bool get hasLeftForGood => _leftDeletedDive;

  /// Called on every change of the sitting.
  @override
  void _noteSittingEnded() => noteOpenedSittingEnded();
}
