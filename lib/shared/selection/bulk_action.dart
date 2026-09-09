import 'dart:async';

import 'package:flutter/material.dart';

/// What a bulk action's handler reports once it finishes.
///
/// Leaving selection mode afterwards is decided centrally in SelectionAppBar
/// from this value, not by each handler calling `exit()` for itself. That is
/// deliberate: the ad-hoc version drifted, and the media library's Share
/// shipped as the one bulk action that finished and left the diver stranded
/// in multi-select (#1262), inline beside two siblings that both exited.
/// Returning an outcome is not optional, so a new action cannot repeat that
/// omission without failing to compile.
enum BulkActionOutcome {
  /// The action ran. The selection has served its purpose and the mode ends.
  completed,

  /// The diver backed out of a dialog, sheet or page before anything
  /// happened, so the selection they built is left intact to act on again.
  cancelled,

  /// The action was attempted and failed. The selection survives so the
  /// diver can retry after reading the error, rather than rebuilding it.
  failed,
}

/// One bulk operation a surface offers on the current selection.
///
/// Surfaces declare their extras as a list of these; the baseline
/// select-all / deselect-all / delete controls are supplied by
/// SelectionAppBar itself, so no surface can accidentally omit them.
@immutable
class BulkAction {
  /// Stable identifier, used as the widget key and in tests.
  final String id;

  /// Canonical icon for the concept. One icon per concept across the app:
  /// every merge-like action uses the same glyph, including dive combine.
  final IconData icon;

  /// Localized label, shown as a tooltip and as the overflow menu entry.
  final String label;

  /// Smallest selection this action accepts. Merge needs 2, delete needs 1.
  final int minCount;

  /// Largest selection this action accepts, when one applies.
  final int? maxCount;

  /// Destructive actions render in the error color and confirm before acting.
  final bool isDestructive;

  /// Actions that operate on the list rather than on the current selection,
  /// such as "select by date range", and so stay enabled at zero checked.
  final bool alwaysEnabled;

  /// Extra condition on *which* items are checked, not just how many.
  ///
  /// Count gates cannot express "every checked item is still active" or
  /// "every checked course is in progress", and those actions are incoherent
  /// on a mixed selection. Surfaces supply a predicate over the checked ids
  /// instead of contorting [maxCount].
  final bool Function(Set<String> checkedIds)? isEnabled;

  /// Whether completing this action should leave selection mode.
  ///
  /// False only for actions that *build* a selection rather than consume one
  /// -- select-by-date-range feeds the checked set and would be useless if it
  /// closed the bar it just populated. Every action that acts on the checked
  /// items leaves the default alone.
  final bool exitsSelectionOnComplete;

  /// Runs the action and reports what happened.
  ///
  /// Awaited by SelectionAppBar, so a handler that shows a dialog must return
  /// only once the dialog is resolved; returning early would exit the mode
  /// out from under a modal the diver is still reading.
  final FutureOr<BulkActionOutcome> Function() onInvoke;

  const BulkAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onInvoke,
    this.minCount = 1,
    this.maxCount,
    this.isDestructive = false,
    this.alwaysEnabled = false,
    this.isEnabled,
    this.exitsSelectionOnComplete = true,
  });

  /// Whether this action can run against a selection of [count] items.
  ///
  /// An empty selection never enables an action, whatever [minCount] says,
  /// unless the action declared itself [alwaysEnabled].
  bool isEnabledFor(int count) => isEnabledForSelection(count, const {});

  /// Whether this action can run against [checkedIds].
  ///
  /// [count] is passed separately so callers that only know the size (tests,
  /// simple surfaces) need not build a set.
  bool isEnabledForSelection(int count, Set<String> checkedIds) {
    if (alwaysEnabled) return true;
    if (count == 0) return false;
    if (count < minCount) return false;
    if (maxCount != null && count > maxCount!) return false;
    if (isEnabled != null && !isEnabled!(checkedIds)) return false;
    return true;
  }
}
