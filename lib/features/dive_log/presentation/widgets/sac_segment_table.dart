import 'package:flutter/material.dart';

/// One line of a [SacSegmentTable].
class SacSegmentTableRow {
  final String label;
  final IconData? icon;

  /// Length of the bar behind the label as a share of the widest, 0 to 1.
  final double barFactor;

  /// The rate as shown, with no unit when it matches the column heading.
  final String rate;
  final String depth;
  final String duration;

  /// Whether the row is drawn as the current selection.
  final bool selected;

  /// The whole row for a screen reader, with the rate's unit.
  final String semanticLabel;

  const SacSegmentTableRow({
    required this.label,
    this.icon,
    required this.barFactor,
    required this.rate,
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

/// The phase and gas breakdowns of the Gas consumption by segment card.
///
/// Sections share one set of columns, headed once by the first section, so
/// rates line up down the card and the unit is not repeated on each line. The
/// number columns take their content's width, so a long unit, a translated
/// heading or larger text squeezes the label rather than the figures.
class SacSegmentTable extends StatelessWidget {
  static const double _minRowHeight = 26;
  static const double _columnGap = 10;
  static const double _labelInset = 4;

  final String rateHeading;
  final String depthHeading;
  final String durationHeading;
  final List<SacSegmentTableSection> sections;

  const SacSegmentTable({
    super.key,
    required this.rateHeading,
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

class _LabelCell extends StatelessWidget {
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
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: row.semanticLabel,
      selected: row.selected,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: row.barFactor.clamp(0.0, 1.0),
                heightFactor: 0.8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(start: inset),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (row.icon != null) ...[
                    Icon(row.icon, size: 14),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
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
          ],
        ),
      ),
    );
  }
}
