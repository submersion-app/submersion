import 'package:flutter/foundation.dart';

import 'package:submersion/shared/selection/selection_state.dart';

/// Inclusive id span between [anchorId] and [targetId] within [orderedIds].
///
/// Order-independent: extending backwards selects the same range. Returns an
/// empty list when either id is absent, so a stale anchor cannot select a
/// wrong span.
List<String> idsInRange(
  List<String> orderedIds,
  String anchorId,
  String targetId,
) {
  final anchorIndex = orderedIds.indexOf(anchorId);
  final targetIndex = orderedIds.indexOf(targetId);
  if (anchorIndex < 0 || targetIndex < 0) return const [];

  final lo = anchorIndex < targetIndex ? anchorIndex : targetIndex;
  final hi = anchorIndex < targetIndex ? targetIndex : anchorIndex;
  return [for (var i = lo; i <= hi; i++) orderedIds[i]];
}

/// Owns the multi-selection state machine for one list or grid surface.
///
/// Deliberately not a Riverpod provider: selection prunes to the visible set
/// and does not survive leaving the surface, so it is ephemeral view state.
/// A plain [ValueNotifier] is testable without a ProviderContainer.
class SelectionController extends ValueNotifier<SelectionState> {
  SelectionController() : super(SelectionState.inactive);

  /// Enter selection mode deliberately, with nothing checked.
  ///
  /// No-op when already active, so tapping Select twice does not clear the
  /// user's work.
  void enterExplicit() {
    if (value.isActive) return;
    value = const SelectionState(
      checkedIds: <String>{},
      isActive: true,
      enteredExplicitly: true,
      anchorId: null,
    );
  }

  /// Enter selection mode as a side effect of a modifier-click, checking
  /// [id]. Behaves as [toggle] when the mode is already active.
  ///
  /// Touch has no equivalent: long-press no longer enters selection mode on
  /// any surface, so on a phone every entry is explicit and this is the only
  /// path that still evaporates at zero checked.
  ///
  /// [seedId] is checked alongside [id] on entry: the row the surface was
  /// already showing as current -- the highlighted row backing the detail
  /// pane -- so a modifier-click adds to what the user sees selected instead
  /// of discarding it, matching Finder. The anchor is still [id], so a
  /// following shift-click extends from the row just clicked. Ignored once
  /// the mode is active, where the checked set already holds the intent.
  void enterImplicit(String id, {String? seedId}) {
    if (value.isActive) {
      toggle(id);
      return;
    }
    value = SelectionState(
      checkedIds: {?seedId, id},
      isActive: true,
      enteredExplicitly: false,
      anchorId: id,
    );
  }

  /// Check or uncheck [id], moving the range anchor to it.
  ///
  /// Unchecking the last item ends an implicitly entered mode.
  void toggle(String id) {
    final next = Set<String>.from(value.checkedIds);
    if (!next.remove(id)) next.add(id);

    if (next.isEmpty && !value.enteredExplicitly) {
      exit();
      return;
    }
    value = value.copyWith(checkedIds: next, anchorId: id);
  }

  /// Check every item between the anchor and [targetId] in [orderedIds].
  ///
  /// The anchor is the controller's current anchor, else [fallbackAnchorId]
  /// (the row highlighted in the detail pane), else [targetId] itself. The
  /// anchor never moves during extension, so consecutive shift-clicks extend
  /// from the original origin rather than walking it forward.
  void extendTo(
    String targetId,
    List<String> orderedIds, {
    String? fallbackAnchorId,
  }) {
    if (!orderedIds.contains(targetId)) return;

    // A stale anchor -- a highlighted row that a filter change pushed out of
    // the visible list, say -- yields an empty range. Fall back to anchoring
    // on the target so shift-click always checks at least the clicked row,
    // rather than activating the mode with nothing checked.
    var anchor = value.anchorId ?? fallbackAnchorId ?? targetId;
    if (!orderedIds.contains(anchor)) anchor = targetId;

    final next = Set<String>.from(value.checkedIds)
      ..addAll(idsInRange(orderedIds, anchor, targetId));

    value = SelectionState(
      checkedIds: next,
      isActive: true,
      enteredExplicitly: value.isActive ? value.enteredExplicitly : false,
      anchorId: anchor,
    );
  }

  /// Check every id in [selectableIds].
  ///
  /// The surface passes only rows that can actually be acted on, so
  /// non-selectable rows are excluded by omission rather than by a filter
  /// here. Counts as explicit entry: the user asked for all of them.
  void selectAll(List<String> selectableIds) {
    value = SelectionState(
      checkedIds: Set<String>.from(selectableIds),
      isActive: true,
      enteredExplicitly: true,
      anchorId: value.anchorId,
    );
  }

  /// Replace the checked set with [ids], leaving the entry mode alone.
  ///
  /// For surfaces whose child widget owns the gesture layer and reports its
  /// complete selection rather than a delta -- the media grid. [selectAll] is
  /// the wrong call there despite also taking a whole set, because it declares
  /// the mode explicit, which would launder an incidental gesture into a
  /// deliberate entry and stop it evaporating at zero checked.
  ///
  /// Only a gesture can activate the mode through this path, so an activating
  /// call counts as implicit entry; the Select button routes through
  /// [enterExplicit] instead. An empty [ids] on an inactive controller is a
  /// no-op rather than an activation.
  ///
  /// No grid gesture activates the mode today -- the media grids are driven
  /// into selection by their Select control -- but the branch is kept so a
  /// future grid gesture cannot silently declare itself deliberate.
  void replaceChecked(List<String> ids) {
    final next = ids.toSet();

    if (!value.isActive) {
      if (next.isEmpty) return;
      value = SelectionState(
        checkedIds: next,
        isActive: true,
        enteredExplicitly: false,
        anchorId: ids.first,
      );
      return;
    }

    if (next.isEmpty && !value.enteredExplicitly) {
      exit();
      return;
    }
    value = value.copyWith(checkedIds: next);
  }

  /// Uncheck everything, ending an implicitly entered mode.
  ///
  /// Ending the implicit mode here is the same rule as unchecking the last
  /// item by hand, so the two paths cannot disagree.
  void deselectAll() {
    if (!value.enteredExplicitly) {
      exit();
      return;
    }
    value = value.copyWith(checkedIds: const <String>{}, clearAnchor: true);
  }

  /// Drop checked ids that are no longer in [visibleIds].
  ///
  /// Called whenever the filtered, searched or sorted list changes, so the
  /// count always matches what is on screen and a bulk action can never reach
  /// a record the user cannot see.
  void pruneTo(List<String> visibleIds) {
    if (!value.isActive) return;

    final visible = visibleIds.toSet();
    final next = value.checkedIds.where(visible.contains).toSet();
    final anchorStillVisible =
        value.anchorId != null && visible.contains(value.anchorId);

    if (next.length == value.checkedIds.length &&
        (value.anchorId == null || anchorStillVisible)) {
      return;
    }

    if (next.isEmpty && !value.enteredExplicitly) {
      exit();
      return;
    }

    value = value.copyWith(
      checkedIds: next,
      anchorId: anchorStillVisible ? value.anchorId : null,
      clearAnchor: !anchorStillVisible,
    );
  }

  /// Leave selection mode and discard the selection.
  void exit() {
    value = SelectionState.inactive;
  }
}
