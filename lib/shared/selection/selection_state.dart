import 'package:flutter/foundation.dart';

/// Immutable snapshot of a multi-selection on one list or grid surface.
///
/// [enteredExplicitly] records how selection mode began, because that decides
/// how it ends: a mode the user asked for with the Select button survives at
/// zero checked items, while one entered incidentally by modifier-click
/// evaporates when the last item is unchecked.
@immutable
class SelectionState {
  /// Ids of the checked items. Always entity ids, never list indices.
  final Set<String> checkedIds;

  /// Whether selection mode is active at all.
  final bool isActive;

  /// True when the mode was entered deliberately (Select button, Ctrl/Cmd-A).
  final bool enteredExplicitly;

  /// Fixed origin for shift-click range extension.
  final String? anchorId;

  const SelectionState({
    required this.checkedIds,
    required this.isActive,
    required this.enteredExplicitly,
    required this.anchorId,
  });

  /// The resting state: no mode, nothing checked, no anchor.
  static const SelectionState inactive = SelectionState(
    checkedIds: <String>{},
    isActive: false,
    enteredExplicitly: false,
    anchorId: null,
  );

  int get count => checkedIds.length;

  bool isChecked(String id) => checkedIds.contains(id);

  SelectionState copyWith({
    Set<String>? checkedIds,
    bool? isActive,
    bool? enteredExplicitly,
    String? anchorId,
    bool clearAnchor = false,
  }) {
    return SelectionState(
      checkedIds: checkedIds ?? this.checkedIds,
      isActive: isActive ?? this.isActive,
      enteredExplicitly: enteredExplicitly ?? this.enteredExplicitly,
      anchorId: clearAnchor ? null : (anchorId ?? this.anchorId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SelectionState &&
      other.isActive == isActive &&
      other.enteredExplicitly == enteredExplicitly &&
      other.anchorId == anchorId &&
      setEquals(other.checkedIds, checkedIds);

  @override
  int get hashCode => Object.hash(
    isActive,
    enteredExplicitly,
    anchorId,
    Object.hashAllUnordered(checkedIds),
  );
}
