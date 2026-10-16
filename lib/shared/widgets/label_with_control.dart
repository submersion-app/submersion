import 'package:flutter/material.dart';

/// A label with a width-hungry control after it, such as a dropdown or a
/// pair of text buttons, that moves the control onto its own line when the
/// two cannot share one.
///
/// A `Row` with the label in `Expanded` (or a `ListTile` with the control in
/// `trailing`) lays the control out first and gives the label what is left.
/// In a longer translation that left the label a few pixels, and it broke
/// one character per line (issue #3358). Here the label keeps the full width
/// when it needs it, and the control drops below it instead.
///
/// In a `ListTile`, pass this as the `title` and leave `trailing` empty. It
/// fills the width it is offered, so that width must be bounded.
class LabelWithControl extends StatelessWidget {
  const LabelWithControl({
    super.key,
    required this.label,
    required this.control,
    this.spacing = 16,
    this.runSpacing = 4,
  });

  /// Usually a [Text]. It wraps between words once it has a line of its own.
  final Widget label;

  /// Sits at the far end of the line when it fits beside [label], and at the
  /// start of the next line when it does not.
  final Widget control;

  /// The least gap between [label] and [control] on a shared line.
  final double spacing;

  /// The gap between [label] and [control] once they are on two lines.
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    // A Wrap offered a loose width shrinks to its children, which would
    // leave the control right after the label rather than at the far end.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: spacing,
        runSpacing: runSpacing,
        children: [label, control],
      ),
    );
  }
}
