import 'package:flutter/material.dart';

import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';

/// Home's panel grid: one fixed-height row per [HomeRow], each panel taking
/// its share of the row as a flex weight, so every row runs edge to edge and
/// the panels in it line up top and bottom.
///
/// A sliver, so a row is built only as it nears the screen. Rows have fixed
/// heights rather than measured ones: measuring panel content (charts,
/// lists) is unsafe in an unbounded scroll view and defeats lazy building.
class DashboardGrid extends StatelessWidget {
  final List<HomeRow> rows;
  final Widget Function(HomePanelType panel) panelBuilder;
  final double Function(HomeRow row) rowHeight;

  /// Shown as a row of its own (the first-dive panel): after the first row
  /// when that row is the key numbers, otherwise at the top.
  final Widget? leading;
  final bool leadingFirst;
  final double spacing;

  const DashboardGrid({
    required this.rows,
    required this.panelBuilder,
    required this.rowHeight,
    this.leading,
    this.leadingFirst = false,
    this.spacing = 8,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    Widget leadingRow() => _GridRow(
      key: const ValueKey<String>('home-grid-leading'),
      bottomGap: spacing,
      child: leading!,
    );
    if (leading != null && (leadingFirst || rows.isEmpty)) {
      children.add(leadingRow());
    }
    for (final (i, row) in rows.indexed) {
      children.add(
        _GridRow(
          // A sliver matches unkeyed children by index, so without this a
          // row arriving above would remount every row below it.
          key: ValueKey<HomePanelType>(row.panels.first),
          bottomGap: spacing,
          child: SizedBox(
            height: rowHeight(row),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < row.panels.length; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  Expanded(
                    flex: row.units[j],
                    child: panelBuilder(row.panels[j]),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      if (i == 0 && leading != null && !leadingFirst) {
        children.add(leadingRow());
      }
    }
    return SliverList.list(children: children);
  }
}

/// One row of the grid. Once built it stays built, so scrolling past a panel
/// does not cost it its state: the map keeps its tiles.
///
/// The gap sits below the row, not above it: the row's box then starts at
/// its panels, so a row counts as on screen only once they are, which is
/// what the map's paint-deferred mount keys off.
class _GridRow extends StatefulWidget {
  final double bottomGap;
  final Widget child;

  const _GridRow({super.key, required this.bottomGap, required this.child});

  @override
  State<_GridRow> createState() => _GridRowState();
}

class _GridRowState extends State<_GridRow> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomGap),
      child: widget.child,
    );
  }
}
