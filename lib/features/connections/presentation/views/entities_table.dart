import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/table_parts.dart';
import 'package:submersion/features/connections/presentation/views/table_rows.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_legend.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every entity on the map as a sortable row; tapping one selects it.
class EntitiesTable extends ConsumerStatefulWidget {
  const EntitiesTable({
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
  ConsumerState<EntitiesTable> createState() => _EntitiesTableState();
}

class _EntitiesTableState extends ConsumerState<EntitiesTable> {
  EntitiesColumn _by = EntitiesColumn.dives;
  bool _ascending = false;

  /// Sorts by [column], reversing it when it is the sort [shownBy] the
  /// header currently shows.
  void _sort(
    EntitiesColumn column,
    EntitiesColumn shownBy,
    bool shownAscending,
  ) => setState(() {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final columns = [
          TableColumnSpec(
            EntitiesColumn.name,
            l10n.connections_table_name,
            flex: 4,
          ),
          if (wide)
            TableColumnSpec(EntitiesColumn.kind, l10n.connections_table_kind),
          TableColumnSpec(
            EntitiesColumn.dives,
            l10n.connections_table_dives,
            numeric: true,
          ),
          TableColumnSpec(
            EntitiesColumn.links,
            l10n.connections_table_links,
            numeric: true,
          ),
          if (wide)
            TableColumnSpec(
              EntitiesColumn.strongest,
              l10n.connections_table_strongest,
              flex: 3,
            ),
          if (wide)
            TableColumnSpec(
              EntitiesColumn.first,
              l10n.connections_table_firstDive,
            ),
        ];
        // A narrow view can hide the sorted column; sort by the default
        // until it shows again.
        final (by, ascending) = ConnectionsTableRows.shownSort(
          _by,
          _ascending,
          columns.map((c) => c.id),
          EntitiesColumn.dives,
        );
        final rows = ConnectionsTableRows.entities(
          widget.graph,
          by,
          ascending: ascending,
        );
        return Column(
          children: [
            SortableHeader<EntitiesColumn>(
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
                  final r = rows[i];
                  final strongest = r.strongest;
                  final isSelected =
                      selected is NodeSelection && selected.ref == r.node.ref;
                  return Material(
                    color: isSelected
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Colors.transparent,
                    child: InkWell(
                      key: ValueKey('entity-row-$i'),
                      onTap: () => widget.onSelect(NodeSelection(r.node.ref)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12 - kTableCellInset,
                        ),
                        child: Row(
                          children: [
                            ConnectionsTableCell(
                              flex: 4,
                              child: KindLabel(
                                kind: r.node.ref.kind,
                                label: r.node.label,
                                colors: widget.colors,
                              ),
                            ),
                            if (wide)
                              ConnectionsTableCell(
                                child: Text(
                                  kindNameOne(l10n, r.node.ref.kind),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ConnectionsTableCell(
                              numeric: true,
                              child: Text('${r.node.diveCount}'),
                            ),
                            ConnectionsTableCell(
                              numeric: true,
                              child: Text('${r.links}'),
                            ),
                            if (wide)
                              ConnectionsTableCell(
                                flex: 3,
                                child: Text(
                                  strongest == null
                                      ? ''
                                      : '${strongest.label} (${r.strongestWeight})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (wide)
                              ConnectionsTableCell(
                                child: Text(
                                  units.formatDate(r.node.firstDiveAt),
                                ),
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
