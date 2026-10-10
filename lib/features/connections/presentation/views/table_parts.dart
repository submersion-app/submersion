import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_icons.dart';

/// Each side of a cell, header or body, so neighbouring columns never touch
/// (a right-aligned number would otherwise run into the next column).
const double kTableCellInset = 6;

/// Space after the last table row or matrix row, so the year play pill that
/// floats at the bottom never covers it.
const double kTableEndPadding = 72;

class TableColumnSpec<T extends Enum> {
  const TableColumnSpec(
    this.id,
    this.label, {
    this.flex = 2,
    this.numeric = false,
  });

  final T id;
  final String label;
  final int flex;
  final bool numeric;
}

/// One table cell, sized by [flex] and right-aligned when [numeric].
class ConnectionsTableCell extends StatelessWidget {
  const ConnectionsTableCell({
    super.key,
    required this.child,
    this.flex = 2,
    this.numeric = false,
  });

  final Widget child;
  final int flex;
  final bool numeric;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: kTableCellInset),
      child: Align(
        alignment: numeric
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: child,
      ),
    ),
  );
}

/// The header row: tap a column to sort by it, again to reverse.
class SortableHeader<T extends Enum> extends StatelessWidget {
  const SortableHeader({
    super.key,
    required this.columns,
    required this.sortedBy,
    required this.ascending,
    required this.onSort,
  });

  final List<TableColumnSpec<T>> columns;
  final T sortedBy;
  final bool ascending;
  final ValueChanged<T> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Container(
      height: 40,
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 12 - kTableCellInset),
      child: Row(
        children: [
          for (final c in columns)
            Expanded(
              flex: c.flex,
              child: InkWell(
                key: ValueKey('sort-${c.id.name}'),
                onTap: () => onSort(c.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kTableCellInset,
                  ),
                  child: Row(
                    mainAxisAlignment: c.numeric
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          c.label,
                          style: style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (c.id == sortedBy)
                        Icon(
                          ascending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 14,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The kind's icon in the kind's colour, then a one-line label.
class KindLabel extends StatelessWidget {
  const KindLabel({
    super.key,
    required this.kind,
    required this.label,
    required this.colors,
  });

  final ConnectionKind kind;
  final String label;
  final ConnectionKindColors colors;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(connectionKindIcon(kind), size: 16, color: colors.colorFor(kind)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
