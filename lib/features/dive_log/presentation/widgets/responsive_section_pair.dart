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

  /// Whether both columns are stretched to the taller one's height in row
  /// mode, instead of each keeping its intrinsic height.
  ///
  /// Only for pairs whose cards fill the height they are given; a card that
  /// merely sits at its natural height gains nothing and pays an
  /// [IntrinsicHeight] layout pass for it.
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= minRowWidth) {
          final row = Row(
            crossAxisAlignment: stretch
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              SizedBox(width: columnGap),
              Expanded(child: second),
            ],
          );
          return stretch ? IntrinsicHeight(child: row) : row;
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
