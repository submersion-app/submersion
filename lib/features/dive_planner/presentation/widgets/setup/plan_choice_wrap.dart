import 'package:flutter/material.dart';

/// A small fixed-choice selector that reflows to multiple lines instead of
/// scrolling or compressing its labels (issue #3552 follow-up).
///
/// [SegmentedButton] packs every option into one row: at the Setup
/// accordion's narrow widths this either wrapped labels mid-word, or - once
/// given unconstrained width to avoid that - pushed later options out of
/// view with no indication they existed. [Wrap] solves both: each choice is
/// its own full-size, always-readable chip, and the row breaks onto a
/// second line on its own once it runs out of room.
class PlanChoiceWrap<T> extends StatelessWidget {
  const PlanChoiceWrap({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// Each choice's value and label, in display order.
  final List<(T value, String label)> options;

  final T selected;

  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onChanged(value),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}
