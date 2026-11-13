import 'package:flutter/material.dart';

/// One line of a [SacSegmentTable].
class SacSegmentTableRow {
  final String label;

  /// What this row is drawn in elsewhere, as a key to the chart and the share
  /// bar. Null gives no dot.
  final Color? color;

  /// The rate as shown, with no unit when it matches the column heading.
  final String rate;

  /// The gas used, with its unit.
  final String used;

  /// The row's share of the gas its section used, such as `59%`, or null
  /// where the section's gas can't be added up.
  final String? share;
  final String depth;
  final String duration;

  /// Whether the row is drawn as the current selection.
  final bool selected;

  /// The whole row for a screen reader, with the rate's unit.
  final String semanticLabel;

  const SacSegmentTableRow({
    required this.label,
    this.color,
    required this.rate,
    required this.used,
    this.share,
    required this.depth,
    required this.duration,
    required this.selected,
    required this.semanticLabel,
  });
}

/// A titled run of rows in a [SacSegmentTable].
class SacSegmentTableSection {
  final String title;
  final List<SacSegmentTableRow> rows;

  const SacSegmentTableSection({required this.title, required this.rows});
}

/// The phase and gas breakdowns of the Gas consumption by segment card: for
/// each row its rate, the gas it used and its share, its depth and its time.
///
/// Sections share one set of columns, headed once by the first section, so
/// rates line up down the card and the unit is not repeated on each line. The
/// number columns take their content's width, so a long unit, a translated
/// heading or larger text squeezes the label rather than the figures.
class SacSegmentTable extends StatelessWidget {
  static const double _minRowHeight = 28;
  static const double _columnGap = 10;
  static const double _labelInset = 4;

  final String rateHeading;
  final String usedHeading;
  final String depthHeading;
  final String durationHeading;
  final List<SacSegmentTableSection> sections;

  const SacSegmentTable({
    super.key,
    required this.rateHeading,
    required this.usedHeading,
    required this.depthHeading,
    required this.durationHeading,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headingStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget number(String text, TextStyle? style) => ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: _columnGap,
          end: _labelInset,
        ),
        child: Text(text, style: style, textAlign: TextAlign.end),
      ),
    );

    TableRow heading(SacSegmentTableSection section, {required bool first}) {
      return TableRow(
        decoration: first
            ? null
            : BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(section.title, style: headingStyle),
          ),
          number(first ? rateHeading : '', headingStyle),
          number(first ? usedHeading : '', headingStyle),
          number(first ? depthHeading : '', headingStyle),
          number(first ? durationHeading : '', headingStyle),
        ],
      );
    }

    TableRow row(SacSegmentTableRow row) {
      final style = theme.textTheme.bodySmall;
      final secondary = style?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      return TableRow(
        decoration: row.selected
            ? BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary),
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        children: [
          _LabelCell(row: row, minHeight: _minRowHeight, inset: _labelInset),
          number(row.rate, style?.copyWith(fontWeight: FontWeight.w600)),
          _UsedCell(
            used: row.used,
            share: row.share,
            style: style,
            shareStyle: secondary,
            padding: const EdgeInsetsDirectional.only(
              start: _columnGap,
              end: _labelInset,
            ),
          ),
          number(row.depth, secondary),
          number(row.duration, secondary),
        ],
      );
    }

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
        3: IntrinsicColumnWidth(),
        4: IntrinsicColumnWidth(),
      },
      children: [
        for (final (index, section) in sections.indexed) ...[
          heading(section, first: index == 0),
          ...section.rows.map(row),
        ],
      ],
    );
  }
}

class _UsedCell extends StatelessWidget {
  final String used;
  final String? share;
  final TextStyle? style;
  final TextStyle? shareStyle;
  final EdgeInsetsGeometry padding;

  const _UsedCell({
    required this.used,
    required this.share,
    required this.style,
    required this.shareStyle,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: padding,
        // One text, so on the narrowest card the share wraps under the
        // amount rather than overflowing.
        child: Text.rich(
          TextSpan(
            text: used,
            style: style,
            children: [
              if (share != null) TextSpan(text: ' $share', style: shareStyle),
            ],
          ),
          textAlign: TextAlign.end,
        ),
      ),
    );
  }
}

class _LabelCell extends StatelessWidget {
  static const double _dotSize = 8;
  static const double _dotGap = 6;

  final SacSegmentTableRow row;
  final double minHeight;
  final double inset;

  const _LabelCell({
    required this.row,
    required this.minHeight,
    required this.inset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = row.color;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: row.semanticLabel,
      selected: row.selected,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: inset),
          // A stack rather than a row, so a column squeezed narrower than
          // the dot clips the label instead of overflowing.
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              if (color != null)
                SizedBox.square(
                  dimension: _dotSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: color == null ? 0 : _dotSize + _dotGap,
                ),
                child: Text(
                  row.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: row.selected ? FontWeight.bold : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
