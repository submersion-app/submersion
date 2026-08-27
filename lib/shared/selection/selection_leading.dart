import 'package:flutter/material.dart';

/// A row's leading slot, which becomes a checkbox in selection mode.
///
/// The swap is animated so entering and leaving the mode does not jolt the
/// list. Non-selectable rows keep their [child] and render no checkbox, which
/// is what tells the user at a glance that the row cannot be acted on.
class SelectionLeading extends StatelessWidget {
  /// The row's normal leading element: dive number badge, avatar, gear icon.
  final Widget child;

  final bool isSelectionMode;
  final bool isChecked;

  /// False for rows that cannot be acted on, such as built-in reference data.
  final bool isSelectable;

  final ValueChanged<bool>? onChanged;

  const SelectionLeading({
    super.key,
    required this.child,
    required this.isSelectionMode,
    required this.isChecked,
    this.isSelectable = true,
    this.onChanged,
  });

  static const Duration _swapDuration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final showCheckbox = isSelectionMode && isSelectable;

    return AnimatedSwitcher(
      duration: _swapDuration,
      child: showCheckbox
          ? Checkbox(
              key: const ValueKey('selection_leading_checkbox'),
              value: isChecked,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value ?? false),
            )
          : KeyedSubtree(
              key: const ValueKey('selection_leading_child'),
              child: child,
            ),
    );
  }
}
