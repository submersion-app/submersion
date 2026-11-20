import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// An entry in the dashboard's responsive grid.
sealed class DashboardEntry {
  const DashboardEntry();
}

/// Spans all columns at every width.
class FullBlock extends DashboardEntry {
  final Widget child;
  const FullBlock(this.child);
}

/// Spans one column; consecutive [ThirdBlock]s share a row. A leftover
/// block on an incomplete row expands to fill the remaining width.
class ThirdBlock extends DashboardEntry {
  final Widget child;
  const ThirdBlock(this.child);
}

/// Two widgets sharing one row at 2 or 3 columns, half the width each, and
/// stacked in order at 1 column.
///
/// Deliberately not two [ThirdBlock]s: those are packed in chunks of the
/// column count, so at 3 columns a neighbouring third would join the row and
/// squeeze the pair to a third of the width each. A pair states that the two
/// cards belong side by side whatever surrounds them.
class PairBlock extends DashboardEntry {
  final Widget first;
  final Widget second;
  const PairBlock({required this.first, required this.second});
}

/// A lead widget with side widgets stacked in the remaining column.
/// At 3 columns the lead spans 2; at 2 columns it spans 1; at 1 column
/// the group dissolves into the plain ordered stack.
class LeadSideGroup extends DashboardEntry {
  final Widget lead;
  final List<Widget> side;
  const LeadSideGroup({required this.lead, required this.side});
}

/// Responsive dashboard layout: one ordered entry list drives phone and
/// desktop. Column count follows [ResponsiveBreakpoints]: 1 below 800,
/// 2 at 800-1199, 3 at >=1200.
///
/// Builds a sliver, so a card is built only as its row approaches the viewport
/// rather than all at once when the home screen opens. The page around it
/// still decides which cards exist; this only defers building them.
class DashboardGrid extends StatelessWidget {
  final List<DashboardEntry> entries;
  final double spacing;

  const DashboardGrid({required this.entries, this.spacing = 12, super.key});

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveBreakpoints.isDesktopExtended(context)
        ? 3
        : ResponsiveBreakpoints.isDesktop(context)
        ? 2
        : 1;

    // Each row with the card that names it, the first one it holds.
    final rows = <(Widget, Widget)>[];
    final pendingThirds = <Widget>[];

    void flushThirds() {
      if (pendingThirds.isEmpty) return;
      if (columns == 1) {
        rows.addAll([for (final card in pendingThirds) (card, card)]);
      } else {
        for (var i = 0; i < pendingThirds.length; i += columns) {
          final end = i + columns > pendingThirds.length
              ? pendingThirds.length
              : i + columns;
          final chunk = pendingThirds.sublist(i, end);
          // No IntrinsicHeight: cards keep natural heights, top-aligned.
          // Intrinsic measurement is unsafe over arbitrary card content
          // (charts, internal flex) and caused layout failures.
          rows.add((
            chunk.first,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < chunk.length; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  Expanded(child: chunk[j]),
                ],
              ],
            ),
          ));
        }
      }
      pendingThirds.clear();
    }

    for (final entry in entries) {
      switch (entry) {
        case ThirdBlock(:final child):
          pendingThirds.add(child);
        case FullBlock(:final child):
          flushThirds();
          rows.add((child, child));
        case PairBlock(:final first, :final second):
          flushThirds();
          if (columns == 1) {
            rows.add((first, first));
            rows.add((second, second));
          } else {
            // Same top-aligned natural heights as every other row here: the
            // taller card does not stretch its partner.
            rows.add((
              first,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: first),
                  SizedBox(width: spacing),
                  Expanded(child: second),
                ],
              ),
            ));
          }
        case LeadSideGroup(:final lead, :final side):
          flushThirds();
          if (columns == 1) {
            rows.add((lead, lead));
            rows.addAll([for (final card in side) (card, card)]);
          } else {
            rows.add((
              lead,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: columns == 3 ? 2 : 1, child: lead),
                  SizedBox(width: spacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < side.length; i++) ...[
                          if (i > 0) SizedBox(height: spacing),
                          side[i],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ));
          }
      }
    }
    flushThirds();

    return SliverList.list(
      children: [
        for (final (i, (firstCard, row)) in rows.indexed)
          _GridRow(
            // A sliver matches unkeyed children by index, so without this a
            // card that resolves late would remount every row below it (the
            // map included) instead of pushing them down.
            key: ValueKey<Object>(firstCard.key ?? firstCard.runtimeType),
            bottomGap: i < rows.length - 1 ? spacing : 0,
            child: row,
          ),
      ],
    );
  }
}

/// One row of the grid. Once built it stays built, so scrolling past a card
/// does not cost it its state: the map keeps its tiles and the media ribbon
/// its scroll offset, as they did when every card was built up front.
///
/// The gap sits below the row, not above it: the row's box then starts at its
/// card, so a row counts as on screen only once the card is, not while the
/// transparent gap above it peeks over the fold.
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
