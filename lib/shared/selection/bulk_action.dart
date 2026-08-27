import 'package:flutter/material.dart';

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

  final VoidCallback onInvoke;

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
