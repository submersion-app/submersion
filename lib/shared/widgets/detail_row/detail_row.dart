import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/detail_row/render_detail_row.dart';

/// A detail-page row: an optional leading icon and a label, then the value
/// right beside them rather than at the far edge (issue #3678).
///
/// Inside a [DetailRowGroup] the labels form one column as wide as the
/// group's widest label, so a card's values all start at the same place.
/// The column never takes more than [maxLabelShare] of the row; a longer
/// label wraps within it. The value starts at the column's end, aligned to
/// the start, and wraps within the rest of the row.
///
/// The row adds no semantics of its own: a caller that reads the row as
/// one node, or makes it a button, wraps it as before.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.icon,
    this.iconSize = 20,
    this.iconGap = 12,
    this.iconColor,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  /// A row whose value is plain text.
  DetailRow.text({
    Key? key,
    required String label,
    required String value,
    TextStyle? valueStyle,
    int? maxLines,
    TextOverflow? overflow,
    TextStyle? labelStyle,
    IconData? icon,
    double iconSize = 20,
    double iconGap = 12,
    Color? iconColor,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 8),
  }) : this(
         key: key,
         label: label,
         value: Text(
           value,
           style: valueStyle,
           maxLines: maxLines,
           overflow: overflow,
         ),
         labelStyle: labelStyle,
         icon: icon,
         iconSize: iconSize,
         iconGap: iconGap,
         iconColor: iconColor,
         padding: padding,
       );

  /// The space between the label column and the value.
  static const double gap = 16;

  /// The most of the row's width the label column may take.
  static const double maxLabelShare = 0.4;

  /// The field name. An empty label leaves the cell blank, so the value of
  /// a continuation row lines up under the value above it. A group whose
  /// rows have no label at all has no gap either, so its values start at
  /// the edge.
  final String label;
  final Widget value;

  /// Defaults to `bodyMedium` in `onSurfaceVariant`.
  final TextStyle? labelStyle;

  /// Drawn before the label, inside the label column.
  final IconData? icon;
  final double iconSize;
  final double iconGap;

  /// Defaults to the primary colour.
  final Color? iconColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = DefaultTextStyle.of(context).style.merge(
      labelStyle ??
          theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
    );

    // Measured while building, so every row of a group has reported its
    // width before any of them lays out.
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final textWidth = label.isEmpty ? 0.0 : painter.width;
    final lineHeight = painter.preferredLineHeight;
    painter.dispose();

    final hasIcon = icon != null;
    // The first line is as tall as the taller of the icon and a line of
    // text; whichever is shorter is centred on it.
    final firstLine = hasIcon ? math.max(lineHeight, iconSize) : lineHeight;
    final textTop = (firstLine - lineHeight) / 2;

    final labelCell = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasIcon) ...[
          SizedBox(
            width: iconSize,
            height: firstLine,
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? theme.colorScheme.primary,
              ),
            ),
          ),
          SizedBox(width: iconGap),
        ],
        Flexible(
          child: Padding(
            padding: EdgeInsets.only(top: textTop),
            child: Text(label, style: style),
          ),
        ),
      ],
    );

    return Padding(
      padding: padding,
      child: DetailRowLayout(
        label: labelCell,
        value: Padding(
          padding: EdgeInsets.only(top: textTop),
          child: value,
        ),
        column: DetailRowGroup.maybeOf(context),
        ownLabelWidth: textWidth + (hasIcon ? iconSize + iconGap : 0),
        gap: gap,
        maxLabelShare: maxLabelShare,
      ),
    );
  }
}
