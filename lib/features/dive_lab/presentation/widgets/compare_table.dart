import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/domain/services/compare_columns.dart';
import 'package:submersion/features/dive_lab/presentation/compare_format.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const double _labelWidth = 112;
const double _minColumnWidth = 96;
const double _rowHeight = 44;

/// One row per measure and a column per line, Planned first. The row labels
/// stay put while the columns scroll sideways, so a phone shows three columns
/// and a dive with more stays readable. Rows share one height, scaled with the
/// text, because the labels and the scrolling columns are separate lists that
/// have to line up.
class CompareTable extends StatelessWidget {
  const CompareTable({
    super.key,
    required this.columns,
    required this.units,
    this.onOpenColumn,
  });

  final List<CompareColumn> columns;
  final UnitFormatter units;

  /// Called when a what-if's heading is tapped.
  final void Function(CompareColumn column)? onOpenColumn;

  @override
  Widget build(BuildContext context) {
    // A column can still be loading; row labels alone would read as a dive
    // with nothing to show.
    if (columns.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rowHeight = MediaQuery.textScalerOf(context).scale(_rowHeight);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final planned = columns
        .where((c) => c.kind == CompareLineKind.planned)
        .firstOrNull;

    Widget headingCell(CompareColumn column) {
      final title = Text(
        compareColumnTitle(l10n, column),
        style: theme.textTheme.labelMedium,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
      final open = onOpenColumn;
      if (open == null || column.kind != CompareLineKind.whatIf) return title;
      return InkWell(onTap: () => open(column), child: title);
    }

    Widget valueCell(CompareRow row, CompareColumn column) {
      final overshoots =
          planned != null &&
          column.kind == CompareLineKind.asDived &&
          overshootsPlan(row, planned, column);
      return Text(
        compareCell(l10n, units, row, column),
        key: ValueKey('compareCell_${column.id}_${row.name}'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: overshoots ? theme.colorScheme.error : null,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - _labelWidth;
        final columnWidth = math.max(_minColumnWidth, room / columns.length);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _labelWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: rowHeight),
                  for (final row in CompareRow.values)
                    SizedBox(
                      height: rowHeight,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          compareRowLabel(l10n, row),
                          style: labelStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final column in columns)
                      SizedBox(
                        width: columnWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Cell(
                              height: rowHeight,
                              child: headingCell(column),
                            ),
                            for (final row in CompareRow.values)
                              _Cell(
                                height: rowHeight,
                                child: valueCell(row, column),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    ),
  );
}
