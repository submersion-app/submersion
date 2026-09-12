import 'package:flutter/material.dart';

import 'package:submersion/shared/selection/selection_leading.dart';

/// A checkbox inserted at the start of a row that has no leading element.
///
/// Tiles that own a leading widget -- a dive number badge, a site avatar --
/// wrap it in [SelectionLeading], which puts the checkbox ahead of it. Compact
/// and dense tiles start their row with the entity name and have no leading
/// widget to wrap, so this slot supplies the checkbox on its own. It sits
/// inside the tile's own padding, so the checkbox reads as part of the card
/// rather than floating beside it.
///
/// Nothing is reserved when selection mode is off: the slot collapses to zero
/// width, and the gap collapses with it rather than leaving the row's first
/// element indented by a checkbox that is not there.
class SelectionCheckboxSlot extends StatelessWidget {
  final bool isSelectionMode;
  final bool isChecked;

  /// False for rows that cannot be acted on, such as built-in reference data.
  final bool isSelectable;

  final ValueChanged<bool>? onChanged;

  /// Space between the checkbox and the row's first real element.
  final double gap;

  const SelectionCheckboxSlot({
    super.key,
    required this.isSelectionMode,
    required this.isChecked,
    this.isSelectable = true,
    this.onChanged,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionLeading(
      isSelectionMode: isSelectionMode,
      isChecked: isChecked,
      isSelectable: isSelectable,
      onChanged: onChanged,
      gap: gap,
      child: const SizedBox.shrink(),
    );
  }
}
