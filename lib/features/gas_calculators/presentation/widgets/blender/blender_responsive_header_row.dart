import 'package:flutter/material.dart';

/// Lays [leading] and [trailing] side by side in a [Row] when the available
/// width is at least [minRowWidth], and stacks them in a [Column] (leading
/// above trailing) otherwise.
///
/// In row mode [trailing] is capped at [maxTrailingShare] of the width, so a
/// label that is still too wide (a long translation, a large system text
/// size) shortens to its ellipsis instead of squeezing [leading] to nothing
/// and overflowing the row.
///
/// Every blender card row that pairs a title or input field on the left with
/// a single action on the right used to cope with a narrow phone or a
/// narrow master-detail pane in two different, both flawed, ways: a title
/// row centred [BlenderSectionTitle]'s own bottom padding into the row,
/// offsetting the title against the action instead of lining them up; a
/// field row shortened the action's label down to an ellipsis, hiding it
/// almost entirely (issue #2926 follow-up). Stacking instead keeps both
/// fully visible and each at its own natural height.
///
/// Measures its own available width with a [LayoutBuilder] rather than the
/// screen width, the same approach as `BlenderResponsiveFieldRow` and
/// `ResponsiveSectionPair`.
class BlenderResponsiveHeaderRow extends StatelessWidget {
  const BlenderResponsiveHeaderRow({
    super.key,
    required this.leading,
    required this.trailing,
    this.minRowWidth = 320,
    this.gap = 8,
    this.rowCrossAxisAlignment = CrossAxisAlignment.center,
    this.maxTrailingShare = 0.6,
  });

  final Widget leading;
  final Widget trailing;

  /// The available width at or above which this shares a row instead of
  /// stacking.
  final double minRowWidth;

  /// Gutter between [leading] and [trailing], in either orientation.
  final double gap;

  /// Cross-axis alignment in row mode. A field with a floating label wants
  /// [CrossAxisAlignment.start] rather than the default centring, so the
  /// trailing action lines up with the field's top edge, not its label.
  final CrossAxisAlignment rowCrossAxisAlignment;

  /// The largest fraction of the available width [trailing] may take in row
  /// mode; [leading] always keeps the rest.
  final double maxTrailingShare;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= minRowWidth) {
        return Row(
          crossAxisAlignment: rowCrossAxisAlignment,
          children: [
            Expanded(child: leading),
            SizedBox(width: gap),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * maxTrailingShare,
              ),
              child: trailing,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          SizedBox(height: gap),
          trailing,
        ],
      );
    },
  );
}
