import 'package:flutter/material.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';

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
    child: Align(
      alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final c in columns)
            Expanded(
              flex: c.flex,
              child: InkWell(
                key: ValueKey('sort-${c.id.name}'),
                onTap: () => onSort(c.id),
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
        ],
      ),
    );
  }
}

/// A kind colour dot and a one-line label.
class KindDotLabel extends StatelessWidget {
  const KindDotLabel({
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
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: colors.colorFor(kind),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
