import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';

/// A record page asked to open already unlocked, as the old edit addresses
/// ask (`/<records>/<id>/edit`, a list pane's `&mode=edit`; issue #4527).
///
/// The page unlocks once, when it first has the stored record, and once
/// more if the request turns on again later; Save, Cancel or a lock end
/// that sitting as any other, and the page stays locked after. The page's
/// owner is told once when that sitting has ended ([onOpenedSittingEnded]),
/// so a pane opened for editing can return to view mode.
///
/// The page calls [openUnlockedOnce] where it first has the stored record
/// and [noteOpenedSittingEnded] from [onEditChanged].
mixin RecordOpenUnlocked<W extends ConsumerStatefulWidget, T>
    on RecordEditHost<W, T> {
  /// Whether [widget] asks for the page opened unlocked.
  bool openUnlockedOf(W widget);

  /// Told once when the sitting this page opened unlocked has ended, but
  /// not when a leave the app asked about ended it.
  VoidCallback? get onOpenedSittingEnded;

  /// Whether the page is handing its unlock to another, such as the list
  /// pane it is moving into, which opens the record unlocked itself.
  bool get handsUnlockElsewhere => false;

  /// Whether the page has gone for good (its record deleted): the end of
  /// its sitting is not told, as the pane has moved on.
  bool get hasLeftForGood => false;

  bool _openedUnlocked = false;

  /// Whether the open sitting is the one this page opened unlocked, so its
  /// end is told to [onOpenedSittingEnded].
  bool _sittingOpenedUnlocked = false;

  /// Whether this page has already opened unlocked, or tried to.
  bool get hasOpenedUnlocked => _openedUnlocked;

  /// Unlocks on [stored] after this frame, once per page, when the page was
  /// asked to open unlocked. Call where the page first has the stored
  /// record.
  void openUnlockedOnce(T stored) {
    if (!openUnlockedOf(widget) || _openedUnlocked || isCreating) return;
    if (handsUnlockElsewhere) return;
    _openedUnlocked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // By now the page may no longer be asked, or may hold another record
      // (a stale read, another record handed to it): a record not its own
      // is not opened, and the page's own may be once it has it.
      if (!openUnlockedOf(widget) || recordIdOf(stored) != hostRecordId) {
        _openedUnlocked = false;
        return;
      }
      final controller = editController;
      if (controller.isUnlocked) return;
      controller.unlock(shownRecord(stored));
      _sittingOpenedUnlocked = controller.isUnlocked;
    });
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    final asked = openUnlockedOf(widget);
    final wasAsked = openUnlockedOf(oldWidget);
    // Turned on for a page already showing the record: open unlocked again.
    if (asked && !wasAsked) _openedUnlocked = false;
    // Turned off (the address left `mode=edit`, as Android's Back does on
    // the same page): a sitting it opened with nothing to lose locks.
    final controller = maybeEditController;
    if (!asked &&
        wasAsked &&
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
  void noteOpenedSittingEnded() {
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
    final ended = onOpenedSittingEnded;
    if (ended == null) return;
    // After the frame: the lock can come while the page is being built.
    // A lock on the way out (a leave that asked first, a deleted record)
    // is not reported: the page has gone, and the pane has moved on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !hasLeftForGood) ended();
    });
  }
}
