import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/table_parts.dart';
import 'package:submersion/features/connections/presentation/views/table_rows.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every connection on the map as a sortable row; tapping one selects it.
class PairsTable extends ConsumerStatefulWidget {
  const PairsTable({
    super.key,
    required this.graph,
    required this.colors,
    required this.selection,
    required this.onSelect,
  });

  final ConnectionGraph graph;
  final ConnectionKindColors colors;
  final GraphSelection? selection;
  final ValueChanged<GraphSelection?> onSelect;

  @override
  ConsumerState<PairsTable> createState() => _PairsTableState();
}

class _PairsTableState extends ConsumerState<PairsTable> {
  PairsColumn _by = PairsColumn.shared;
  bool _ascending = false;

  /// Sorts by [column], reversing it when it is the sort [shownBy] the
  /// header currently shows.
  void _sort(PairsColumn column, PairsColumn shownBy, bool shownAscending) =>
      setState(() {
        _by = column;
        _ascending = column == shownBy
            ? !shownAscending
            : ConnectionsTableRows.startsAscending(column);
      });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final selected = widget.selection;
    final labels = {for (final n in widget.graph.nodes) n.ref: n.label};
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final columns = [
          TableColumnSpec(
            PairsColumn.a,
            l10n.connections_table_entity,
            flex: 3,
          ),
          TableColumnSpec(
            PairsColumn.b,
            l10n.connections_table_linkedWith,
            flex: 3,
          ),
          TableColumnSpec(
            PairsColumn.shared,
            l10n.connections_table_sharedDives,
            numeric: true,
          ),
          TableColumnSpec(PairsColumn.last, l10n.connections_table_lastShared),
          if (wide)
            TableColumnSpec(
              PairsColumn.first,
              l10n.connections_table_firstShared,
            ),
        ];
        // A narrow view can hide the sorted column; sort by the default
        // until it shows again.
        final (by, ascending) = ConnectionsTableRows.shownSort(
          _by,
          _ascending,
          columns.map((c) => c.id),
          PairsColumn.shared,
        );
        final rows = ConnectionsTableRows.pairs(
          widget.graph,
          by,
          ascending: ascending,
        );
        return Column(
          children: [
            SortableHeader<PairsColumn>(
              columns: columns,
              sortedBy: by,
              ascending: ascending,
              onSort: (c) => _sort(c, by, ascending),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: kTableEndPadding),
                itemCount: rows.length,
                itemExtent: 48,
                itemBuilder: (context, i) {
                  final e = rows[i];
                  final isSelected =
                      selected is EdgeSelection &&
                      e.touches(selected.a) &&
                      e.touches(selected.b);
                  return Material(
                    color: isSelected
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Colors.transparent,
                    child: InkWell(
                      key: ValueKey('pair-row-$i'),
                      onTap: () =>
                          widget.onSelect(EdgeSelection(e.source, e.target)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12 - kTableCellInset,
                        ),
                        child: Row(
                          children: [
                            ConnectionsTableCell(
                              flex: 3,
                              child: KindLabel(
                                kind: e.source.kind,
                                label: labels[e.source] ?? e.source.id,
                                colors: widget.colors,
                              ),
                            ),
                            ConnectionsTableCell(
                              flex: 3,
                              child: KindLabel(
                                kind: e.target.kind,
                                label: labels[e.target] ?? e.target.id,
                                colors: widget.colors,
                              ),
                            ),
                            ConnectionsTableCell(
                              numeric: true,
                              child: Text('${e.weight}'),
                            ),
                            ConnectionsTableCell(
                              child: Text(units.formatDate(e.lastDiveAt)),
                            ),
                            if (wide)
                              ConnectionsTableCell(
                                child: Text(units.formatDate(e.firstDiveAt)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
