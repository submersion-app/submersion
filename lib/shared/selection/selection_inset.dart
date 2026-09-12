import 'package:flutter/material.dart';

import 'package:submersion/shared/selection/selection_leading.dart';

/// Start padding for a card line that sits under the first line's content.
///
/// Card tiles put their leading element on the first line and indent the lines
/// below it by a fixed [start] so they align with the title. In selection mode
/// [SelectionLeading] inserts a checkbox column ahead of that leading element,
/// pushing the title along; this inset grows by the same width, over the same
/// slide, so the lower lines stay under the title instead of drifting left of
/// it.
class SelectionInset extends StatelessWidget {
  final bool isSelectionMode;

  /// The indent outside selection mode: the leading element plus its gap.
  final double start;

  final Widget child;

  const SelectionInset({
    super.key,
    required this.isSelectionMode,
    required this.start,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: SelectionLeading.slideDuration,
      padding: EdgeInsetsDirectional.only(
        start:
            start +
            SelectionLeading.columnWidth(isSelectionMode: isSelectionMode),
      ),
      child: child,
    );
  }
}
