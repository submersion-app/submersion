import 'package:flutter/material.dart';

/// A row's leading slot, which gains a checkbox ahead of it in selection mode.
///
/// The checkbox is inserted, never swapped in: the leading element often
/// carries identifying data (a dive number, an avatar's initials), and a user
/// picking rows for a bulk action needs to see it (issue #1717). The checkbox
/// column slides in and out so entering and leaving the mode does not jolt the
/// list.
///
/// Non-selectable rows keep a blank column where the checkbox would be. The
/// missing checkbox tells the user at a glance that the row cannot be acted
/// on, and the blank keeps its leading element aligned with its neighbours.
class SelectionLeading extends StatelessWidget {
  /// The row's normal leading element: dive number badge, avatar, gear icon.
  final Widget child;

  final bool isSelectionMode;
  final bool isChecked;

  /// False for rows that cannot be acted on, such as built-in reference data.
  final bool isSelectable;

  final ValueChanged<bool>? onChanged;

  /// Space between the checkbox column and [child] in selection mode.
  final double gap;

  const SelectionLeading({
    super.key,
    required this.child,
    required this.isSelectionMode,
    required this.isChecked,
    this.isSelectable = true,
    this.onChanged,
    this.gap = 8,
  });

  /// How long the checkbox column takes to slide in or out. Content that has
  /// to move with it, such as `SelectionInset`, animates over the same span.
  static const Duration slideDuration = Duration(milliseconds: 150);

  /// Width of the checkbox below: a shrink-wrapped tap target (40) with the
  /// compact density adjustment (-8). A non-selectable row reserves exactly
  /// this, width only, so it lines up without growing taller.
  static const double _checkboxExtent = 32;

  /// The width the checkbox column adds ahead of [child], with [gap].
  static double columnWidth({required bool isSelectionMode, double gap = 8}) =>
      isSelectionMode ? _checkboxExtent + gap : 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: slideDuration,
          alignment: AlignmentDirectional.centerStart,
          child: isSelectionMode
              ? Padding(
                  padding: EdgeInsetsDirectional.only(end: gap),
                  child: isSelectable
                      ? Checkbox(
                          value: isChecked,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: onChanged == null
                              ? null
                              : (value) => onChanged!(value ?? false),
                        )
                      : const SizedBox(width: _checkboxExtent),
                )
              : const SizedBox.shrink(),
        ),
        child,
      ],
    );
  }
}
