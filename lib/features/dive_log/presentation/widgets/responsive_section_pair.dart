import 'package:flutter/material.dart';

/// Renders two dive-detail cards side by side when there is enough horizontal
/// room, and stacked otherwise.
///
/// At or above [minRowWidth] the cards sit in a top-aligned [Row] of two equal
/// [Expanded] columns separated by [columnGap], each card keeping its own
/// intrinsic height. Below it they stack in a [Column] with [stackGap] between
/// them -- visually identical to rendering the two cards as adjacent stacked
/// sections.
///
/// The widget measures its own available width with a [LayoutBuilder], so it
/// behaves correctly both in the full-width standalone detail page and inside
/// the narrower master-detail pane, without consulting the screen width.
class ResponsiveSectionPair extends StatelessWidget {
  const ResponsiveSectionPair({
    super.key,
    required this.first,
    required this.second,
    this.minRowWidth = 700,
    this.columnGap = 16,
    this.stackGap = 24,
  });

  /// The leading card (left column in row mode, top card when stacked).
  final Widget first;

  /// The trailing card (right column in row mode, bottom card when stacked).
  final Widget second;

  /// At or above this available width the pair lays out as two columns.
  final double minRowWidth;

  /// Horizontal gutter between the two columns in row mode.
  final double columnGap;

  /// Vertical gap between the two cards when stacked.
  final double stackGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= minRowWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              SizedBox(width: columnGap),
              Expanded(child: second),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            first,
            SizedBox(height: stackGap),
            second,
          ],
        );
      },
    );
  }
}
