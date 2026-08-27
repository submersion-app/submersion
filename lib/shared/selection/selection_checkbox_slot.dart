import 'package:flutter/material.dart';

import 'package:submersion/shared/selection/selection_leading.dart';

/// A checkbox inserted at the start of a row that has no leading element.
///
/// Tiles that own a leading widget -- a dive number badge, a site avatar --
/// use [SelectionLeading] to swap it for the checkbox. Compact and dense tiles
/// start their row with the entity name and have nothing to swap, so the
/// checkbox has to be inserted instead. This keeps that insertion inside the
/// tile's own padding, so the checkbox reads as part of the card rather than
/// floating beside it.
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

  static const Duration _gapDuration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final showCheckbox = isSelectionMode && isSelectable;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectionLeading(
          isSelectionMode: isSelectionMode,
          isChecked: isChecked,
          isSelectable: isSelectable,
          onChanged: onChanged,
          child: const SizedBox.shrink(),
        ),
        // The gap belongs to the checkbox, so it collapses with it.
        AnimatedSize(
          duration: _gapDuration,
          child: SizedBox(width: showCheckbox ? gap : 0),
        ),
      ],
    );
  }
}
