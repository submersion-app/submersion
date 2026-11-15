import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/equal_height_row.dart';

/// Renders two dive-detail cards side by side when there is enough horizontal
/// room, and stacked otherwise.
///
/// At or above [minRowWidth] the cards sit in two equal columns separated by
/// [columnGap], and the shorter card grows to the taller one's height, so no
/// blank space is left under it before the next card (issue #4583). Below it
/// they stack in a [Column] with [stackGap] between them, each at its own
/// height: visually identical to rendering the two cards as adjacent stacked
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
    this.stackedFirst,
    this.stackedSecond,
    this.minRowWidth = 700,
    this.columnGap = 16,
    this.stackGap = 24,
    this.stretch = false,
  });

  /// The leading card (left column in row mode, top card when stacked unless
  /// [stackedFirst] is given).
  final Widget first;

  /// The trailing card (right column in row mode, bottom card when stacked
  /// unless [stackedSecond] is given).
  final Widget second;

  /// What to show in place of [first] when the pair stacks.
  ///
  /// A [stretch] pair's cards are built to fill the height the row hands them,
  /// with [Expanded] children inside. The stacked [Column] has no height to
  /// hand out, so those same cards would collapse their flexible parts to
  /// nothing there; this is where their natural-height variant goes.
  final Widget? stackedFirst;

  /// What to show in place of [second] when the pair stacks. See
  /// [stackedFirst].
  final Widget? stackedSecond;

  /// At or above this available width the pair lays out as two columns.
  final double minRowWidth;

  /// Horizontal gutter between the two columns in row mode.
  final double columnGap;

  /// Vertical gap between the two cards when stacked.
  final double stackGap;

  /// Whether the row shares its height through an [IntrinsicHeight] instead
  /// of an [EqualHeightRow].
  ///
  /// Every row gives both cards the taller one's height. Only a pair whose
  /// cards hold [Expanded] children, and so cannot be laid out at their
  /// natural height first, needs this: [IntrinsicHeight] measures them
  /// without laying them out. Its cards must then answer intrinsic size
  /// queries, so nothing in them may hold a [LayoutBuilder].
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= minRowWidth) {
          if (!stretch) {
            return EqualHeightRow(gap: columnGap, children: [first, second]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: first),
                SizedBox(width: columnGap),
                Expanded(child: second),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stackedFirst ?? first,
            SizedBox(height: stackGap),
            stackedSecond ?? second,
          ],
        );
      },
    );
  }
}
