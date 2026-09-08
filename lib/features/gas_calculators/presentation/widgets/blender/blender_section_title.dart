import 'package:flutter/material.dart';

/// The heading style shared by every blender card section.
class BlenderSectionTitle extends StatelessWidget {
  const BlenderSectionTitle(this.text, {super.key, this.bottomPadding = 12});

  final String text;

  /// The gap to whatever follows the heading in its column.
  ///
  /// Set it to zero when the heading shares a row with something else: the
  /// padding is part of this widget's height, so a centre-aligned row would
  /// centre the padded box and leave the text itself sitting half the padding
  /// too high (PR #1359 review, point 6). The row then owns the spacing.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottomPadding),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}
